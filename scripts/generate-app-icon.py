#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "branding" / "MihomoCoreManager-2.png"
MASTER = ROOT / "branding" / "AppIcon-master-1024.png"
OUT = ROOT / "MihomoCoreManager/Resources/Assets.xcassets/AppIcon.appiconset"
WEB = ROOT / "portable-runtime/ui/app-icon-128.png"

if not SOURCE.is_file():
    raise SystemExit(f"missing icon source: {SOURCE}")

img = Image.open(SOURCE).convert("RGBA")
# v1.3.1 uses the user-supplied MihomoCoreManager-2 artwork as the single
# source of truth. Preserve transparency and aspect ratio while normalizing the
# shared release master to the 1024x1024 macOS asset-catalog size.
if img.size != (1024, 1024):
    img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
MASTER.parent.mkdir(parents=True, exist_ok=True)
img.save(MASTER, optimize=True)

OUT.mkdir(parents=True, exist_ok=True)
for size in (16, 32, 64, 128, 256, 512, 1024):
    icon = img.resize((size, size), Image.Resampling.LANCZOS)
    if size <= 128:
        icon = icon.filter(ImageFilter.UnsharpMask(radius=0.55, percent=115, threshold=2))
    icon.save(OUT / f"AppIcon-{size}.png", optimize=True)

WEB.parent.mkdir(parents=True, exist_ok=True)
img.resize((128, 128), Image.Resampling.LANCZOS).save(WEB, optimize=True)
print(f"generated app icon assets from {SOURCE}")
