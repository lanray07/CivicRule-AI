#!/usr/bin/env python3
"""Turn real Simulator captures into App Store screenshots with localized copy."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SCENES = ("welcome", "overview", "checklist", "voice", "documents", "lease", "permits", "sources", "privacy", "address")
FOOTERS = {
    "welcome": "Plain-English guidance • Sources included",
    "overview": "Business profile • Permit dates • Records",
    "checklist": "Planning • Licences • Signage • Premises",
    "voice": "On-device voice transcription",
    "documents": "Original document always in view",
    "lease": "Planning • Access • Fire safety • Opening hours",
    "permits": "References • Renewal dates • Reminders",
    "sources": "Official source • Checked date • Limitations",
    "privacy": "Local records • Optional app lock • Data export",
    "address": "Planning • Licensing • Signage • Property conditions",
}
FOREST = "#123F34"
LIME = "#D3EF7A"
CREAM = "#F6F2E9"
WHITE = "#FFFFFF"


def font_path(bold: bool) -> str:
    choices = [
        Path("C:/Windows/Fonts/seguisb.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
        Path("/System/Library/Fonts/SFNS.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for candidate in choices:
        if candidate.exists():
            return str(candidate)
    raise FileNotFoundError("No supported UI font was found")


def wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for word in text.split():
        trial = f"{current} {word}".strip()
        if current and draw.textbbox((0, 0), trial, font=font)[2] > max_width:
            lines.append(current)
            current = word
        else:
            current = trial
    if current:
        lines.append(current)
    return lines


def compose(source: Path, destination: Path, headline: str, footer: str) -> None:
    shot = Image.open(source).convert("RGB")
    width, height = shot.size
    is_tablet = width >= height * 0.65
    header = int(height * (0.18 if not is_tablet else 0.16))
    canvas = Image.new("RGB", (width, height), FOREST)
    draw = ImageDraw.Draw(canvas)
    margin = int(width * 0.07)
    kicker_font = ImageFont.truetype(font_path(True), max(24, int(width * 0.026)))
    # Tablet screenshots have a wider canvas, so the phone scale makes a
    # two-line headline collide with the keyword line below it.
    headline_scale = 0.046 if is_tablet else 0.058
    headline_font = ImageFont.truetype(font_path(True), max(48, int(width * headline_scale)))
    footer_font = ImageFont.truetype(font_path(False), max(24, int(width * 0.027)))

    kicker = "CIVICRULE AI  •  SMALL BUSINESS"
    kicker_box = draw.textbbox((0, 0), kicker, font=kicker_font)
    pill_width = kicker_box[2] + int(width * 0.05)
    pill_y = int(header * 0.12)
    pill_pad_y = max(12, int(kicker_font.size * 0.35))
    pill_height = (kicker_box[3] - kicker_box[1]) + pill_pad_y * 2
    draw.rounded_rectangle((margin, pill_y, margin + pill_width, pill_y + pill_height), radius=999, fill=LIME)
    draw.text((margin + int(width * 0.025), pill_y + pill_pad_y - kicker_box[1]), kicker, font=kicker_font, fill=FOREST)
    y = int(header * 0.34)
    for line in wrap(draw, headline, headline_font, width - margin * 2):
        draw.text((margin, y), line, font=headline_font, fill=WHITE)
        y += int(headline_font.size * 1.08)
    draw.text((margin, header - int(header * 0.14)), footer, font=footer_font, fill=CREAM)

    card_margin = int(width * 0.045)
    available_w = width - card_margin * 2
    available_h = height - header - int(height * 0.018)
    scale = min(available_w / width, available_h / height)
    rendered = shot.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    radius = max(24, int(width * 0.035))
    mask = Image.new("L", rendered.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, rendered.width, rendered.height), radius=radius, fill=255)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sx = (width - rendered.width) // 2
    sy = header
    ImageDraw.Draw(shadow).rounded_rectangle((sx, sy + 10, sx + rendered.width, sy + rendered.height + 10), radius=radius, fill=(0, 0, 0, 95))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(8, int(width * 0.018))))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.paste(rendered, (sx, sy), mask)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("build/store-captures"))
    parser.add_argument("--locale", default="en-GB")
    parser.add_argument("--output", type=Path, default=Path("store-assets/screenshots"))
    args = parser.parse_args()
    metadata = json.loads((Path("store-assets/metadata") / f"{args.locale}.json").read_text(encoding="utf-8"))
    for device in ("iphone", "ipad"):
        for number, scene in enumerate(SCENES, 1):
            source = args.source / device / f"{scene}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            destination = args.output / args.locale / device / f"{number:02d}-{scene}.png"
            compose(source, destination, metadata["screenshotHeadlines"][scene], FOOTERS[scene])
            print(destination)


if __name__ == "__main__":
    main()
