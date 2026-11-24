"""Verify generated APK identity, offline boundary and checksum; no publication."""
from pathlib import Path
import hashlib
import json
import os
import subprocess

sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
aapts = sorted((sdk / "build-tools").glob("*/aapt"))
assert aapts, "Android aapt unavailable"
apk = Path("build/app/outputs/flutter-apk/app-release.apk")
assert apk.is_file(), "Offline preview APK missing"
badging = subprocess.check_output([str(aapts[-1]), "dump", "badging", str(apk)], text=True)
permissions = subprocess.check_output([str(aapts[-1]), "dump", "permissions", str(apk)], text=True)
assert "name='com.maqwatilink.green_secure_preview'" in badging, "Wrong isolated preview package"
assert "android.permission.INTERNET" not in permissions, "Offline preview must not reach services"
metadata = {
    "package": "com.maqwatilink.green_secure_preview",
    "purpose": "OFFLINE UI PREVIEW ONLY; no verified financial session or real OTP",
    "file": str(apk),
    "bytes": apk.stat().st_size,
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "internet_permission": False,
    "signing": "Flutter generated preview configuration; not production signing",
}
Path("build/release-readiness/apk-verification.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps(metadata))
