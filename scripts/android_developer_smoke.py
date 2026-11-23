"""Exercise existing unverified role shells in the separate developer APK.

No fixture records, identity, token or live gateway are injected. This tests
native rendering/navigation of available offline states, never financial E2E.
"""
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = 'com.maqwatilink.ui_audit_developer'
OUT = Path('build/android-developer-smoke')
OUT.mkdir(parents=True, exist_ok=True)


def adb(*args):
    return subprocess.check_output(['adb', *args], text=True)


def window():
    adb('shell', 'uiautomator', 'dump', '/sdcard/developer-window.xml')
    xml = adb('shell', 'cat', '/sdcard/developer-window.xml')
    (OUT / 'latest-window.xml').write_text(xml)
    return xml


def tap(label, bottom=False):
    nodes = []
    for node in ET.fromstring(window()).iter('node'):
        values = [node.get('text', ''), node.get('content-desc', '')]
        if not any(value.strip() == label for value in values):
            continue
        bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
            nodes.append(bounds)
    assert nodes, f'Native control unavailable: {label}'
    bounds = sorted(nodes, key=lambda b: b[1], reverse=bottom)[0]
    adb('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2),
        str((bounds[1]+bounds[3])//2))
    time.sleep(.5)


def capture(name):
    time.sleep(.5)
    assert adb('shell', 'pidof', PACKAGE).strip(), 'Developer APK exited'
    data = subprocess.check_output(['adb', 'exec-out', 'screencap', '-p'])
    assert data.startswith(b'\x89PNG\r\n\x1a\n')
    (OUT / f'{name}.png').write_bytes(data)


try:
    adb('install', '-r', 'build/app/outputs/flutter-apk/app-release.apk')
    adb('logcat', '-c')
    adb('shell', 'wm', 'density', '160')
    adb('shell', 'wm', 'size', '390x900')
    activity = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).strip().splitlines()[-1]
    assert '/' in activity
    adb('shell', 'am', 'start', '-W', '-n', activity)
    time.sleep(3)
    assert 'معاينة تصميم فقط' in window(), 'Developer scope warning missing'
    for gender in ['blue', 'pink']:
        if gender == 'pink':
            tap('الثيم الوردي')
        for mode in ['day', 'night']:
            if mode == 'night':
                tap('الوضع الليلي')
            theme = f'{gender}_{mode}'
            for role, tabs in [('merchant', ['الرئيسية', 'الحركة', 'العملاء', 'مساحتي']),
                               ('customer', ['الرئيسية', 'الحركة', 'استديو', 'التجار', 'المتاجر'])]:
                tap('تاجر' if role == 'merchant' else 'عميل')
                for index, label in enumerate(tabs):
                    tap(label, bottom=True)
                    capture(f'{role}_{theme}_390_tab{index}')
                tap('الرئيسية', bottom=True)
                for label, name in [('التنبيهات', 'notifications'), ('الضبط', 'settings')]:
                    tap(label)
                    capture(f'{role}_{theme}_390_{name}')
                    adb('shell', 'input', 'keyevent', '4')
                    time.sleep(.5)
                for width in [320, 360, 430, 600, 800]:
                    adb('shell', 'wm', 'size', f'{width}x900')
                    capture(f'{role}_{theme}_{width}_home')
                adb('shell', 'wm', 'size', '390x900')
            if mode == 'night':
                tap('الوضع النهاري')
    logs = adb('logcat', '-d')
    (OUT / 'logcat.txt').write_text(logs)
    assert 'FATAL EXCEPTION' not in logs, 'Native crash'
    assert 'Unable to load asset' not in logs, 'Missing asset'
    captures = len(list(OUT.glob('*.png')))
    assert captures == 92, f'Incomplete developer matrix: {captures}'
    (OUT / 'result.json').write_text(json.dumps({
        'installed': True, 'launched': True, 'themes': 4,
        'widths': [320, 360, 390, 430, 600, 800], 'captures': captures,
        'role_tab_and_modal_captures': 52, 'extra_home_size_captures': 40,
        'scope': 'existing offline unverified shells; no auth or financial E2E',
    }, indent=2))
finally:
    (OUT / 'logcat-final.txt').write_text(adb('logcat', '-d'))
    adb('shell', 'wm', 'size', 'reset')
    adb('shell', 'wm', 'density', 'reset')
