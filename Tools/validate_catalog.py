"""Read-only validation of the static Catalog 001 editorial identity manifest."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "Catalog" / "Catalog-001.json"
# Approved revision-1 (catalogOrder, id) pairs, encoded as compact UTF-8 JSON.
# Keep this independent of the input manifest; later contracts require approval.
APPROVED_IDENTITIES_SHA256 = "81033ce2044bfc6fda88015f12ef339135784aa3ca067ace8b3b1870462f4b88"
PRIMARY_COUNTS = {
    "psychology-human-behavior": 10,
    "communication-negotiation": 7,
    "habits-personal-growth": 8,
    "money-personal-finance": 7,
    "leadership-strategy": 7,
    "productivity-focus": 4,
    "relationships-emotional-intelligence": 3,
    "meaning-philosophy-resilience": 4,
}
RULES = {
    "onePrimaryShelfPerBook": True,
    "secondaryShelvesAllowed": True,
    "stableBookIDsMustNotChangeAfterFreeze": True,
    "wholeBookPackageIsAtomicDistributionUnit": True,
    "maximumIdeasPerAuthoredBook": 12,
    "coreIdeaExperienceMaximumSeconds": 300,
    "catalogDoesNotImplyPackageAvailability": True,
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def object_fields(value, fields, path):
    require(isinstance(value, dict), f"{path}: expected an object")
    missing = sorted(set(fields) - value.keys())
    extra = sorted(value.keys() - set(fields))
    require(not missing, f"{path}: missing fields {', '.join(missing)}")
    require(not extra, f"{path}: unknown fields {', '.join(extra)}")


def text(value, path, allow_empty=False):
    require(isinstance(value, str), f"{path}: expected text")
    require(allow_empty or bool(value.strip()), f"{path}: must not be empty")
    require(value == value.strip(), f"{path}: remove surrounding whitespace")


def integer(value, path, minimum=1):
    require(type(value) is int and value >= minimum, f"{path}: expected an integer >= {minimum}")


def text_list(value, path, nonempty=False, casefold=False):
    require(isinstance(value, list), f"{path}: expected an array")
    require(not nonempty or bool(value), f"{path}: must not be empty")
    for i, item in enumerate(value):
        text(item, f"{path}[{i}]")
    keys = [item.casefold() if casefold else item for item in value]
    require(len(keys) == len(set(keys)), f"{path}: duplicate values")


def unique(values, path):
    require(len(values) == len(set(values)), f"{path}: duplicate values")


def validate_catalog(manifest):
    """Validate schema 1 and the approved 50-book/eight-shelf Catalog 001 contract.

    The input is never normalized or modified. This checks metadata structure,
    not factual review, package availability, or lesson-content release approval.
    """
    object_fields(manifest, ["schemaVersion", "catalogID", "catalogRevision", "status",
                            "title", "bookCount", "rules", "shelves", "books"], "catalog")
    integer(manifest["schemaVersion"], "schemaVersion")
    require(manifest["schemaVersion"] == 1, "schemaVersion: only schema 1 is supported")
    require(manifest["catalogID"] == "catalog-001", "catalogID: expected catalog-001")
    integer(manifest["catalogRevision"], "catalogRevision")
    require(manifest["catalogRevision"] == 1, "catalogRevision: only revision 1 is supported")
    require(manifest["status"] == "editorial-source-of-truth", "status: expected editorial-source-of-truth")
    text(manifest["title"], "title")
    integer(manifest["bookCount"], "bookCount")
    object_fields(manifest["rules"], RULES, "rules")
    for key, expected in RULES.items():
        actual = manifest["rules"][key]
        require(type(actual) is type(expected) and actual == expected, f"rules.{key}: expected {expected}")

    shelves = manifest["shelves"]
    require(isinstance(shelves, list) and len(shelves) == 8, "shelves: expected exactly 8 shelves")
    for i, shelf in enumerate(shelves):
        path = f"shelves[{i}]"
        object_fields(shelf, ["id", "name", "order"], path)
        text(shelf["id"], path + ".id")
        text(shelf["name"], path + ".name")
        integer(shelf["order"], path + ".order")
    shelf_ids = [s["id"] for s in shelves]
    unique(shelf_ids, "shelves.id")
    unique([s["order"] for s in shelves], "shelves.order")
    require({s["order"] for s in shelves} == set(range(1, 9)), "shelves.order: expected 1–8 exactly once")
    require(all(s["order"] == i + 1 for i, s in enumerate(shelves)),
            "shelves: physical array order must match order 1–8")
    require(set(shelf_ids) == set(PRIMARY_COUNTS), "shelves.id: expected the eight approved Catalog 001 shelf IDs")

    books = manifest["books"]
    require(isinstance(books, list), "books: expected an array")
    require(len(books) == manifest["bookCount"], "bookCount: declared count does not match books")
    require(len(books) == 50, "books: expected exactly 50 books")
    fields = ["catalogOrder", "id", "title", "authors", "primaryShelfID", "secondaryShelfIDs",
              "tags", "authoringPriority", "editorialStatus", "packageStatus", "notes"]
    for i, book in enumerate(books):
        path = f"books[{i}]"
        object_fields(book, fields, path)
        for key in ["id", "title", "primaryShelfID"]:
            text(book[key], path + "." + key)
        text_list(book["authors"], path + ".authors", nonempty=True, casefold=True)
        text_list(book["tags"], path + ".tags", nonempty=True, casefold=True)
        text_list(book["secondaryShelfIDs"], path + ".secondaryShelfIDs")
        require(book["primaryShelfID"] in shelf_ids, path + ".primaryShelfID: unknown shelf")
        require(all(s in shelf_ids for s in book["secondaryShelfIDs"]), path + ".secondaryShelfIDs: unknown shelf")
        require(book["primaryShelfID"] not in book["secondaryShelfIDs"], path + ": primary shelf repeated as secondary")
        integer(book["catalogOrder"], path + ".catalogOrder")
        integer(book["authoringPriority"], path + ".authoringPriority")
        require(book["editorialStatus"] in ["planned", "authored"], path + ".editorialStatus: unknown status")
        require(book["packageStatus"] in ["not-authored", "authored-local"], path + ".packageStatus: unknown status")
        text(book["notes"], path + ".notes", allow_empty=True)
    unique([b["id"] for b in books], "books.id")
    for key in ["catalogOrder", "authoringPriority"]:
        values = [b[key] for b in books]
        unique(values, "books." + key)
        require(set(values) == set(range(1, 51)), f"books.{key}: expected 1–50 exactly once")
    require(all(b["catalogOrder"] == i + 1 for i, b in enumerate(books)),
            "books: physical array order must match catalogOrder 1–50")
    identities = [[b["catalogOrder"], b["id"]] for b in books]
    identity_bytes = json.dumps(identities, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    require(hashlib.sha256(identity_bytes).hexdigest() == APPROVED_IDENTITIES_SHA256,
            "books: catalogOrder + id sequence differs from approved revision-1 identities")
    counts = Counter(b["primaryShelfID"] for b in books)
    for shelf_id, expected in PRIMARY_COUNTS.items():
        require(counts[shelf_id] == expected, f"{shelf_id}: expected {expected} primary books, found {counts[shelf_id]}")
    return {
        "catalogID": manifest["catalogID"], "catalogRevision": manifest["catalogRevision"],
        "bookCount": len(books), "shelfCount": len(shelves),
        "primaryShelfCounts": {s["id"]: counts[s["id"]] for s in sorted(shelves, key=lambda s: s["order"])},
    }


def read_catalog(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"Duplicate JSON object key: {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ValueError(f"Invalid JSON constant: {value}")

    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=pairs,
                      parse_constant=invalid_constant)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args(argv)
    try:
        summary = validate_catalog(read_catalog(args.manifest))
    except (OSError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"VALID {summary['catalogID']} revision {summary['catalogRevision']}: 50 books, 8 shelves")
    for shelf_id, count in summary["primaryShelfCounts"].items():
        print(f"  {shelf_id}: {count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
