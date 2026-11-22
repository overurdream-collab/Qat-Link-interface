"""Repair image containers only; do not redraw or recolor owner artwork.

Flutter can reject JPEG/WebP files even when the GitHub assets exist.
The original visible pixels are preserved, with colorspace/encoding normalized.
Run from repository root. Requires Pillow.
"""
from pathlib import Path
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

FILES = [
    (Path("assets/images/maqwati_approved_mascot.jpeg"), "JPEG"),
    (Path("assets/images/maqwati_feminine_mascot.webp"), "WEBP"),
]
for path, format_name in FILES:
    raw = path.read_bytes()
    print(f"Checking {path}: bytes={len(raw)}, head={raw[:12].hex()}, tail={raw[-12:].hex()}")
    try:
        with Image.open(path) as opened:
            opened.load()
            print(f"  source: format={opened.format}, size={opened.size}, mode={opened.mode}")
            if opened.width < 100 or opened.height < 100:
                raise ValueError(f"Low resolution artwork: {opened.size}")
            normalized = opened.convert("RGB" if format_name == "JPEG" else "RGBA")
            output = path.with_suffix(path.suffix + ".repaired")
            if format_name == "JPEG":
                normalized.save(output, format="JPEG", quality=93, optimize=True,
                                progressive=False, subsampling=0)
            else:
                normalized.save(output, format="WEBP", quality=91, method=5)
            with Image.open(output) as check:
                check.load()
                assert check.size == opened.size
            path.write_bytes(output.read_bytes())
            output.unlink()
            print(f"  repaired: bytes={path.stat().st_size}")
    except Exception as exc:
        print(f"  REPAIR BLOCKED: {type(exc).__name__}: {exc}")
        raise SystemExit(f"Cannot safely repair image without replacing owner artwork: {path}") from exc
