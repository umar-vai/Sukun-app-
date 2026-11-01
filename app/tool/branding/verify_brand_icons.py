"""Offline checks for branded launcher assets; no APK, production data or internet needed."""
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

APP = Path(__file__).resolve().parents[2]


def assert_png(path: Path, size: int) -> None:
    content = path.read_bytes()
    assert content.startswith(b"\x89PNG\r\n\x1a\n"), f"Invalid PNG: {path}"
    width, height = struct.unpack(">II", content[16:24])
    assert (width, height) == (size, size), f"{path}: {width}x{height} != {size}x{size}"


def main() -> None:
    source = APP / "assets/brand/sukunlife_logo.png"
    assert source.is_file() and source.stat().st_size > 100_000
    for name, size in {
        "favicon.png": 48,
        "icons/Icon-192.png": 192,
        "icons/Icon-512.png": 512,
        "icons/Icon-maskable-512.png": 512,
        "icons/apple-touch-icon.png": 180,
    }.items():
        assert_png(APP / "web" / name, size)

    root = APP / "android/app/src/main/res"
    for density, size in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192
    }.items():
        folder = root / ("mipmap-" + density)
        assert_png(folder / "ic_launcher.png", size)
        assert_png(folder / "ic_launcher_foreground.png", round(size * 2.25))

    adaptive = ET.parse(root / "mipmap-anydpi-v26/ic_launcher.xml").getroot()
    assert adaptive.tag == "adaptive-icon"
    assert (APP / "web/index.html").read_text().count('href="favicon.png"') == 1
    assert 'Icon-maskable-512.png' in (APP / "web/manifest.json").read_text()
    print("PASS: Sukun official favicon, PWA and Android launchers; no APK built")


if __name__ == "__main__":
    main()
