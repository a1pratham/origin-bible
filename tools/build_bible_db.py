#!/usr/bin/env python3
"""Build assets/bible/web.db (+ web.version) from the World English Bible USFM zip.

Source: eBible.org "World English Bible" (engwebp), file engwebp_usfm.zip.
Usage:  python tools/build_bible_db.py path/to/engwebp_usfm.zip
        python tools/build_bible_db.py path/to/engwebp_usfm.zip --out assets/bible

Standard library only. Verse wording is kept exactly as in the source. Only
markup is removed: footnotes, cross-references, Strong's numbers, section
headings and character styles. Psalm titles are kept as verse 0.
"""
import argparse
import hashlib
import re
import sqlite3
import sys
import zipfile
from pathlib import Path

# (code, name, chapters, testament). Keep in sync with lib/features/bible/data/bible_books.dart
BOOKS = [
    ("GEN", "Genesis", 50, "OT"), ("EXO", "Exodus", 40, "OT"), ("LEV", "Leviticus", 27, "OT"),
    ("NUM", "Numbers", 36, "OT"), ("DEU", "Deuteronomy", 34, "OT"), ("JOS", "Joshua", 24, "OT"),
    ("JDG", "Judges", 21, "OT"), ("RUT", "Ruth", 4, "OT"), ("1SA", "1 Samuel", 31, "OT"),
    ("2SA", "2 Samuel", 24, "OT"), ("1KI", "1 Kings", 22, "OT"), ("2KI", "2 Kings", 25, "OT"),
    ("1CH", "1 Chronicles", 29, "OT"), ("2CH", "2 Chronicles", 36, "OT"), ("EZR", "Ezra", 10, "OT"),
    ("NEH", "Nehemiah", 13, "OT"), ("EST", "Esther", 10, "OT"), ("JOB", "Job", 42, "OT"),
    ("PSA", "Psalms", 150, "OT"), ("PRO", "Proverbs", 31, "OT"), ("ECC", "Ecclesiastes", 12, "OT"),
    ("SNG", "Song of Solomon", 8, "OT"), ("ISA", "Isaiah", 66, "OT"), ("JER", "Jeremiah", 52, "OT"),
    ("LAM", "Lamentations", 5, "OT"), ("EZK", "Ezekiel", 48, "OT"), ("DAN", "Daniel", 12, "OT"),
    ("HOS", "Hosea", 14, "OT"), ("JOL", "Joel", 3, "OT"), ("AMO", "Amos", 9, "OT"),
    ("OBA", "Obadiah", 1, "OT"), ("JON", "Jonah", 4, "OT"), ("MIC", "Micah", 7, "OT"),
    ("NAM", "Nahum", 3, "OT"), ("HAB", "Habakkuk", 3, "OT"), ("ZEP", "Zephaniah", 3, "OT"),
    ("HAG", "Haggai", 2, "OT"), ("ZEC", "Zechariah", 14, "OT"), ("MAL", "Malachi", 4, "OT"),
    ("MAT", "Matthew", 28, "NT"), ("MRK", "Mark", 16, "NT"), ("LUK", "Luke", 24, "NT"),
    ("JHN", "John", 21, "NT"), ("ACT", "Acts", 28, "NT"), ("ROM", "Romans", 16, "NT"),
    ("1CO", "1 Corinthians", 16, "NT"), ("2CO", "2 Corinthians", 13, "NT"), ("GAL", "Galatians", 6, "NT"),
    ("EPH", "Ephesians", 6, "NT"), ("PHP", "Philippians", 4, "NT"), ("COL", "Colossians", 4, "NT"),
    ("1TH", "1 Thessalonians", 5, "NT"), ("2TH", "2 Thessalonians", 3, "NT"), ("1TI", "1 Timothy", 6, "NT"),
    ("2TI", "2 Timothy", 4, "NT"), ("TIT", "Titus", 3, "NT"), ("PHM", "Philemon", 1, "NT"),
    ("HEB", "Hebrews", 13, "NT"), ("JAS", "James", 5, "NT"), ("1PE", "1 Peter", 5, "NT"),
    ("2PE", "2 Peter", 3, "NT"), ("1JN", "1 John", 5, "NT"), ("2JN", "2 John", 1, "NT"),
    ("3JN", "3 John", 1, "NT"), ("JUD", "Jude", 1, "NT"), ("REV", "Revelation", 22, "NT"),
]

TRANSLATION = {
    "id": "web",
    "abbreviation": "WEB",
    "name": "World English Bible",
    "language": "en",
    "license": "Public domain",
    "source_url": "https://ebible.org/Scriptures/details.php?id=engwebp",
    "attribution": 'World English Bible (WEB), public domain. "World English Bible" is a trademark of eBible.org.',
}

NOTE_RE = re.compile(r"\\(f|fe|x|fig)\b.*?\\\1\*", re.S)
WORD_RE = re.compile(r"\\\+?w\s+([^|\\]*?)(?:\|[^\\]*)?\\\+?w\*")
MARK_RE = re.compile(r"\\\+?[A-Za-z][A-Za-z0-9]*\*?")
LINE_RE = re.compile(r"^\\(\w+)\*?(?:\s+(.*))?$")
VERSE_RE = re.compile(r"^(\d+)(?:[-,]\d+)*[a-z]?\s*(.*)$", re.S)

