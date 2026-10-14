"""Exercise the real Gradle release gate without creating any signing key.

Run from the repository root with JAVA_HOME set to the Android JBR.
Only negative cases: this is not evidence of a successfully signed APK.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
NAMES = (
    'PEKSEN_ANDROID_KEYSTORE', 'PEKSEN_ANDROID_KEYSTORE_PASSWORD',
    'PEKSEN_ANDROID_KEY_ALIAS', 'PEKSEN_ANDROID_KEY_PASSWORD',
)


class ReleaseSigningTest(unittest.TestCase):
    def rejected(self, values, task, message):
        env = os.environ.copy()
        for name in NAMES:
            env.pop(name, None)
        env.update(values)
        wrapper = 'gradlew.bat' if os.name == 'nt' else 'gradlew'
        result = subprocess.run(
            [str(ROOT / 'android' / wrapper), '--console=plain', task],
            cwd=ROOT / 'android', env=env, capture_output=True,
            text=True, encoding='utf-8', errors='replace', timeout=180,
        )
        # Never dump Gradle/environment content on assertion failure.
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, 'Release gate unexpectedly passed')
        self.assertTrue(message in output, 'Expected release guard was not reached')
        self.assertFalse('not-a-real-password-marker' in output,
                         'Signing value was exposed in Gradle diagnostics')

    def test_release_build_requires_credentials(self):
        self.rejected({}, ':app:preReleaseBuild', 'Release signing is not configured.')

    def test_partial_configuration_is_rejected(self):
        self.rejected({NAMES[2]: 'release'}, ':app:validateReleaseSigning',
                      'Release signing is not configured.')

    def test_repository_keystore_location_is_rejected(self):
        self.rejected(dict(zip(NAMES, [str(ROOT / 'pubspec.yaml'),
                      'not-a-real-password-marker', 'release',
                      'not-a-real-password-marker'])),
                      ':app:validateReleaseSigning',
                      'Release keystore must be an existing absolute file outside the repository.')

    def test_debug_alias_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='peksen-signing-test-') as folder:
            # Plain text placeholder, deliberately not a keystore or key.
            path = Path(folder) / 'placeholder.txt'
            path.write_text('not a keystore', encoding='utf-8')
            self.rejected(dict(zip(NAMES, [str(path),
                          'not-a-real-password-marker', 'androiddebugkey',
                          'not-a-real-password-marker'])),
                          ':app:validateReleaseSigning',
                          'Android debug signing material is not permitted for release.')


if __name__ == '__main__':
    unittest.main(verbosity=2)
