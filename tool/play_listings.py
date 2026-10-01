#!/usr/bin/env python3
"""Push the store listing copy to Google Play, one localisation per language. No browser.

    tool/play_listings.py --dry-run        # parse and show what would be sent
    tool/play_listings.py                  # write all seven listings
    tool/play_listings.py --only en-US,ar  # just these
    tool/play_listings.py --default en-US  # also make this the default listing language

`docs/STORE-LISTING.md` is the source of truth: this reads the `## Google Play` block of each
language section rather than keeping a second copy of the copy that could drift from it.

**The app name is forced to `opentransit` in every language.** The doc still carries the older
per-language names ("opentransit: transporte" and so on); the decision was a single clean
wordmark everywhere, and a name that differs by locale reads as a different product.

Why the API and not the Console: the Console asks for name, short description and full
description in a form per language, and a 4000-character paste into a browser text area is both
slow and easy to truncate silently. The API takes all seven in one commit, and `--dry-run`
shows the character counts against Play's limits before anything is sent.

Graphics are deliberately not touched. Play falls back to the default language's icon, feature
graphic and screenshots for any localisation that has none of its own, which is what we want
while the screenshots are Bogotá-only: one set, not seven that drift.

Permission note, because the failure is silent and the error body is empty. Committing an edit
that touches listings needs 'Manage store presence' on the service account, on top of the
'View app information' prerequisite. Granting it does not take effect immediately: every
listing write kept returning 200 and the final `:commit` kept returning 403 "The caller does
not have permission" for more than ten minutes afterwards, then started working with no further
change. If you hit that, wait rather than re-granting.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from play_publish import Client  # noqa: E402  (shares the service-account auth and error hints)

DOC = HERE.parent / "docs" / "STORE-LISTING.md"
APP_NAME = "opentransit"

# Play's own caps. The doc records its counts, but it is the API that rejects, so check here.
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}

# `# Spanish — `es-419`` ... the locale is the only thing we need off the heading. One heading
# carries a trailing note ("# English — `en-US` (default listing)"), so do not anchor to the end
# of the line: doing that silently dropped English, the one listing every unlocalised country
# falls back to.
_HEADING = re.compile(r"^#\s+[^\n`]*`([A-Za-z]{2}(?:-[A-Za-z0-9]{2,3})?)`", re.M)
_FIELD = re.compile(
    r"^\*\*(App name|Short description|Full description)\*\*.*?\n+```\n(.*?)\n```",
    re.S | re.M,
)
_FIELD_KEY = {
    "App name": "title",
    "Short description": "shortDescription",
    "Full description": "fullDescription",
}


def parse(doc: Path) -> dict[str, dict[str, str]]:
    """Locale -> {title, shortDescription, fullDescription}, read from the Google Play blocks."""
    text = doc.read_text()
    heads = list(_HEADING.finditer(text))
    if not heads:
        sys.exit(f"no `# Language — `locale`` headings found in {doc}")

    out: dict[str, dict[str, str]] = {}
    for i, h in enumerate(heads):
        locale = h.group(1)
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        section = text[h.end():end]

        # Each language section carries a Google Play block and an App Store block, in that
        # order. Taking only the first keeps Apple's shorter copy out of Play's fields.
        play = section.split("## App Store")[0]
        if "## Google Play" not in play:
            continue

        fields = {_FIELD_KEY[m.group(1)]: m.group(2).strip() for m in _FIELD.finditer(play)}
        missing = [k for k in LIMITS if k not in fields]
        if missing:
            sys.exit(f"{locale}: no {', '.join(missing)} block under '## Google Play'")

        fields["title"] = APP_NAME
        out[locale] = fields
    return out


def check(locale: str, fields: dict[str, str]) -> list[str]:
    return [
        f"{locale} {k} is {len(fields[k])} characters, over Play's {cap}"
        for k, cap in LIMITS.items()
        if len(fields[k]) > cap
    ]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--doc", type=Path, default=DOC)
    ap.add_argument("--only", help="comma-separated locales, default every one in the doc")
    ap.add_argument("--default", help="also set this as the app's default listing language")
    ap.add_argument("--dry-run", action="store_true", help="parse and report, send nothing")
    ap.add_argument("--package", default="com.jeronimotech.opentransit")
    ap.add_argument("--key", type=Path,
                    default=Path.home() / ".config/opentransit/play-service-account.json")
    a = ap.parse_args()

    listings = parse(a.doc)
    if a.only:
        want = [s.strip() for s in a.only.split(",") if s.strip()]
        unknown = [w for w in want if w not in listings]
        if unknown:
            sys.exit(f"not in the doc: {', '.join(unknown)}. Have: {', '.join(listings)}")
        listings = {k: listings[k] for k in want}

    problems = [p for loc, f in listings.items() for p in check(loc, f)]
    for loc, f in listings.items():
        print(f"{loc:7} name {len(f['title']):>2}/30  short {len(f['shortDescription']):>2}/80  "
              f"full {len(f['fullDescription']):>4}/4000  {f['shortDescription'][:48]}…")
    if problems:
        sys.exit("\n".join(problems))
    if a.default and a.default not in listings and not a.only:
        sys.exit(f"--default {a.default} is not one of the listings being written")
    if a.dry_run:
        print(f"\ndry run: {len(listings)} listings parsed, nothing sent")
        return 0

    c = Client(a.key, a.package)
    edit = c.request("POST", "/edits")["id"]
    committed = False
    try:
        for locale, fields in listings.items():
            # PUT, not PATCH: a language that has no listing yet is a 404 to PATCH, and six of
            # the seven do not exist the first time this runs. PUT creates or replaces, and
            # wants the language echoed in the body.
            c.request("PUT", f"/edits/{edit}/listings/{locale}",
                      body={"language": locale, **fields})
            print(f"[play] wrote {locale}")
        if a.default:
            # Must come after the listing exists, or Play refuses a default with no copy.
            c.request("PATCH", f"/edits/{edit}/details", body={"defaultLanguage": a.default})
            print(f"[play] default listing language is now {a.default}")
        c.request("POST", f"/edits/{edit}:commit")
        committed = True
    finally:
        if not committed:
            try:
                c.request("DELETE", f"/edits/{edit}")
                print("[play] edit discarded, nothing was changed", file=sys.stderr)
            except SystemExit:
                pass
    print(f"committed {len(listings)} listings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