# Paragraph / poetry markers whose text belongs to the current verse.
PARA = {
    "p", "m", "mi", "pi", "pi1", "pi2", "pi3", "pc", "pr", "pm", "pmo", "pmc", "pmr", "nb",
    "q", "q1", "q2", "q3", "q4", "qr", "qc", "qm", "qm1", "qm2", "qm3",
    "li", "li1", "li2", "li3", "li4", "lim", "lim1", "lim2", "b", "ph", "ph1", "ph2", "ph3", "cls",
}
# Character styles that can start a line and continue the current verse.
CHAR = {"w", "wj", "add", "nd", "qs", "tl", "sc", "bk", "dc", "k", "pn", "ord", "sig", "em", "bd", "it"}


def clean(s: str) -> str:
    s = WORD_RE.sub(r"\1", s)
    s = MARK_RE.sub("", s)
    return re.sub(r"\s+", " ", s).strip()


def parse_book(text: str):
    """Return {chapter: {verse: text}} (verse 0 = psalm title)."""
    text = NOTE_RE.sub("", text)
    chapters = {}
    chapter = 0
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        m = LINE_RE.match(line)
        if not m:
            if current is not None:
                current.append(line)
            continue
        marker, rest = m.group(1), (m.group(2) or "")
        if marker == "c":
            n = re.match(r"\d+", rest)
            if not n:
                raise ValueError(f"Bad chapter line: {line!r}")
            chapter = int(n.group())
            chapters[chapter] = {}
            current = None
        elif marker == "v":
            vm = VERSE_RE.match(rest)
            if not vm or chapter == 0:
                raise ValueError(f"Bad verse line: {line!r}")
            vnum = int(vm.group(1))
            current = chapters[chapter].setdefault(vnum, [])
            if vm.group(2):
                current.append(vm.group(2))
        elif marker == "d":
            if current is not None:
                current.append(rest)
            elif chapter:
                chapters[chapter][0] = [rest]
        elif marker in PARA or marker in CHAR:
            if current is not None:
                current.append(line if marker in CHAR else rest)
        # everything else (ids, headings, titles, remarks) is skipped
    out = {}
    for ch, verses in chapters.items():
        out[ch] = {}
        for v, pieces in verses.items():
            t = clean(" ".join(pieces))
            if t:
                out[ch][v] = t
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("zip", help="path to engwebp_usfm.zip")
    ap.add_argument("--out", default="assets/bible", help="output directory")
    ap.add_argument("--partial", action="store_true", help="allow missing books (testing only)")
    args = ap.parse_args()

    found = {}
    with zipfile.ZipFile(args.zip) as zf:
        for name in zf.namelist():
            if not name.lower().endswith((".usfm", ".sfm")):
                continue
            text = zf.read(name).decode("utf-8-sig")
            m = re.search(r"^\\id\s+([A-Z0-9]{3})", text, re.M)
            if m:
                found[m.group(1)] = text

    missing = [c for c, *_ in BOOKS if c not in found]
    if missing and not args.partial:
        print(f"ERROR: missing books in zip: {missing}", file=sys.stderr)
        return 1

    parsed = {}
    for code, name, expected, _ in BOOKS:
        if code not in found:
            continue
        data = parse_book(found[code])
        if sorted(data) != list(range(1, expected + 1)):
            print(f"ERROR: {code} chapters {sorted(data)[:3]}..{sorted(data)[-3:]} != 1..{expected}", file=sys.stderr)
            if not args.partial:
                return 1
        parsed[code] = data

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    db_path = out_dir / "web.db"
    if db_path.exists():
        db_path.unlink()

    con = sqlite3.connect(db_path)
    con.executescript(
        """
        PRAGMA journal_mode = DELETE;
        CREATE TABLE translations(
            id TEXT PRIMARY KEY, abbreviation TEXT, name TEXT, language TEXT,
            license TEXT, source_url TEXT, attribution TEXT);
        CREATE TABLE books(
            code TEXT PRIMARY KEY, name TEXT, testament TEXT, chapters INTEGER, ord INTEGER);
        CREATE TABLE verses(
            translation_id TEXT NOT NULL, book_code TEXT NOT NULL,
            chapter INTEGER NOT NULL, verse INTEGER NOT NULL, text TEXT NOT NULL,
            PRIMARY KEY (translation_id, book_code, chapter, verse)) WITHOUT ROWID;
        """
    )
    t = TRANSLATION
    con.execute(
        "INSERT INTO translations VALUES (?,?,?,?,?,?,?)",
        (t["id"], t["abbreviation"], t["name"], t["language"], t["license"], t["source_url"], t["attribution"]),
    )
    for i, (code, name, chapters, testament) in enumerate(BOOKS):
        con.execute("INSERT INTO books VALUES (?,?,?,?,?)", (code, name, testament, chapters, i))
    total = 0
    for code, data in parsed.items():
        for ch, verses in data.items():
            for v, text in verses.items():
                con.execute("INSERT INTO verses VALUES (?,?,?,?,?)", (t["id"], code, ch, v, text))
                total += v > 0
    con.commit()
    con.execute("VACUUM")
    con.close()

    digest = hashlib.sha256(db_path.read_bytes()).hexdigest()[:16]
    (out_dir / "web.version").write_text(digest + "\n", encoding="utf-8")

    print(f"Books: {len(parsed)}/66   Verses (excluding psalm titles): {total}")
    print(f"Wrote {db_path} ({db_path.stat().st_size / 1_048_576:.1f} MB) and web.version = {digest}")
    if not args.partial and not 30_500 <= total <= 31_500:
        print("WARNING: verse total is outside the expected ~31,100 range. Inspect the source.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
