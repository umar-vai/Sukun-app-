#!/usr/bin/env python3
"""Offline, NO NETWORK: convert a PRIVATE source catalog into Admin CMS draft inputs.

Input and output contain protected editorial text. Run only on an authorized,
encrypted operator workstation; never commit outputs or send them to CI.
Generated items are DRAFT + STAFF-ONLY, not approved patient resources.
"""
import argparse
import json
import os
import pathlib
import re
import sys
import uuid

EXPECTED_HASH = "8b9af4677cec5c4b8964a431a47c076a7a59e862d91606caede8ad6141257f24"
NAMESPACE = uuid.UUID("af35f2aa-27b4-4297-8732-6d3490d70144")
KINDS = {"dua", "quran", "amal", "supplement", "ghusl", "ruqyah_guide", "prayer_collection"}
SOURCE_REF = "সেলফ রুকইয়াহ গাইড · ইবনে ইসহাক · চেতনা প্রকাশন (নভেম্বর ২০২৪)"

def required_text(value, label):
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Missing or invalid " + label)
    return value.strip()

def nonempty(value):
    return value.strip() if isinstance(value, str) and value.strip() else None

def prepare(data):
    source = data.get("source") or {}
    if source.get("sha256") != EXPECTED_HASH:
        raise ValueError("Source checksum mismatch; refusing unrelated source")
    rows = data.get("entries")
    if not isinstance(rows, list) or not rows:
        raise ValueError("No private editorial entries found")
    seen = set()
    result = []
    for row in rows:
        identifier = required_text(row.get("resource_id"), "resource_id")
        if identifier in seen or not re.fullmatch(r"SRG2024-[A-Z]{3}-\d{3}", identifier):
            raise ValueError("Duplicate/invalid editorial resource ID: " + identifier)
        seen.add(identifier)
        kind = row.get("type")
        if kind not in KINDS:
            raise ValueError("Unsupported source type: " + repr(kind))
        if row.get("source_file_sha256") != EXPECTED_HASH:
            raise ValueError("Entry references wrong original: " + identifier)
        if row.get("visibility") != "staff_only" or row.get("content_review") != "draft":
            raise ValueError("Unsafe source status or visibility: " + identifier)
        if row.get("auto_assignment_allowed") is not False:
            raise ValueError("Auto-assignment must remain false: " + identifier)
        title = required_text(row.get("title_bn"), "title_bn")
        paragraph = required_text(str(row.get("source_paragraph_index_zero_based", "")), "paragraph_index")
        section = required_text(row.get("source_section"), "source_section")
        page = nonempty(row.get("source_book_page_hint"))
        # Quran text blocks are not yet verified individual verses. Do not
        # manufacture Surah/Ayah metadata or register them as canonical Quran.
        content_type = {
            "dua": "dua", "quran": "article", "amal": "amal",
            "supplement": "article", "ghusl": "article",
            "ruqyah_guide": "article", "prayer_collection": "dua"
        }[kind]
        raw_arabic = nonempty(row.get("arabic_text_as_in_source"))
        bangla_description = nonempty(row.get("source_description_as_in_source"))
        bangla_meaning = nonempty(row.get("bangla_meaning_as_in_source"))
        source_reference = SOURCE_REF + " · " + section + (" · পৃ. " + page if page else "") + " · paragraph " + paragraph
        summary = (
            "Unverified original Quran text block; Surah/Ayah references pending human review."
            if kind == "quran" else
            "Editorial draft from owner-provided source; reference and translation pending human review."
        )
        result.append({
            "source_resource_id": identifier,
            "source_category": kind,
            "approved_for_patient": False,
            "needs_canonical_review": kind in {"quran", "dua", "prayer_collection"},
            "needs_clinical_review": kind in {"ghusl", "supplement"},
            "input": {
                "type": content_type,
                "title": title,
                "titleBn": title,
                "slug": identifier.lower(),
                "visibility": "staff_only",
                "status": "draft",
                "requestId": str(uuid.uuid5(NAMESPACE, EXPECTED_HASH + ":" + identifier)),
                "summary": summary,
                "body": bangla_description,
                "arabicText": raw_arabic,
                "banglaText": bangla_meaning,
                "transliteration": nonempty(row.get("transliteration_bn_as_in_source")),
                "referenceText": source_reference,
                "sourceType": "human_provided_book",
                "sourceReference": source_reference,
                "sourceEdition": "নভেম্বর 2024",
                "author": "ইবনে ইসহাক",
                "publisher": "চেতনা প্রকাশন",
                "languageCode": "bn",
                "rightsNote": "Sukun Life owner attested app-use rights on 2026-10-12. Attribution preserved; human editorial and canonical verification required.",
            },
        })
    return {
        "schema": "sukun.private_admin_draft_payload.v1",
        "source_sha256": EXPECTED_HASH,
        "copyright_permission": "user_attested_for_sukun_life_app",
        "imported": False,
        "published": False,
        "entries": result,
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if os.getenv("CI") or os.getenv("GITHUB_ACTIONS"):
        raise SystemExit("Refusing private material preparation in CI")
    src = pathlib.Path(args.input).resolve()
    dest = pathlib.Path(args.output).resolve()
    if src == dest or dest.exists() or dest.is_symlink():
        raise SystemExit("Output must be new, not input or symlink")
    if ".git" in dest.parts or "github" in str(dest).lower():
        raise SystemExit("Refusing GitHub directory")
    data = json.loads(src.read_text(encoding="utf-8"))
    result = prepare(data)
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(dest, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("Prepared", len(result["entries"]), "staff-only draft CMS inputs. NO NETWORK. NO IMPORT.")

if __name__ == "__main__":
    main()
