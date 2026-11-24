"""Generate an isolated preview identity, preserving approved Flutter source/assets."""
from pathlib import Path

project = Path("android/app/build.gradle.kts")
content = project.read_text()
old = 'applicationId = "com.maqwatilink.qat_link"'
assert old in content, "Unexpected generated Android applicationId"
project.write_text(content.replace(old, 'applicationId = "com.maqwatilink.green_secure_preview"'))
manifest = Path("android/app/src/main/AndroidManifest.xml")
content = manifest.read_text()
assert 'android:label="qat_link"' in content, "Unexpected generated label"
manifest.write_text(content.replace('android:label="qat_link"',
                                    'android:label="مقوتي لينك - معاينة دون اتصال"'))
with Path("android/gradle.properties").open("a") as output:
    output.write("\nkotlin.incremental=false\n")
for name in (
    "01-welcome-blue.jpeg", "02-close-yellow.jpeg", "03-eyes-blue.jpeg",
    "04-welcome-purple.jpeg", "05-close-pink.jpeg", "06-welcome-red.jpeg",
    "07-happiness-pink.jpeg",
):
    assert (Path("assets/banners") / name).is_file(), f"Missing approved banner: {name}"
