#!/usr/bin/env python3
"""Read-only browser CORS / range probe of owner-attested public audio.

Uses only 32 response bytes per file. No patient accounts, auth tokens,
production Supabase, downloads to disk, or media redistribution.
A failed external-host probe is diagnostic; it must not be misreported as a
working browser download or be used to weaken rights/security checks.
"""
from __future__ import annotations

import json
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

ORIGIN = "https://app.sukunlife.com"
SOURCE = (
    pathlib.Path(__file__).resolve().parents[2]
    / "app/assets/data/ruqyahbd_book_audio_crosswalk.json"
)


def probe(label: str, url: str) -> bool:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "files.ruqyahbd.org":
        print(f"FAIL {label}: unauthorized probe host")
        return False
    request = urllib.request.Request(
        url,
        headers={
            "Origin": ORIGIN,
            "Range": "bytes=0-127",
            "User-Agent": "SukunLife-WebOffline-Acceptance/1.0",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=18) as response:
            final = urllib.parse.urlparse(response.geturl())
            if final.scheme != "https" or final.hostname != parsed.hostname:
                print(f"FAIL {label}: unexpected redirect host")
                return False
            cors = response.headers.get("Access-Control-Allow-Origin", "")
            response_type = response.headers.get("Content-Type", "").lower()
            range_result = response.headers.get("Content-Range", "")
            sample = response.read(32)
            cors_ok = cors in ("*", ORIGIN)
            audio_ok = (
                "audio/" in response_type
                or "application/octet-stream" in response_type
                or sample.startswith(b"ID3")
                or (len(sample) > 1 and sample[0] == 0xFF and sample[1] & 0xE0 == 0xE0)
            )
            print(
                f"{'PASS' if cors_ok and audio_ok else 'FAIL'} {label}: "
                f"HTTP {response.status}, CORS={'yes' if cors_ok else 'no'}, "
                f"audio={'yes' if audio_ok else 'no'}, "
                f"range={'yes' if bool(range_result) else 'no'}"
            )
            return cors_ok and audio_ok
    except (TimeoutError, OSError, urllib.error.URLError) as exc:
        print(f"UNVERIFIED {label}: external host unavailable ({type(exc).__name__})")
        return False


def main() -> int:
    entries = json.loads(SOURCE.read_text(encoding="utf-8"))["entries"]
    approved = [
        item for item in entries
        if item.get("licensing") == "owner_attested_for_sukun_life_app_2026_10_12"
        and item.get("media_url", "").startswith("https://files.ruqyahbd.org/")
    ]
    # Test across /audio/ and /clips/ instead of copying the entire catalog.
    selected = []
    for prefix in ("/audio/", "/clips/"):
        match = next(
            (item for item in approved
             if urllib.parse.urlparse(item["media_url"]).path.startswith(prefix)),
            None,
        )
        if match is not None:
            selected.append(match)
    if not selected:
        print("FAIL: no approved catalog recordings found")
        return 1
    passed = [
        probe(f"approved-recording-{index + 1}", item["media_url"])
        for index, item in enumerate(selected)
    ]
    print(f"Browser HTTPS audio host capability: {sum(passed)}/{len(passed)}")
    return 0 if all(passed) else 1


if __name__ == "__main__":
    sys.exit(main())
