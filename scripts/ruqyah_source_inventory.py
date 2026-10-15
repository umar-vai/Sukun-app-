#!/usr/bin/env python3
"""Read-only inventory of authorized Ruqyah Ayat site's eight topic pages.

Never copies data into production automatically. Outputs an artifact for
manual, item-by-item review: Arabic exactness, Bangla wording, and audio URLs.
"""
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse
import requests
from bs4 import BeautifulSoup

ROOT = Path(os.environ.get("OUTPUT_DIR", "ruqyah-source-review"))
ROOT.mkdir(parents=True, exist_ok=True)
HOSTS = {"ayat.ruqyahbd.org", "pro.ruqyahbd.org"}
HEADERS = {"User-Agent": "SukunLifeAuthorizedQA/1.0 (+content permission)"}
CATEGORY_NAMES = [
    "বেসিক রুকইয়াহ",
    "রুকইয়ার আয়াত",
    "রুকইয়ার দোয়া",
    "বদনজরের আয়াত",
    "সিহরের আয়াত",
    "আয়াতুশ শিফা",
    "আয়াতুল হারক",
    "আয়াতুস সাকিনাহ",
]

def allowed(uri):
    try:
        parsed = urlparse(uri)
        return parsed.scheme == "https" and parsed.hostname in HOSTS
    except Exception:
        return False

def get_html(index):
    urls = [f"https://ayat.ruqyahbd.org/{index}",
            f"https://pro.ruqyahbd.org/ayat/{index}"]
    failures = []
    for url in urls:
        try:
            response = requests.get(url, headers=HEADERS, timeout=23,
                                    allow_redirects=False)
            if response.status_code == 200 and len(response.content) > 900:
                return url, response.text
            failures.append(f"{response.status_code}/{len(response.content)}")
        except requests.RequestException as error:
            failures.append(type(error).__name__)
    raise ValueError(f"Section {index} sources unavailable: {','.join(failures)}")

def inventory(index, url, html):
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()
    text = soup.get_text("\n", strip=True)
    media = set()
    for tag in soup.select("audio, source, a, [src], [data-src], [data-audio], [data-url]"):
        for attr in ("src", "href", "data-src", "data-audio", "data-url"):
            raw = tag.get(attr)
            if not isinstance(raw, str) or not raw.strip():
                continue
            target = urljoin(url, raw.strip())
            parsed = urlparse(target)
            if parsed.scheme == "https" and (
                re.search(r"\.(mp3|ogg|m4a|wav|aac)(?:[?#]|$)", parsed.path+"?"+parsed.query, re.I)
                or "audio" in parsed.path.lower()
            ):
                media.add(target)
    elements = []
    for el in soup.select("h1, h2, h3, h4, p, audio, source, button, [role=button]")[:80]:
        entry = {"tag": el.name, "class": " ".join(el.get("class", [])[:3]),
                 "text_preview": el.get_text(" ", strip=True)[:72]}
        elements.append(entry)
    normalized = {
        "section": index,
        "title_expected": CATEGORY_NAMES[index-1],
        "source_url": url,
        "html_sha256": hashlib.sha256(html.encode()).hexdigest(),
        "headings": [h.get_text(" ", strip=True)[:130] for h in soup.select("h1,h2")[:25]],
        "text_length": len(text),
        "has_arabic": bool(re.search("[\u0600-\u06ff]", text)),
        "audio_url_count": len(media),
        "audio_urls": sorted(media),
        "element_structure": elements,
    }
    (ROOT / f"{index:02d}-source.html").write_text(html, encoding="utf-8")
    (ROOT / f"{index:02d}-text.txt").write_text(text, encoding="utf-8")
    (ROOT / f"{index:02d}-inventory.json").write_text(
        json.dumps(normalized, ensure_ascii=False, indent=2), encoding="utf-8")
    return normalized

def main():
    summary=[]
    for i in range(1,9):
        try:
            url, html=get_html(i)
            item=inventory(i,url,html)
            summary.append({"id":i,"ok":True,"title":item["headings"][:2],
                            "chars":item["text_length"],
                            "audio_count":item["audio_url_count"]})
            print(f"SECTION_{i} status=extracted chars={item['text_length']} "
                  f"audio={item['audio_url_count']} headings={item['headings'][:2]}",
                  flush=True)
        except Exception as error:
            summary.append({"id":i,"ok":False,"error":str(error)})
            print(f"SECTION_{i} status=unavailable reason={str(error)[:140]}",flush=True)
        time.sleep(0.3)
    (ROOT/"summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    # Vite SPA: the HTML is only an app shell. Inspect referenced source assets
    # separately; do not fabricate "extracted" content from an empty DOM.
    try:
        first=(ROOT/"01-source.html").read_text(encoding="utf-8")
        soup=BeautifulSoup(first,"html.parser")
        app_scripts=[x["src"] for x in soup.select("script[src]")
                     if x["src"].startswith("/assets/")]
        print("SPA_BUNDLES="+str(len(app_scripts)))
        for index,script in enumerate(app_scripts[:4]):
            url=urljoin("https://ayat.ruqyahbd.org",script)
            response=requests.get(url,headers=HEADERS,timeout=55)
            if response.status_code != 200:
                print("SPA_BUNDLE_FETCH_STATUS="+str(response.status_code))
                continue
            content=response.text
            (ROOT/f"bundle-{index}.js").write_text(content,encoding="utf-8")
            arabic=len(re.findall("[\\u0600-\\u06ff]",content))
            urls=sorted(set(re.findall(r'https?://[^\\s"\\x27<>]{4,180}',content)))
            audio=[x for x in urls if re.search(r'mp3|m4a|audio|\.ogg',x,re.I)]
            markers={phrase:content.count(phrase) for phrase in
                     ("بেসিক রুকইয়াহ","رَبِّ","arabicText","audioUrl","mp3","firebase")}
            print(f"SPA_BUNDLE_{index} bytes={len(content)} arabic_chars={arabic} audio_candidate_count={len(audio)} markers={markers}",flush=True)
            (ROOT/f"bundle-{index}-audio-candidates.json").write_text(
               json.dumps(audio,ensure_ascii=False,indent=2),encoding="utf-8")
    except Exception as exc:
        print("SPA_BUNDLE_INVENTORY_ERROR="+str(exc)[:145],flush=True)
    print(f"EXTRACTED_SECTIONS={sum(x['ok'] and x['chars']>1000 for x in summary)}")

    # Inventory is allowed to be partial but must be recorded honestly.
    if not any(x['ok'] for x in summary):
        sys.exit(1)

if __name__=="__main__":
    main()
