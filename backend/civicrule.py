"""Source-gated pilot. No model-memory regulatory answers; Python 3.10+, stdlib only."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import sqlite3
import ssl
import uuid
from datetime import datetime, timezone, timedelta
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, build_opener, HTTPSHandler, HTTPRedirectHandler

ROOT = Path(__file__).resolve().parent
SOURCE_URL = "https://www.gov.uk/government/publications/pavement-licences-guidance/pavement-licences-guidance"
CATALOG = {
    "england-pavement": {
        "id": "england-pavement", "url": SOURCE_URL,
        "authority": "Ministry of Housing, Communities and Local Government",
        "title": "Pavement licences: guidance", "jurisdiction": "England",
        "publicationDate": "2024-04-02", "section": "1.1 What is a pavement licence?",
        "excerpt": "Where a pavement licence is granted, clear access routes on the highway will need to be maintained",
        "summary": "The official England guidance describes pavement licences for removable furniture on certain highways beside premises. It also requires clear access routes. Whether this route applies to your proposal needs confirmation with the local authority.",
        "checks": ["Confirm whether the proposed seating area is public highway", "Ask the local authority which application route applies", "Verify local conditions, operating hours and accessible clearances"],
    }
}


def now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(value: datetime | None = None) -> str:
    return (value or now()).isoformat()


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


class MainText(HTMLParser):
    """Ignore chrome and formatting; compare the main text, not raw HTML."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.in_main = False
        self.hidden = 0
        self.parts: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag == "main": self.in_main = True
        if tag in ("script", "style"): self.hidden += 1

    def handle_endtag(self, tag):
        if tag == "main": self.in_main = False
        if tag in ("script", "style"): self.hidden = max(0, self.hidden - 1)

    def handle_data(self, data):
        if self.in_main and not self.hidden: self.parts.append(data)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Source moved; review the canonical URL before following a redirect")


class RegulatoryRetrievalService:
    def find_official_sources(self, nation: str) -> list[dict]:
        return [dict(source) for source in CATALOG.values() if source["jurisdiction"] == nation]

    def retrieve(self, url: str) -> str:
        # Only exact editorially configured URLs are fetched. No user URL, wildcard or redirect.
        if url not in {source["url"] for source in CATALOG.values()}:
            raise ValueError("Source URL is not allowlisted")
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != "www.gov.uk" or parsed.username or parsed.port:
            raise ValueError("Invalid official source URL")
        opener = build_opener(NoRedirect(), HTTPSHandler(context=ssl.create_default_context()))
        with opener.open(Request(url, headers={"User-Agent": "CivicRulePilot/0.1 source verification"}), timeout=20) as response:
            if "text/html" not in response.headers.get("Content-Type", ""):
                raise ValueError("Expected HTML; source needs review")
            raw = response.read(2_000_001)
            if len(raw) > 2_000_000: raise ValueError("Source exceeds size limit")
            parser = MainText()
            parser.feed(raw.decode("utf-8"))
            text = normalize(" ".join(parser.parts))
            if len(text) < 200: raise ValueError("Source extraction incomplete")
            return text


class RegulationSourceRepository:
    def __init__(self, path: str | Path):
        self.path = str(path)
        if self.path != ":memory:": Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.path)
        self.db.row_factory = sqlite3.Row
        self.db.executescript("""
        CREATE TABLE IF NOT EXISTS sources (
          id TEXT PRIMARY KEY, body TEXT NOT NULL, hash TEXT NOT NULL,
          checked_at TEXT NOT NULL, approved_hash TEXT, error TEXT);
        CREATE TABLE IF NOT EXISTS changes (
          id TEXT PRIMARY KEY, source_id TEXT NOT NULL, previous TEXT NOT NULL,
          current TEXT NOT NULL, detected_at TEXT NOT NULL);
        """)

    def get(self, source_id: str):
        row = self.db.execute("SELECT * FROM sources WHERE id=?", (source_id,)).fetchone()
        return dict(row) if row else None

    def record(self, source_id: str, body: str, checked: datetime | None = None):
        normalized = normalize(body)
        digest = hashlib.sha256(normalized.encode()).hexdigest()
        previous = self.get(source_id)
        with self.db:
            if previous and previous["hash"] != digest:
                self.db.execute("INSERT INTO changes VALUES (?,?,?,?,?)", (str(uuid.uuid4()), source_id, previous["body"], normalized, stamp(checked)))
            self.db.execute("""INSERT INTO sources VALUES (?,?,?,?,NULL,NULL)
              ON CONFLICT(id) DO UPDATE SET body=excluded.body, hash=excluded.hash,
              checked_at=excluded.checked_at, error=NULL""", (source_id, normalized, digest, stamp(checked)))
        return digest

    def fail(self, source_id: str, error: str):
        with self.db: self.db.execute("UPDATE sources SET error=? WHERE id=?", (error, source_id))

    def approve(self, source_id: str, expected_hash: str):
        row = self.get(source_id)
        if not row or not hmac.compare_digest(row["hash"], expected_hash):
            raise ValueError("Source changed since review")
        if row["error"] or normalize(CATALOG[source_id]["excerpt"]) not in row["body"]:
            raise ValueError("Review failed: source unavailable or supporting excerpt missing")
        with self.db: self.db.execute("UPDATE sources SET approved_hash=? WHERE id=?", (expected_hash, source_id))

    def close(self): self.db.close()


class SourceFreshnessService:
    max_age = timedelta(hours=24)

    def usable(self, row: dict | None, at: datetime | None = None) -> bool:
        if not row or row["error"] or row["hash"] != row["approved_hash"]: return False
        try:
            age = (at or now()) - datetime.fromisoformat(row["checked_at"])
            return timedelta(0) <= age <= self.max_age
        except (ValueError, TypeError): return False


