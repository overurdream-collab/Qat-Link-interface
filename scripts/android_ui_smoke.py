"""Install and exercise the actual offline APK on the CI Android emulator.
No credentials, SMS, user session or financial authority are supplied.
"""
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = 'com.maqwatilink.ui_audit_preview'
OUT = Path('build/android-smoke')
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args], text=True)

def tap_label(label, attempts=8):
    for _ in range(attempts):
        adb('shell', 'uiautomator', 'dump', '/sdcard/window.xml')
        xml = adb('shell', 'cat', '/sdcard/window.xml')
        (OUT / 'latest-window.xml').write_text(xml)
        for node in ET.fromstring(xml).iter('node'):
            if label in (node.get('text'), node.get('content-desc')):
                x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds', '')))
                if x2 > x1 and y2 > y1:
                    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
                    time.sleep(1)
                    return
        if label in ['الوضع الليلي', 'الوضع النهاري']:
            adb('shell', 'input', 'swipe', '180', '250', '180', '750', '350')
        else:
            adb('shell', 'input', 'swipe', '180', '650', '180', '300', '350')
        time.sleep(.5)
    raise AssertionError(f'Cannot reach actual Android control: {label}')

def capture(name):
    time.sleep(1)
    assert adb('shell', 'pidof', PACKAGE).strip(), 'APK process exited'
    result = subprocess.check_output(['adb', 'exec-out', 'screencap', '-p'])
    assert result.startswith(b'\x89PNG\r\n\x1a\n')
    (OUT / f'{name}.png').write_bytes(result)

try:
    adb('install', '-r', 'build/app/outputs/flutter-apk/app-release.apk')
    adb('logcat', '-c')
    adb('shell', 'wm', 'density', '160')
    adb('shell', 'wm', 'size', '390x900')
    activity = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).strip().splitlines()[-1]
    assert '/' in activity
    adb('shell', 'am', 'start', '-W', '-n', activity)
    time.sleep(3)
    for gender in ['blue', 'pink']:
        if gender == 'pink':
            tap_label('إنشاء حساب جديد')
            tap_label('أنثى')
            adb('shell', 'input', 'keyevent', '4')
            time.sleep(1)
        for width in [320, 360, 390, 430, 600, 800]:
            adb('shell', 'wm', 'size', f'{width}x900')
            for _ in range(3):
                adb('shell', 'input', 'swipe', '180', '250', '180', '750', '200')
            capture(f'{gender}_day_{width}')
            tap_label('الوضع الليلي')
            capture(f'{gender}_night_{width}')
            tap_label('الوضع النهاري')
    logs = adb('logcat', '-d')
    (OUT / 'logcat.txt').write_text(logs)
    assert 'FATAL EXCEPTION' not in logs, 'Native crash recorded'
    assert 'Unable to load asset' not in logs, 'Flutter asset error recorded'
    (OUT / 'result.json').write_text(json.dumps({'installed': True, 'launched': True,
        'themes': 4, 'widths': [320,360,390,430,600,800], 'captures': 24,
        'scope': 'offline login; no authentication or financial E2E'}, indent=2))
finally:
    (OUT / 'logcat-final.txt').write_text(adb('logcat', '-d'))
    adb('shell', 'wm', 'size', 'reset')
    adb('shell', 'wm', 'density', 'reset')
