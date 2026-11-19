#!/usr/bin/env python3
"""Translations of the shell (plugin/src/Sylenara/I18n/trs/es.po), without hand-editing the catalogue.

    po-tool.py [--po FILE] status                 untranslated and fuzzy entries (msgid per line), and totals
    po-tool.py [--po FILE] set MAP.json           apply {"English msgid": "traducción"}: clears the fuzzy flag (also
                                                  "fuzzy, qt-format"), drops the "#|" previous-msgid lines, keeps other flags
Run `fish scripts/trs.fish raw` and `msgmerge -q --update --backup=none es.po raw.pot` first. Exit 1 when
`status` finds something pending, 0 when the catalogue is complete. Entries with msgctxt are matched by msgid too.
"""
import json
import re
import sys
from pathlib import Path

PO = Path(__file__).resolve().parents[1] / "plugin/src/Sylenara/I18n/trs/es.po"


def msgid_of(block: str) -> str | None:
    m = re.search(r'^msgid ((?:".*"\n?)+)', block, re.M)
    if not m:
        return None
    return "".join(re.findall(r'"(.*)"', m.group(1)))


def msgstr_of(block: str) -> str:
    """The translation; for a plural entry its forms joined ("" when any form is empty)."""
    forms = re.findall(r'^msgstr(?:\[\d+\])? ((?:".*"\n?)+)', block, re.M)
    texts = ["".join(re.findall(r'"(.*)"', f)) for f in forms]
    return "" if not texts or any(not t for t in texts) else "|".join(texts)


def entries(text: str):
    for i, block in enumerate(text.split("\n\n")):
        if block.lstrip().startswith("#~"):
            continue  # obsolete
        mid = msgid_of(block)
        if mid:  # the header has an empty msgid
            yield i, block, mid


def status() -> int:
    text = PO.read_text()
    untranslated = [mid for _, b, mid in entries(text) if not msgstr_of(b)]
    fuzzy = [mid for _, b, mid in entries(text) if re.search(r"^#,.*\bfuzzy\b", b, re.M)]
    for mid in untranslated:
        print(f"UNTRANSLATED  {mid}")
    for mid in fuzzy:
        print(f"FUZZY         {mid}")
    print(f"-- untranslated: {len(untranslated)}  fuzzy: {len(fuzzy)}")
    return 1 if untranslated or fuzzy else 0


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def set_(path: str) -> int:
    mapping = json.loads(Path(path).read_text())
    blocks = PO.read_text().split("\n\n")
    done = set()
    for i, block, mid in list(entries("\n\n".join(blocks))):
        if mid not in mapping:
            continue
        if "msgid_plural" in block:
            print(f"  plural, edit it by hand (msgstr[0] / msgstr[1]): {mid}")
            continue
        b = re.sub(r"^#\|.*\n", "", block, flags=re.M)
        b = re.sub(r"^(#,.*?)\bfuzzy\b,? ?", r"\1", b, flags=re.M)
        b = re.sub(r"^#,\s*\n", "", b, flags=re.M)  # a flag line left empty
        b = b[: b.index("\nmsgstr") + 1] + f'msgstr "{escape(mapping[mid])}"'
        blocks[i] = b
        done.add(mid)
    PO.write_text("\n\n".join(blocks))
    missing = [m for m in mapping if m not in done]
    print(f"applied {len(done)}; not found {len(missing)}")
    for m in missing:
        print(f"  not in the catalogue: {m}")
    return 1 if missing else 0


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--po":
        PO = Path(sys.argv[2])
        del sys.argv[1:3]
    if len(sys.argv) >= 2 and sys.argv[1] == "status":
        sys.exit(status())
    if len(sys.argv) == 3 and sys.argv[1] == "set":
        sys.exit(set_(sys.argv[2]))
    print(__doc__, file=sys.stderr)
    sys.exit(2)
