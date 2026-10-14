"""Read-only Phase 16 source/config checks. No .env or credential values read.

This is a narrow regression guard, not a dependency/CVE or penetration scan.
"""
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def main():
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    forbidden = [p for p in tracked if p and (
        Path(p).name in {'.env', 'key.properties', 'google-services.json'} or
        Path(p).suffix.lower() in {'.jks', '.keystore', '.p12', '.pfx', '.apk'})]
    assert not forbidden, 'Sensitive/local artifact tracked: ' + ', '.join(forbidden)
    print('PASS: local env/signing/native Firebase/APK artifacts not tracked')
    candidates = []
    for name in tracked:
        path = ROOT / name
        if not name or path.suffix.lower() not in {'.dart', '.kt', '.sql', '.ts', '.json', '.md', '.ps1', '.py'}:
            continue
        content = path.read_text(encoding='utf-8-sig')
        # Header-only rejection fixtures and runtime-generated keys are not
        # embedded credentials. Require a literal encoded key body + footer.
        if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+[A-Za-z0-9+/=\r\n]{128,}-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', content.replace('\\n', '\n')):
            candidates.append(name)
    assert not candidates, 'Private key marker requires review (values suppressed): ' + ', '.join(candidates)
    print('PASS: no complete literal private-key blocks in tracked source')
    main_app = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot().find('application')
    assert main_app.get(ANDROID+'allowBackup') == 'false'
    assert main_app.get(ANDROID+'usesCleartextTraffic') != 'true'
    assert main_app.get(ANDROID+'networkSecurityConfig') is None
    assert all(s.get(ANDROID+'exported') == 'false' for s in main_app.findall('service'))
    config = ET.parse(ROOT / 'android/app/src/debug/res/xml/debug_network_security_config.xml').getroot()
    assert config.find('base-config').get('cleartextTrafficPermitted') == 'false'
    assert {d.text for d in config.findall('.//domain')} == {'192.168.0.100','10.0.2.2','127.0.0.1','localhost','::1'}
    print('PASS: Android backup disabled, tracking service private, HTTP exceptions debug/local-only')
    route = (ROOT / 'lib/core/routing/app_router.dart').read_text(encoding='utf-8')
    assert 'kDebugMode && previewEnabled' in route
    print('PASS: preview remains explicitly debug-gated (behavior also covered by Flutter tests)')
    print('4/4 source checks PASS; no secret values printed')


if __name__ == '__main__':
    main()
