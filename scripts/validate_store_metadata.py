#!/usr/bin/env python3
"""Validate localized App Store copy before it is sent to App Store Connect."""
from __future__ import annotations

import json
from pathlib import Path

LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotionalText": 170,
    "description": 4000,
    "keywords": 100,
}


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "store-assets" / "metadata"
    failed = False
    for path in sorted(root.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        locale = data.get("locale", path.stem)
        for field, limit in LIMITS.items():
            length = len(data[field])
            if length > limit:
                failed = True
                print(f"ERROR {locale} {field}: {length}/{limit}")
        keyword_count = len([item for item in data["keywords"].split(",") if item.strip()])
        print(
            f"{locale}: subtitle {len(data['subtitle'])}/30, "
            f"promo {len(data['promotionalText'])}/170, "
            f"keywords {len(data['keywords'])}/100 ({keyword_count} terms), "
            f"description {len(data['description'])}/4000"
        )
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
