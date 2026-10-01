#!/usr/bin/env python3
"""Push the App Store listing copy to App Store Connect, one localisation per language.

    tool/asc_listing.py --dry-run           # parse and show what would be sent
    tool/asc_listing.py --version 1.15.0    # write every locale onto that version
    tool/asc_listing.py --version 1.15.0 --only ar-SA

`docs/STORE-LISTING.md` is the source of truth. This reads the `## App Store` block of each
language section, so Apple and Play stay in step with one document rather than two copies that
drift. `tool/play_listings.py` is the same idea against Google.

**The app name is forced to `opentransit` in every language**, as on Play. The doc still carries
the older per-language names.

Apple splits the copy across two objects and the split is not obvious:

- `appInfoLocalizations` hang off the **app**, not the version, and hold `name`, `subtitle` and
  `privacyPolicyUrl`. They survive across versions.
- `appStoreVersionLocalizations` hang off the **version** and hold `description`, `keywords`,
  `promotionalText`, `whatsNew`, `supportUrl` and `marketingUrl`.

A new language needs a row in both, and the app-info row has to exist first or the version row
has nothing to attach a name to. That ordering is why adding a language by hand is fiddly.

Screenshots are not touched here; see `--help` on `tool/asc_screenshots.py`. Apple falls back to
the primary language's screenshots for any localisation without its own, which is what we want
while the captures are Bogotá-only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOC = HERE.parent / "docs" / "STORE-LISTING.md"
APP_NAME = "opentransit"
API = "https://api.appstoreconnect.apple.com/v1"

SUPPORT_URL = "https://opentransit.tech"
MARKETING_URL = "https://opentransit.tech"
PRIVACY_URL = "https://bogota.opentransit.tech/bogota/privacy"

# The doc is keyed by Play locale codes. Apple uses its own, and they disagree for five of seven.
PLAY_TO_APPLE = {
    "es-419": "es-MX", "en-US": "en-US", "pt-PT": "pt-PT",
    "fr-FR": "fr-FR", "it-IT": "it", "ms-MY": "ms", "ar": "ar-SA",
}

# Apple's caps. Over any of these the API rejects the whole PATCH with a field-level error.
LIMITS = {"name": 30, "subtitle": 30, "promotionalText": 170, "keywords": 100,
          "description": 4000}

_HEADING = re.compile(r"^#\s+[^\n`]*`([A-Za-z]{2}(?:-[A-Za-z0-9]{2,3})?)`", re.M)
_FIELD = re.compile(
    r"^\*\*(Name|Subtitle|Promotional text|Keywords|Description)\*\*.*?\n+```\n(.*?)\n```",
    re.S | re.M,
)
_KEY = {"Name": "name", "Subtitle": "subtitle", "Promotional text": "promotionalText",
        "Keywords": "keywords", "Description": "description"}


def log(msg: str) -> None:
    print(f"[asc] {msg}", file=sys.stderr)


def parse(doc: Path) -> dict[str, dict[str, str]]:
    """Apple locale -> the five copy fields, read from the `## App Store` blocks."""
    text = doc.read_text()
    heads = list(_HEADING.finditer(text))
    if not heads:
        sys.exit(f"no `# Language — `locale`` headings found in {doc}")
    out: dict[str, dict[str, str]] = {}
    for i, h in enumerate(heads):
        play_locale = h.group(1)
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        section = text[h.end():end]
        if "## App Store" not in section:
            continue
        # Everything after the Apple heading, so Play's longer copy cannot leak into Apple's caps.
        apple = section.split("## App Store", 1)[1]
        fields = {_KEY[m.group(1)]: m.group(2).strip() for m in _FIELD.finditer(apple)}
        missing = [k for k in LIMITS if k not in fields]
        if missing:
            sys.exit(f"{play_locale}: the '## App Store' block has no {', '.join(missing)}")
        fields["name"] = APP_NAME
        out[PLAY_TO_APPLE.get(play_locale, play_locale)] = fields
    return out


class Client:
    def __init__(self) -> None:
        import jwt  # imported late so --dry-run works without the dependency
        self.key_id = os.environ.get("ASC_KEY_ID") or sys.exit("missing env ASC_KEY_ID")
        issuer = os.environ.get("ASC_ISSUER_ID") or sys.exit("missing env ASC_ISSUER_ID")
        path = Path(os.environ.get("ASC_KEY_PATH")
                    or Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{self.key_id}.p8")
        if not path.is_file():
            sys.exit(f"API key file not found: {path}")
        now = time.time()
        self.tok = jwt.encode({"iss": issuer, "iat": int(now), "exp": int(now) + 900,
                               "aud": "appstoreconnect-v1"},
                              path.read_text(), algorithm="ES256",
                              headers={"kid": self.key_id, "typ": "JWT"})

    def request(self, method: str, path: str, body: dict | None = None,
                params: dict | None = None) -> dict:
        url = API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.tok}")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                errs = json.loads(detail).get("errors", [])
                # Apple's useful text is in `detail`; `title` alone is usually "Entity error".
                detail = "; ".join(f"{x.get('title')}: {x.get('detail')}" for x in errs)
            except ValueError:
                pass
            sys.exit(f"App Store Connect {method} {path} -> HTTP {e.code}: {detail}")

    def all(self, path: str, params: dict | None = None) -> list[dict]:
        p = dict(params or {})
        p.setdefault("limit", 200)
        return self.request("GET", path, params=p).get("data", [])


def version_row(c: Client, app: str, version: str) -> str:
    rows = c.all(f"/apps/{app}/appStoreVersions",
                 {"filter[platform]": "IOS", "limit": 20,
                  "fields[appStoreVersions]": "versionString,appStoreState"})
    for v in rows:
        if v["attributes"]["versionString"] == version:
            return v["id"]
    sys.exit(f"no version {version}; run `asc_signing.py appstore --version {version}` first, "
             "which creates or renames the editable one")


def app_info_id(c: Client, app: str) -> str:
    infos = c.all(f"/apps/{app}/appInfos", {"limit": 10})
    editable = [i for i in infos
                if i["attributes"].get("appStoreState") not in {"READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}]
    return (editable or infos)[0]["id"]


def write_locale(c: Client, info_id: str, version_id: str, locale: str, f: dict[str, str]) -> str:
    """Create or update both halves of one localisation. Returns what happened, for the log."""
    # --- app-level: name, subtitle, privacy policy. Must exist before the version row is useful.
    infos = {r["attributes"]["locale"]: r["id"]
             for r in c.all(f"/appInfos/{info_id}/appInfoLocalizations",
                            {"fields[appInfoLocalizations]": "locale"})}
    attrs = {"name": f["name"], "subtitle": f["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
    if locale in infos:
        c.request("PATCH", f"/appInfoLocalizations/{infos[locale]}",
                  {"data": {"type": "appInfoLocalizations", "id": infos[locale], "attributes": attrs}})
        made_info = "updated"
    else:
        c.request("POST", "/appInfoLocalizations",
                  {"data": {"type": "appInfoLocalizations",
                            "attributes": {"locale": locale, **attrs},
                            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}})
        made_info = "created"

    # --- version-level: description, keywords, promotional text, URLs.
    vers = {r["attributes"]["locale"]: r["id"]
            for r in c.all(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
                           {"fields[appStoreVersionLocalizations]": "locale"})}
    vattrs = {"description": f["description"], "keywords": f["keywords"],
              "promotionalText": f["promotionalText"],
              "supportUrl": SUPPORT_URL, "marketingUrl": MARKETING_URL}
    if locale in vers:
        c.request("PATCH", f"/appStoreVersionLocalizations/{vers[locale]}",
                  {"data": {"type": "appStoreVersionLocalizations", "id": vers[locale],
                            "attributes": vattrs}})
        made_ver = "updated"
    else:
        c.request("POST", "/appStoreVersionLocalizations",
                  {"data": {"type": "appStoreVersionLocalizations",
                            "attributes": {"locale": locale, **vattrs},
                            "relationships": {"appStoreVersion":
                                              {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        made_ver = "created"
    return f"appInfo {made_info}, version {made_ver}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--doc", type=Path, default=DOC)
    ap.add_argument("--version", help="CFBundleShortVersionString the copy belongs to, e.g. 1.15.0")
    ap.add_argument("--only", help="comma-separated Apple locales")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--app-id", default=os.environ.get("APP_STORE_ID", "6809010622"))
    a = ap.parse_args()

    listings = parse(a.doc)
    if a.only:
        want = [s.strip() for s in a.only.split(",") if s.strip()]
        unknown = [w for w in want if w not in listings]
        if unknown:
            sys.exit(f"not in the doc: {', '.join(unknown)}. Have: {', '.join(listings)}")
        listings = {k: listings[k] for k in want}

    problems = []
    for loc, f in listings.items():
        for k, cap in LIMITS.items():
            if len(f[k]) > cap:
                problems.append(f"{loc} {k} is {len(f[k])} characters, over Apple's {cap}")
        print(f"{loc:6} name {len(f['name']):>2}/30  sub {len(f['subtitle']):>2}/30  "
              f"promo {len(f['promotionalText']):>3}/170  kw {len(f['keywords']):>3}/100  "
              f"desc {len(f['description']):>4}/4000")
    if problems:
        sys.exit("\n".join(problems))
    if a.dry_run:
        print(f"\ndry run: {len(listings)} localisations parsed, nothing sent")
        return 0
    if not a.version:
        sys.exit("pass --version (the App Store version the copy belongs to), or --dry-run")

    c = Client()
    version_id = version_row(c, a.app_id, a.version)
    info_id = app_info_id(c, a.app_id)
    for locale, f in listings.items():
        log(f"{locale}: {write_locale(c, info_id, version_id, locale, f)}")
    print(f"wrote {len(listings)} localisations onto {a.version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
