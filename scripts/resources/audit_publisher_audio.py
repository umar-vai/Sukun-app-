#!/usr/bin/env python3
"""Read-only audit of publisher-hosted audio URLs: compare short byte samples.

This script NEVER downloads complete MP3s, stores patient data or rehosts media.
External host availability is advisory and does not gate local Flutter builds.
"""
import concurrent.futures
import hashlib
import json
import pathlib
import urllib.request
import urllib.error

ASSET = pathlib.Path("app/assets/data/ruqyahbd_book_audio_crosswalk.json")
MAX_BYTES = 128 * 1024
def sample(entry):
    url = entry["media_url"]
    if not url.startswith("https://files.ruqyahbd.org/"):
        return entry["id"], "REFUSED: untrusted media host", "", "", 0
    req = urllib.request.Request(url, headers={
        "User-Agent": "SukunLifeAudioUrlAudit/1.0",
        "Range": f"bytes=0-{MAX_BYTES-1}",
        "Accept": "audio/mpeg, audio/mp3, */*",
    })
    try:
        with urllib.request.urlopen(req, timeout=14) as response:
            payload = response.read(MAX_BYTES)
            content_type = response.headers.get("Content-Type", "").split(";")[0]
            digest = hashlib.sha256(payload).hexdigest()[:24] if payload else ""
            return entry["id"], f"HTTP {response.status} / {content_type}", digest, response.url, len(payload)
    except Exception as exc:
        return entry["id"], f"UNAVAILABLE: {str(exc)[:120]}", "", url, 0

def main():
    entries = json.loads(ASSET.read_text(encoding="utf-8"))["entries"]
    print(f"Auditing {len(entries)} publisher-hosted URLs; maximum {MAX_BYTES} bytes per track, in memory only.")
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(sample, entries))
    seen = {}
    missing = []
    duplicates = []
    for key, status, fingerprint, url, length in results:
        print(f"{key}: {status} | sample={length} sha256-prefix={fingerprint} | {url}")
        if not fingerprint:
            missing.append(key)
        elif fingerprint in seen:
            duplicates.append((seen[fingerprint], key))
        else:
            seen[fingerprint] = key
    print(f"Unique media samples: {len(seen)}; unavailable: {len(missing)}; duplicate samples: {len(duplicates)}")
    if duplicates:
        print("REVIEW DUPLICATE MEDIA RESPONSES:", duplicates)
    if missing:
        print("REVIEW UNAVAILABLE URLS:", missing)
    if duplicates or missing:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
