#!/usr/bin/env python3
"""Synthetic-only tests. No book passages, patient data, or credentials."""
import copy
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).with_name("prepare_private_editorial_drafts.py")
spec = importlib.util.spec_from_file_location("prepare_private_editorial_drafts", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def sample():
    row = {
        "resource_id": "SRG2024-DUA-001",
        "type": "dua",
        "title_bn": "TEST FAKE DUA",
        "source_file_sha256": module.EXPECTED_HASH,
        "source_paragraph_index_zero_based": 55,
        "source_section": "FAKE TEST SECTION",
        "source_book_page_hint": "22",
        "arabic_text_as_in_source": "TEST ONLY - NOT SCRIPTURE",
        "bangla_meaning_as_in_source": None,
        "source_description_as_in_source": None,
        "transliteration_bn_as_in_source": None,
        "visibility": "staff_only",
        "content_review": "draft",
        "auto_assignment_allowed": False,
    }
    return {"source": {"sha256": module.EXPECTED_HASH}, "entries": [row]}

class DraftExportTests(unittest.TestCase):
    def test_draft_never_assigns_or_publishes(self):
        output = module.prepare(sample())
        self.assertEqual(len(output["entries"]), 1)
        row = output["entries"][0]
        self.assertFalse(row["approved_for_patient"])
        self.assertEqual(row["input"]["status"], "draft")
        self.assertEqual(row["input"]["visibility"], "staff_only")
        self.assertEqual(row["input"]["type"], "dua")
        self.assertEqual(row["input"]["slug"], "srg2024-dua-001")
        self.assertIn("চেতনা প্রকাশন", row["input"]["sourceReference"])
        self.assertIn("Sukun Life owner attested", row["input"]["rightsNote"])

    def test_unverified_quran_blocks_are_not_mislabeled(self):
        fixture = sample()
        fixture["entries"][0]["type"] = "quran"
        fixture["entries"][0]["resource_id"] = "SRG2024-QUR-001"
        value = module.prepare(fixture)["entries"][0]
        self.assertEqual(value["input"]["type"], "article")
        self.assertTrue(value["needs_canonical_review"])
        self.assertFalse(value["approved_for_patient"])

    def test_missing_source_hash_refused(self):
        fixture = sample()
        fixture["source"]["sha256"] = "UNRELATED"
        with self.assertRaises(ValueError):
            module.prepare(fixture)

    def test_duplicate_id_refused(self):
        fixture = sample()
        fixture["entries"].append(copy.deepcopy(fixture["entries"][0]))
        with self.assertRaises(ValueError):
            module.prepare(fixture)

    def test_never_accepts_patient_visibility(self):
        fixture = sample()
        fixture["entries"][0]["visibility"] = "public"
        with self.assertRaises(ValueError):
            module.prepare(fixture)

    def test_never_accepts_autolink(self):
        fixture = sample()
        fixture["entries"][0]["auto_assignment_allowed"] = True
        with self.assertRaises(ValueError):
            module.prepare(fixture)

    def test_review_required(self):
        fixture = sample()
        fixture["entries"][0]["content_review"] = "verified"
        with self.assertRaises(ValueError):
            module.prepare(fixture)

    def test_request_id_is_stable(self):
        row1 = module.prepare(sample())["entries"][0]["input"]
        row2 = module.prepare(sample())["entries"][0]["input"]
        self.assertEqual(row1["requestId"], row2["requestId"])

if __name__ == "__main__":
    unittest.main()
