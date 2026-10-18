#!/usr/bin/env python3
"""Static Play Store release safety checks. Does not build or deploy an APK."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
gradle = (root / "app/android/app/build.gradle.kts").read_text(encoding="utf-8")
manifest = (root / "app/android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
ignore = (root / ".gitignore").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/play-release-prep.yml").read_text(encoding="utf-8")

checks = {
    "app ID fixed": bool(re.search(r'applicationId\s*=\s*"com\.sukunlife\.app"', gradle)),
    "compile SDK 36": bool(re.search(r"compileSdk\s*=\s*36", gradle)),
    "target SDK 36": bool(re.search(r"targetSdk\s*=\s*36", gradle)),
    "no debug release signing": 'signingConfigs.getByName("debug")' not in gradle,
    "release signing fail-closed": "releaseTaskRequested && !uploadSigningConfigured" in gradle,
    "approved keystore injected": "SUKUN_UPLOAD_KEYSTORE_PATH" in gradle,
    "release network permission": 'android.permission.INTERNET' in manifest,
    "no Android auto backup": 'android:allowBackup="false"' in manifest,
    "ignore local signing secrets": all(x in ignore for x in ("**/android/key.properties", "*.jks", "*.keystore")),
    "manual workflow required": "workflow_dispatch:" in workflow,
    "PR cannot build signed artifact": "if: github.event_name == 'workflow_dispatch'" in workflow,
    "upload fingerprint comparison": 'PLAY_UPLOAD_CERT_SHA256' in workflow,
    "version code check": "PLAY_LATEST_VERSION_CODE" in workflow,
    "signature verification": "jarsigner -verify" in workflow,
    "no automated Play publication": "google-play-android-publisher" not in workflow.lower(),
}
for name, ok in checks.items():
    print(f'{"PASS" if ok else "FAIL"} {name}')
if not all(checks.values()):
    raise SystemExit("Android release preflight FAILED")
print("Android release preflight PASSED (static policy only, not Play approval).")
