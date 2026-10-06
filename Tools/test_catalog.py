"""Catalog identity/structure regressions. Negative manifests are isolated copies."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from validate_catalog import DEFAULT_MANIFEST, PRIMARY_COUNTS, read_catalog, validate_catalog


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.canonical = read_catalog(DEFAULT_MANIFEST)

    def manifest(self):
        return copy.deepcopy(self.canonical)

    def rejects(self, mutate, message):
        manifest = self.manifest()
        mutate(manifest)
        with self.assertRaisesRegex(ValueError, message):
            validate_catalog(manifest)

    def test_approved_manifest_counts_and_established_ids(self):
        before = self.manifest()
        summary = validate_catalog(self.canonical)
        self.assertEqual(summary["bookCount"], 50)
        self.assertEqual(summary["shelfCount"], 8)
        self.assertEqual(summary["primaryShelfCounts"], PRIMARY_COUNTS)
        self.assertEqual(before, self.canonical, "Validation must never normalize or mutate input")
        books = {b["title"]: b for b in self.canonical["books"]}
        self.assertEqual(books["The Influential Mind"]["id"], "influential-mind")
        self.assertEqual(books["Never Split the Difference"]["id"], "never-split-the-difference")

    def test_duplicate_book_id(self):
        self.rejects(lambda m: m["books"][1].update(id=m["books"][0]["id"]), r"books.id: duplicate")

    def test_only_catalog_revision_one_is_supported(self):
        for revision in (2, 99):
            with self.subTest(revision=revision):
                self.rejects(lambda m: m.update(catalogRevision=revision), "only revision 1 is supported")

    def test_every_approved_book_id_is_locked(self):
        for index, book in enumerate(self.canonical["books"]):
            with self.subTest(catalogOrder=book["catalogOrder"], id=book["id"]):
                self.rejects(lambda m: m["books"][index].update(id=f"accidental-renamed-book-{index}"),
                             "catalogOrder \\+ id sequence differs")

    def test_swapped_ids_with_unchanged_order_fields_are_rejected(self):
        def swap_ids(m):
            a, b = m["books"][20:22]
            a["id"], b["id"] = b["id"], a["id"]
        self.rejects(swap_ids, "catalogOrder \\+ id sequence differs")

    def test_shelf_array_swaps_without_order_changes_are_rejected(self):
        def swap_shelves(m):
            m["shelves"][0], m["shelves"][1] = m["shelves"][1], m["shelves"][0]
        self.rejects(swap_shelves, "physical array order must match order")

    def test_book_array_swaps_without_order_changes_are_rejected(self):
        def swap_books(m):
            m["books"][25], m["books"][26] = m["books"][26], m["books"][25]
        self.rejects(swap_books, "physical array order must match catalogOrder")

    def test_unknown_primary_and_secondary_shelves(self):
        self.rejects(lambda m: m["books"][0].update(primaryShelfID="unknown"), "primaryShelfID: unknown")
        self.rejects(lambda m: m["books"][0].update(secondaryShelfIDs=["unknown"]), "secondaryShelfIDs: unknown")

    def test_duplicate_and_out_of_range_priorities(self):
        self.rejects(lambda m: m["books"][1].update(authoringPriority=m["books"][0]["authoringPriority"]), "authoringPriority: duplicate")
        self.rejects(lambda m: m["books"][0].update(authoringPriority=51), "authoringPriority: expected 1–50")

    def test_wrong_declared_and_actual_counts(self):
        self.rejects(lambda m: m.update(bookCount=49), "declared count")
        def drop(m):
            m["books"].pop(); m["bookCount"] = 49
        self.rejects(drop, "exactly 50")

    def test_self_secondary_and_duplicate_secondary(self):
        self.rejects(lambda m: m["books"][0].update(secondaryShelfIDs=[m["books"][0]["primaryShelfID"]]), "primary shelf repeated")
        self.rejects(lambda m: m["books"][0].update(secondaryShelfIDs=["communication-negotiation"] * 2), "duplicate values")

    def test_schema_revision_and_boolean_integer_confusion(self):
        for key, value in [("schemaVersion", 2), ("schemaVersion", True), ("catalogRevision", 0), ("catalogRevision", True), ("bookCount", True)]:
            with self.subTest(key=key, value=value):
                self.rejects(lambda m: m.update({key: value}), key)
        self.rejects(lambda m: m["books"][0].update(authoringPriority=True), "expected an integer")

    def test_duplicate_shelf_identity_and_order(self):
        self.rejects(lambda m: m["shelves"][1].update(id=m["shelves"][0]["id"]), "shelves.id: duplicate")
        self.rejects(lambda m: m["shelves"][1].update(order=1), "shelves.order: duplicate")
        self.rejects(lambda m: m["shelves"][0].update(order=9), "expected 1–8")

    def test_primary_distribution_and_catalog_order(self):
        self.rejects(lambda m: m["books"][1].update(primaryShelfID="meaning-philosophy-resilience"), "expected 10 primary books")
        self.rejects(lambda m: m["books"][1].update(catalogOrder=1), "catalogOrder: duplicate")

    def test_empty_ids_authors_and_deduplicated_tags(self):
        self.rejects(lambda m: m["books"][0].update(id=" "), "must not be empty")
        self.rejects(lambda m: m["books"][0].update(authors=[]), "must not be empty")
        for tags in [[], [""], ["focus", "Focus"], [" focus"]]:
            with self.subTest(tags=tags):
                self.rejects(lambda m: m["books"][0].update(tags=tags), "tags")

    def test_missing_wrong_type_and_transport_fields(self):
        self.rejects(lambda m: m["books"][0].pop("authors"), "missing fields authors")
        self.rejects(lambda m: m.update(books={}), "expected an array")
        self.rejects(lambda m: m["books"][0].update(packageURL="https://example.invalid/book.json"), "unknown fields packageURL")
        self.rejects(lambda m: m["rules"].update(maximumIdeasPerAuthoredBook=13), "maximumIdeasPerAuthoredBook")

    def test_duplicate_json_keys_and_non_json_constants(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            for text in ['{"books":[],"books":[]}', '{"rules":{"same":1,"same":2}}', '{"catalogRevision":NaN}']:
                with self.subTest(text=text):
                    path.write_text(text)
                    with self.assertRaises(ValueError):
                        read_catalog(path)

    def test_cli_is_deterministic_read_only_and_fails_cleanly(self):
        command = [sys.executable, str(DEFAULT_MANIFEST.parents[1] / "Tools" / "validate_catalog.py")]
        original = DEFAULT_MANIFEST.read_bytes()
        first = subprocess.run(command, cwd=tempfile.gettempdir(), capture_output=True, text=True)
        second = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(first.stdout, second.stdout)
        self.assertEqual(DEFAULT_MANIFEST.read_bytes(), original)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            invalid = self.manifest(); invalid["books"][1]["id"] = invalid["books"][0]["id"]
            path.write_text(json.dumps(invalid))
            before = path.read_bytes()
            result = subprocess.run(command + [str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertIn("books.id: duplicate", result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
