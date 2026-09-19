#!/usr/bin/env python3
"""Create or update reviewed App Store localizations through the ASC API.

The checked-in locale files are the translation memory. CI validates them on
every change; a manual workflow dispatch can preview or publish the exact copy.
Secrets stay in GitHub Actions and are never printed.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

import jwt

APP_ID = "6811508379"
API = "https://api.appstoreconnect.apple.com/v1"


def auth_token() -> str:
    key = os.environ["ASC_PRIVATE_KEY"].strip()
    if not key.startswith("-----BEGIN"):
        key = base64.b64decode(key).decode()
    key = key.replace("\\n", "\n")
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


class ASC:
    def __init__(self) -> None:
        self.token = auth_token()

    def request(self, method: str, path: str, payload: dict | None = None) -> dict:
        body = json.dumps(payload).encode() if payload else None
        request = urllib.request.Request(
            API + path,
            data=body,
            method=method,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response) if response.length != 0 else {}


def metadata_files() -> list[dict]:
    root = Path(__file__).resolve().parents[1] / "store-assets" / "metadata"
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(root.glob("*.json"))]


def version_id(api: ASC) -> str:
    query = urllib.parse.urlencode({"filter[app]": APP_ID, "filter[platform]": "IOS", "limit": "50"})
    versions = api.request("GET", f"/appStoreVersions?{query}")["data"]
    candidates = [item for item in versions if item["attributes"].get("versionString") == "1.0"]
    if not candidates:
        raise RuntimeError("App Store version 1.0 was not found")
    return candidates[0]["id"]


def publish_version_locales(api: ASC, vid: str, locales: list[dict], dry_run: bool) -> None:
    existing = api.request("GET", f"/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=200")["data"]
    by_locale = {item["attributes"]["locale"]: item["id"] for item in existing}
    for item in locales:
        attrs = {key: item[key] for key in ("locale", "description", "keywords", "marketingUrl", "promotionalText", "supportUrl")}
        locale = item["locale"]
        action = "update" if locale in by_locale else "create"
        print(f"{action} version localization {locale}")
        if dry_run:
            continue
        if locale in by_locale:
            ident = by_locale[locale]
            api.request("PATCH", f"/appStoreVersionLocalizations/{ident}", {"data": {"type": "appStoreVersionLocalizations", "id": ident, "attributes": attrs}})
        else:
            api.request("POST", "/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": attrs, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--publish", action="store_true", help="Write reviewed localizations instead of previewing")
    args = parser.parse_args()
    api = ASC()
    locales = metadata_files()
    publish_version_locales(api, version_id(api), locales, not args.publish)


if __name__ == "__main__":
    main()
