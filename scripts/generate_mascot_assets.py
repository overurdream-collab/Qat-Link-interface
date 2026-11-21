#!/usr/bin/env python3
"""Produce two bundled Flutter mascot PNGs from the approved repository mascot.

The blue image preserves the approved repository artwork. The pink variant
re-colors only saturated blue/purple clothing details, retaining face, skin,
head shape, pose, golden jambiya and white garment without trying to infer
gender from the image. No external images, model APIs or network calls.
"""
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/images/maqwati_approved_mascot.jpeg"
BLUE = ROOT / "assets/images/maqwati_mascot_blue.png"
PINK = ROOT / "assets/images/maqwati_mascot_pink.png"

if not SOURCE.is_file():
    raise SystemExit(f"Missing original approved mascot: {SOURCE}")

base = Image.open(SOURCE).convert("RGBA")
base.thumbnail((1000, 1250), Image.Resampling.LANCZOS)
# Preserve source appearance, proportions and pose exactly for the blue theme.
base.save(BLUE, format="PNG", optimize=True)

hsv = np.asarray(base.convert("RGB").convert("HSV"), dtype=np.uint8).copy()
hue, saturation, value = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
# Hue 0..255 in Pillow: blue ~170, purple ~200, pink/magenta ~235.
# Skin, gold, black hair, white cloth and ivory remain unchanged.
blue_cloth = (hue >= 132) & (hue <= 221) & (saturation >= 57) & (value >= 45)
# Make blue details rose and purple details orchid while retaining luminance.
old_hue = hue[blue_cloth].astype(np.float32)
hue[blue_cloth] = np.clip(232 - (old_hue - 132) * .12, 220, 239).astype(np.uint8)
saturation[blue_cloth] = np.minimum(
    255, (saturation[blue_cloth].astype(np.float32) * .96 + 9).astype(np.uint16)
).astype(np.uint8)
converted = Image.fromarray(hsv, mode="HSV").convert("RGB")
variant = Image.merge("RGBA", (*converted.split(), base.getchannel("A")))
variant.save(PINK, format="PNG", optimize=True)

for item in (BLUE, PINK):
    final = Image.open(item)
    assert final.size == base.size and final.size[0] >= 200, item
    assert final.mode == "RGBA", item
    print(f"ASSET_OK {item.relative_to(ROOT)} {final.size} {item.stat().st_size} bytes")
