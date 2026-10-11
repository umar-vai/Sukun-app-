#!/usr/bin/env python3
"""Repair visible Bengali glyphs in a public PDF without changing its text.

This addresses *already embedded* but broken font glyph outlines (e.g.
Leelawadee UI Semilight in the Sukun guide). A PdfFontResolver for missing
fonts cannot change glyphs which the PDF has embedded incorrectly.

Keep the author's original PDF unchanged. Write a separate reviewer copy.
Original searchable text remains underneath transparent page overlays.
"""
from __future__ import annotations

import argparse
import io
import subprocess
from pathlib import Path

import fitz
from PIL import Image, ImageDraw, ImageFont, features


def is_bengali(text: str) -> bool:
    return any("\u0980" <= ch <= "\u09ff" for ch in text)


def font_path(face: str = "Noto Sans Bengali") -> str:
    value = subprocess.check_output(
        ["fc-match", "-f", "%{file}", face], text=True
    ).strip()
    if not value or not Path(value).is_file():
        raise RuntimeError("No authorized, locally installed Bengali font")
    return value


def render_overlay(page: fitz.Page, face: str, scale: float = 3.5):
    if not features.check("raqm"):
        raise RuntimeError("Pillow must have libraqm complex-text shaping enabled")
    width = int(round(page.rect.width * scale))
    height = int(round(page.rect.height * scale))
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    background = ImageDraw.Draw(result)
    spans = []
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                content = span.get("text", "")
                if is_bengali(content):
                    spans.append(span)
    if not spans:
        return None, 0

    # Suppress the old embedded .notdef squares. This leaves all existing PDF
    # searchable text in the underlying content stream untouched.
    for span in spans:
        x0, y0, x1, y1 = span["bbox"]
        if x1 <= x0 or y1 <= y0:
            continue
        background.rectangle(
            (max(0, round((x0 - 0.3) * scale)),
             max(0, round((y0 - 0.3) * scale)),
             min(width, round((x1 + 0.3) * scale)),
             min(height, round((y1 + 0.3) * scale))),
            fill=(255, 255, 255, 255),
        )

    font_regular = font_path(face)
    font_bold = font_path(face + ":style=Bold")
    font_cache = {}
    count = 0
    for span in spans:
        text = span["text"]
        x0, y0, x1, y1 = span["bbox"]
        font_size = max(6, round(span["size"] * scale))
        key = ("bold" if "bold" in span["font"].lower() else "regular", font_size)
        if key not in font_cache:
            font_cache[key] = ImageFont.truetype(
                font_bold if key[0] == "bold" else font_regular,
                font_size,
                layout_engine=ImageFont.Layout.RAQM,
            )
        font = font_cache[key]
        bbox = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox(
            (0, 0), text, font=font, anchor="ls", direction="ltr", language="bn"
        )
        w = max(1, bbox[2] - bbox[0])
        h = max(1, bbox[3] - bbox[1])
        ink = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
        ImageDraw.Draw(ink).text(
            (1 - bbox[0], 1 - bbox[1]), text,
            font=font, fill=(0, 0, 0, 255),
            anchor="ls", direction="ltr", language="bn",
        )

        target_w = max(1, int((x1 - x0) * scale))
        target_h = max(1, int((y1 - y0) * scale))
        ink_scale = min(1.0, target_w / max(1, ink.width), target_h / max(1, ink.height))
        if ink_scale < 0.999:
            ink = ink.resize(
                (max(1, int(ink.width * ink_scale)),
                 max(1, int(ink.height * ink_scale))),
                Image.Resampling.LANCZOS,
            )
        px = round(x0 * scale)
        py = round(y0 * scale + (target_h - ink.height) / 2)
        result.alpha_composite(ink, (max(0, px), max(0, py)))
        count += 1
    return result, count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--page", type=int, help="1-indexed proof page; omit for entire book")
    args = ap.parse_args()

    source = fitz.open(args.source)
    pages = [args.page - 1] if args.page else range(len(source))
    if args.page and not (1 <= args.page <= len(source)):
        ap.error("Page is outside PDF")
    fixed_pages = 0
    glyph_spans = 0
    for number in pages:
        page = source[number]
        img, count = render_overlay(page, "Noto Sans Bengali")
        if img is None:
            continue
        glyph_spans += count
        binary = io.BytesIO()
        img.save(binary, format="PNG", optimize=True)
        page.insert_image(page.rect, stream=binary.getvalue(),
                          keep_proportion=False, overlay=True)
        fixed_pages += 1

    # For proof-run, output a single-page PDF to reduce artifact size.
    if args.page:
        output = fitz.open()
        output.insert_pdf(source, from_page=args.page - 1, to_page=args.page - 1)
        output.save(args.output, garbage=4, deflate=True)
    else:
        source.save(args.output, garbage=4, deflate=True)
    print("FIXED_PAGES", fixed_pages)
    print("FIXED_BENGALI_SPANS", glyph_spans)
    print("OUTPUT_BYTES", args.output.stat().st_size)
    print("RETAINED_TEXT_LAYER", True)


if __name__ == "__main__":
    main()