class JurisdictionResolver:
    def resolve(self, request: dict) -> tuple[str | None, str | None]:
        nation = request.get("nation", "").strip()
        if not nation: return None, "Which country or UK nation is the business in?"
        if nation != "England": return None, "Verified guidance for this jurisdiction is not available in the pilot."
        if not request.get("authority", "").strip(): return None, "Which local authority is responsible for the premises? Confirm it using the official council finder."
        if not request.get("businessType", "").strip(): return None, "What type of business are you planning?"
        return nation, None


class RegulatoryAnswerService:
    def __init__(self, repository: RegulationSourceRepository): self.repository = repository

    def answer(self, request: dict) -> dict:
        question = request.get("question", "").strip()
        if not question or len(question) > 4000: raise ValueError("Question must contain 1–4000 characters")
        result = dict(id=str(uuid.uuid4()), question=question, shortAnswer="", checks=[], sources=[], confidence="Limited", reason="No sufficiently verified evidence is available.", limitations=["Informational assistance, not legal advice or a compliance certificate."], status="unavailable", answeredAt=stamp())
        nation, clarification = JurisdictionResolver().resolve(request)
        if clarification:
            result["shortAnswer"] = clarification
            result["status"] = "needs_context" if not request.get("nation") or nation is None and request.get("nation") == "England" else "unavailable"
            return result
        text = question.lower()
        furniture = bool(re.search(r"\b(tables?|chairs?|seating|furniture)\b", text))
        outside = bool(re.search(r"\b(outside|outdoor|pavement|highway)\b", text))
        # This pilot only routes one domain; mixed topics are not silently answered.
        other_topics = bool(re.search(r"\b(alcohol|signage|sign|music|midnight|food hygiene|planning|waste)\b", text))
        if not furniture or not outside or other_topics:
            result["shortAnswer"] = "This pilot only has reviewed England pavement-seating guidance. I cannot reliably answer this question from the available sources. Please narrow the question or contact the responsible authority."
            return result
        source = dict(CATALOG["england-pavement"])
        row = self.repository.get(source["id"])
        if not SourceFreshnessService().usable(row):
            result["shortAnswer"] = "The relevant official source is not recently verified or has a change awaiting review. No regulatory conclusion is available."
            return result
        if normalize(source["excerpt"]) not in row["body"]:
            result["shortAnswer"] = "The source no longer supports the reviewed explanation. It needs review before an answer can be shown."
            return result
        result.update(shortAnswer=source.pop("summary"), checks=source.pop("checks"), confidence="Moderate", reason="Reviewed national guidance directly addresses pavement seating. Local and property-specific conditions have not been verified.", status="answered")
        source.update(checkedAt=row["checked_at"], contentHash=row["hash"])
        result["sources"] = [source]
        result["limitations"] += ["England national guidance only. The entered local authority is user-provided and has not been independently resolved.", "Local conditions, land ownership, fees, opening hours and the status of your premises have not been checked."]
        return result


def validate_payload(payload):
    if not isinstance(payload, dict): raise ValueError("Expected an object")
    for key in ("question", "nation", "authority", "businessType", "activities"):
        if not isinstance(payload.get(key, ""), str) or len(payload.get(key, "")) > 4000:
            raise ValueError("Invalid context field")
    return payload


def handler(database: Path, token: str):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_): pass  # Never log business questions, tokens or request bodies.

        def respond(self, code, value):
            data = json.dumps(value).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/health": self.respond(200, {"status": "ok", "coverage": "England pavement-seating pilot"})
            else: self.respond(404, {"error": "Not found"})

        def do_POST(self):
            if self.path != "/v1/answers": self.respond(404, {"error": "Not found"}); return
            if not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + token):
                self.respond(401, {"error": "Unauthorized"}); return
            if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                self.respond(415, {"error": "Expected application/json"}); return
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 24_000: self.respond(413, {"error": "Request size exceeds limit"}); return
                self.connection.settimeout(10)
                payload = validate_payload(json.loads(self.rfile.read(size)))
                repo = RegulationSourceRepository(database)
                try: result = RegulatoryAnswerService(repo).answer(payload)
                finally: repo.close()
                self.respond(200, result)
            except (ValueError, UnicodeError): self.respond(400, {"error": "Invalid request"})
            except Exception: self.respond(503, {"error": "Source service unavailable"})
    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["serve", "refresh", "review", "approve"])
    parser.add_argument("--database", type=Path, default=ROOT / "data" / "sources.sqlite")
    parser.add_argument("--source", default="england-pavement", choices=list(CATALOG))
    parser.add_argument("--hash")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    if args.command == "serve":
        token = os.environ.get("CIVICRULE_API_TOKEN", "")
        if len(token) < 32: parser.error("Set CIVICRULE_API_TOKEN to a random secret of at least 32 characters")
        ThreadingHTTPServer(("127.0.0.1", args.port), handler(args.database, token)).serve_forever()
        return
    repo = RegulationSourceRepository(args.database)
    try:
        if args.command == "refresh":
            for key, source in CATALOG.items():
                try:
                    digest = repo.record(key, RegulatoryRetrievalService().retrieve(source["url"]))
                    print(json.dumps({"source": key, "hash": digest, "needsReview": repo.get(key)["approved_hash"] != digest}))
                except Exception as error:
                    repo.fail(key, str(error)); raise
        elif args.command == "review": print(json.dumps(repo.get(args.source), indent=2))
        elif args.command == "approve":
            if not args.hash: parser.error("--hash is required; inspect the exact source version first")
            repo.approve(args.source, args.hash)
            print("Approved exact reviewed source version")
    finally: repo.close()


if __name__ == "__main__": main()

