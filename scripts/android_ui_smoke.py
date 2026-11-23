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

def window():
    adb('shell', 'uiautomator', 'dump', '/sdcard/window.xml')
    xml = adb('shell', 'cat', '/sdcard/window.xml')
    (OUT / 'latest-window.xml').write_text(xml)
    return xml

def tap_node(node, settle=1):
    x1,y1,x2,y2 = map(int,re.findall(r'\d+',node.get('bounds','')))
    if x2 <= x1 or y2 <= y1:
        return False
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    time.sleep(settle)
    return True

def tap_label(label, attempts=8, clickable=False, settle=1):
    for _ in range(attempts):
        for node in ET.fromstring(window()).iter('node'):
            if label in (node.get('text'),node.get('content-desc')):
                if clickable and node.get('clickable') != 'true':
                    continue
                if tap_node(node,settle):
                    return
        if label in ['الوضع الليلي','الوضع النهاري']:
            adb('shell','input','swipe','180','250','180','750','350')
        else:
            adb('shell','input','swipe','180','650','180','300','350')
        time.sleep(.5)
    raise AssertionError(f'Cannot reach actual Android control: {label}')

def tap_field(password):
    for _ in range(8):
        for node in ET.fromstring(window()).iter('node'):
            if node.get('class') == 'android.widget.EditText' and (node.get('password') == 'true') == password:
                bounds=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
                if len(bounds)==4 and bounds[3]-bounds[1]>=32 and tap_node(node):
                    return
        adb('shell','input','swipe','180','650','180','300','350')
    raise AssertionError(f'Cannot reach field password={password}')

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
    # Synthetic local inputs only. An offline preview must never grant a session.
    tap_label('تسجيل الدخول',clickable=True,settle=.2)
    assert 'أدخل رقم الجوال' in window(), 'Empty form validation did not appear'
    capture('form_validation_390')
    tap_field(False)
    adb('shell','input','text','771234567')
    tap_field(True)
    adb('shell','input','text','1234')
    (OUT / 'keyboard-state.txt').write_text(adb('shell','dumpsys','input_method'))
    capture('form_keyboard_390')
    tap_label('إظهار الرمز')
    adb('shell','input','keyevent','4')
    tap_label('تذكرني',clickable=True)
    assert any(n.get('checked')=='true' and 'تذكرني' in (n.get('text','')+n.get('content-desc','')) for n in ET.fromstring(window()).iter('node')), 'Remember-me label did not toggle the checkbox'
    tap_label('تسجيل الدخول',clickable=True,settle=.2)
    xml=window()
    assert 'لا تُفتح الحسابات' in xml, 'Valid local input bypassed the explicit offline gate'
    assert 'حساب التاجر' not in xml, 'A merchant session was exposed from offline input'
    capture('form_offline_gate_390')
    time.sleep(4)
    # Relaunch a clean form for the visual matrix; no stored PIN or session.
    adb('shell','am','force-stop',PACKAGE)
    adb('shell','am','start','-W','-n',activity)
    time.sleep(2)
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
        'themes': 4, 'widths': [320,360,390,430,600,800], 'captures': len(list(OUT.glob('*.png'))),
        'theme_size_captures': 24, 'form_flow_captures': 3, 'offline_gate': True, 'remember_label_toggle': True,
        'scope': 'offline login; no authentication or financial E2E'}, indent=2))
finally:
    (OUT / 'logcat-final.txt').write_text(adb('logcat', '-d'))
    adb('shell', 'wm', 'size', 'reset')
    adb('shell', 'wm', 'density', 'reset')
