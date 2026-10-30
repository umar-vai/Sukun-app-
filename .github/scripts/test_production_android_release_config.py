"""Offline safeguards for direct APK and Play AAB production client configuration.

Never builds Android packages, contacts Firebase, or reads real secrets.
"""
from pathlib import Path
import os
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / ".github/scripts/verify-production-android-client.sh"
APK = (ROOT / ".github/workflows/android-sideload-release.yml").read_text()
AAB = (ROOT / ".github/workflows/play-release-prep.yml").read_text()
UPDATE = (ROOT / "app/lib/core/updates/android_update_panel.dart").read_text()

VALID = {
    "PRODUCTION_FIREBASE_PROJECT_ID": "sukun-prod-test-project",
    "PRODUCTION_FIREBASE_SENDER_ID": "123456789012",
    "PRODUCTION_FIREBASE_ANDROID_API_KEY": "AIzaSy_example_valid_test_key_123456",
    "PRODUCTION_FIREBASE_ANDROID_APP_ID": "1:123456789012:android:012345abcdef",
}

class AndroidReleaseConfigTest(unittest.TestCase):
    def verify(self, overrides, expected):
        values = dict(VALID, **overrides)
        result = subprocess.run(
            ["bash", str(GUARD)], env={**os.environ, **values},
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode == 0, expected, result.stderr)
        self.assertNotIn(VALID["PRODUCTION_FIREBASE_ANDROID_API_KEY"],
                         result.stderr + result.stdout)

    def test_complete_public_client(self):
        self.verify({}, True)

    def test_rejects_missing_project(self):
        self.verify({"PRODUCTION_FIREBASE_PROJECT_ID": ""}, False)

    def test_rejects_missing_sender(self):
        self.verify({"PRODUCTION_FIREBASE_SENDER_ID": ""}, False)

    def test_rejects_missing_api_key(self):
        self.verify({"PRODUCTION_FIREBASE_ANDROID_API_KEY": ""}, False)

    def test_rejects_wrong_android_app_sender(self):
        self.verify({"PRODUCTION_FIREBASE_ANDROID_APP_ID":
                     "1:999999999999:android:012345abcdef"}, False)

    def test_both_signed_builds_have_production_firebase(self):
        for workflow in (APK, AAB):
            for value in (
                "FIREBASE_PROJECT_ID=$PRODUCTION_FIREBASE_PROJECT_ID",
                "FIREBASE_MESSAGING_SENDER_ID=$PRODUCTION_FIREBASE_SENDER_ID",
                "FIREBASE_ANDROID_API_KEY=$PRODUCTION_FIREBASE_ANDROID_API_KEY",
                "FIREBASE_ANDROID_APP_ID=$PRODUCTION_FIREBASE_ANDROID_APP_ID",
                "ENABLE_GOOGLE_OAUTH=true",
                "ENABLE_MEMBER_SIGNUP=true",
                "verify-production-android-client.sh",
            ):
                with self.subTest(value=value):
                    self.assertIn(value, workflow)

    def test_direct_apk_remains_owner_approved_not_automatic(self):
        self.assertIn("workflow_dispatch:", APK)
        self.assertIn("inputs.approve_native_apk == true", APK)
        self.assertIn("SUKUN_UPLOAD_KEYSTORE_PATH", APK)

    def test_update_install_requires_user_tap(self):
        # A successful download should expose an install button, not
        # automatically launch the OS installer from a polling callback.
        start = UPDATE.index("Future<void> _readProgress() async")
        end = UPDATE.index("Future<void> _install() async")
        self.assertNotIn("await _install()", UPDATE[start:end])
        self.assertIn("onPressed: _install", UPDATE)

if __name__ == "__main__":
    unittest.main()
