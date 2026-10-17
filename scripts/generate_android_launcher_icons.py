#!/usr/bin/env python3
"""Build Android launcher icons from the untouched official Sukun Life PNG.

Runs only at an explicitly authorized native build gate. Never replaces or
recolors the brand source, draws a substitute logo, or modifies production.
Requires Pillow (pip install Pillow==11.3.0).
"""
from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
BRAND = REPO / "app/assets/brand/sukunlife_logo.png"
RES = REPO / "app/android/app/src/main/res"
MIST = (232, 245, 252, 255)  # Approved Sukun Mist #E8F5FC.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def make_icon(source: Image.Image, size: int, fraction: float) -> Image.Image:
    """Contain the COMPLETE supplied logo without cropping, stretching or tint."""
    canvas = Image.new("RGBA", (size, size), MIST)
    logo = source.copy()
    limit = round(size * fraction)
    logo.thumbnail((limit, limit), Image.Resampling.LANCZOS)
    canvas.alpha_composite(
        logo, ((size - logo.width) // 2, (size - logo.height) // 2)
    )
    return canvas


def main() -> None:
    if not BRAND.is_file():
        raise SystemExit("Official Sukun Life logo missing; refusing icon generation.")
    source_sha = hashlib.sha256(BRAND.read_bytes()).hexdigest()
    with Image.open(BRAND) as logo_file:
        logo = logo_file.convert("RGBA")
    if logo.width < 64 or logo.height < 64:
        raise SystemExit("Source logo resolution is too low for a launcher icon.")

    for density, scale in DENSITIES.items():
        legacy_path = RES / f"mipmap-{density}/ic_launcher.png"
        legacy_path.parent.mkdir(parents=True, exist_ok=True)
        make_icon(logo, round(48 * scale), 0.83).convert("RGB").save(
            legacy_path, format="PNG", optimize=True
        )

        foreground_path = RES / f"drawable-{density}/sukun_launcher_foreground.png"
        foreground_path.parent.mkdir(parents=True, exist_ok=True)
        make_icon(logo, round(108 * scale), 0.60).save(
            foreground_path, format="PNG", optimize=True
        )

    adaptive = RES / "mipmap-anydpi-v26/ic_launcher.xml"
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/sukun_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/sukun_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )

    colors = RES / "values/sukun_launcher_colors.xml"
    colors.parent.mkdir(parents=True, exist_ok=True)
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources><color name="sukun_launcher_background">#E8F5FC</color></resources>\n',
        encoding="utf-8",
    )
    if hashlib.sha256(BRAND.read_bytes()).hexdigest() != source_sha:
        raise SystemExit("The original logo was modified unexpectedly.")
    print("Android launcher icons generated from original Sukun Life logo.")
    print("Brand source left unchanged. No APK/AAB built by this script.")


if __name__ == "__main__":
    main()
