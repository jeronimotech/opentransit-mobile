#!/usr/bin/env python3
"""Upload App Store screenshots to a version, straight from docs/store/.

    tool/asc_screenshots.py --version 1.15.0 --dry-run
    tool/asc_screenshots.py --version 1.15.0
    tool/asc_screenshots.py --version 1.15.0 --replace   # clear each set first

Apple's upload is a four-step handshake and every step is easy to get subtly wrong, which is why
this exists rather than a curl in a runbook:

1. reserve an `appScreenshots` row, giving the exact byte size and file name. Apple answers with
   one or more `uploadOperations`, each a URL plus the headers it insists on;
2. PUT the bytes to each operation, honouring its own `offset` and `length` — Apple may split a
   file into several parts and the parts are not necessarily in order;
3. PATCH the row with `uploaded: true` and the **MD5** of the whole file. Apple calls it
   `sourceFileChecksum` and rejects anything else;
4. poll `assetDeliveryState`, because a file Apple cannot process fails here, long after the PUT
   returned 200.

Which display type a file belongs to comes from its pixel size, not its folder, so a re-capture
at a new device size lands in the right set without editing this file.

Screenshots are per localisation, but Apple falls back to the primary language for any locale
without its own. We upload the Spanish captures to es-MX and the English ones to en-US and let
the other five inherit, rather than shipping five copies of the same Bogotá screens.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
API = "https://api.appstoreconnect.apple.com/v1"

# (width, height) -> Apple's screenshotDisplayType. Apple accepts a couple of sizes per bucket;
# these are the ones tool/store_shots_ios.sh actually produces.
BY_SIZE = {
    (1320, 2868): "APP_IPHONE_67",          # 6.9" iPhone
    (1290, 2796): "APP_IPHONE_67",
    (2064, 2752): "APP_IPAD_PRO_3GEN_129",  # 13" iPad
    (2048, 2732): "APP_IPAD_PRO_3GEN_129",
    (416, 496): "APP_WATCH_SERIES_10",       # 46mm Apple Watch
    (410, 502): "APP_WATCH_ULTRA",
    (396, 484): "APP_WATCH_SERIES_7",
}

# Folder -> Apple locale. Only the two we have captures for; everything else inherits.
SOURCES = {
    "en": "en-US",
    "es": "es-MX",
}
DIRS = ["docs/store/ios", "docs/store/ipad"]

# The watch captures are one flat set, not per language: the screens are a map, a route name and a
# countdown, so there is nothing to translate. Apple still demands a watch screenshot on every
# localisation of a binary that ships a watch app, so the same files go to each locale we handle.
WATCH_DIR = "docs/screenshots"
WATCH_GLOB = "watch_*.png"


def log(msg: str) -> None:
    print(f"[shots] {msg}", file=sys.stderr)


class Client:
    def __init__(self) -> None:
        import jwt
        self.key_id = os.environ.get("ASC_KEY_ID") or sys.exit("missing env ASC_KEY_ID")
        issuer = os.environ.get("ASC_ISSUER_ID") or sys.exit("missing env ASC_ISSUER_ID")
        path = Path(os.environ.get("ASC_KEY_PATH")
                    or Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{self.key_id}.p8")
        if not path.is_file():
            sys.exit(f"API key file not found: {path}")
        now = time.time()
        self.tok = jwt.encode({"iss": issuer, "iat": int(now), "exp": int(now) + 1200,
                               "aud": "appstoreconnect-v1"},
                              path.read_text(), algorithm="ES256",
                              headers={"kid": self.key_id, "typ": "JWT"})

    def request(self, method: str, path: str, body: dict | None = None,
                params: dict | None = None) -> dict:
        url = path if path.startswith("http") else API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.tok}")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                detail = "; ".join(f"{x.get('title')}: {x.get('detail')}"
                                   for x in json.loads(detail).get("errors", []))
            except ValueError:
                pass
            sys.exit(f"App Store Connect {method} {path} -> HTTP {e.code}: {detail}")

    def all(self, path: str, params: dict | None = None) -> list[dict]:
        p = dict(params or {})
        p.setdefault("limit", 200)
        return self.request("GET", path, params=p).get("data", [])

    def put_bytes(self, op: dict, blob: bytes) -> None:
        chunk = blob[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        with urllib.request.urlopen(req, timeout=300) as r:
            if r.status not in (200, 201, 204):
                sys.exit(f"upload part returned {r.status}")


def discover() -> dict[str, dict[str, list[Path]]]:
    """locale -> displayType -> sorted files, read from the capture folders."""
    from PIL import Image
    out: dict[str, dict[str, list[Path]]] = {}
    for d in DIRS:
        base = ROOT / d
        if not base.is_dir():
            continue
        for folder, locale in SOURCES.items():
            sub = base / folder
            if not sub.is_dir():
                continue
            for f in sorted(sub.glob("*.png")):
                with Image.open(f) as im:
                    size = im.size
                dt = BY_SIZE.get(size)
                if not dt:
                    log(f"skipping {f.relative_to(ROOT)}: {size[0]}x{size[1]} is not a size Apple takes")
                    continue
                out.setdefault(locale, {}).setdefault(dt, []).append(f)

    watch = ROOT / WATCH_DIR
    if watch.is_dir():
        for f in sorted(watch.glob(WATCH_GLOB)):
            with Image.open(f) as im:
                size = im.size
            dt = BY_SIZE.get(size)
            if not dt:
                log(f"skipping {f.relative_to(ROOT)}: {size[0]}x{size[1]} is not a size Apple takes")
                continue
            for locale in SOURCES.values():
                out.setdefault(locale, {}).setdefault(dt, []).append(f)
    return out


def screenshot_set(c: Client, loc_id: str, display_type: str) -> str:
    for s in c.all(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
                   {"fields[appScreenshotSets]": "screenshotDisplayType"}):
        if s["attributes"]["screenshotDisplayType"] == display_type:
            return s["id"]
    return c.request("POST", "/appScreenshotSets",
                     {"data": {"type": "appScreenshotSets",
                               "attributes": {"screenshotDisplayType": display_type},
                               "relationships": {"appStoreVersionLocalization":
                                                 {"data": {"type": "appStoreVersionLocalizations",
                                                           "id": loc_id}}}}})["data"]["id"]


def upload(c: Client, set_id: str, path: Path) -> str:
    blob = path.read_bytes()
    row = c.request("POST", "/appScreenshots",
                    {"data": {"type": "appScreenshots",
                              "attributes": {"fileSize": len(blob), "fileName": path.name},
                              "relationships": {"appScreenshotSet":
                                                {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for op in row["attributes"]["uploadOperations"]:
        c.put_bytes(op, blob)
    # MD5, not SHA. Apple names the field sourceFileChecksum and silently fails the asset otherwise.
    c.request("PATCH", f"/appScreenshots/{row['id']}",
              {"data": {"type": "appScreenshots", "id": row["id"],
                        "attributes": {"uploaded": True,
                                       "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    return row["id"]


def wait_processed(c: Client, ids: list[str], timeout: float = 300) -> None:
    """Apple validates after the PUT, so a 200 upload can still end in a failed asset."""
    deadline = time.time() + timeout
    pending = list(ids)
    while pending and time.time() < deadline:
        still = []
        for sid in pending:
            a = c.request("GET", f"/appScreenshots/{sid}",
                          params={"fields[appScreenshots]": "assetDeliveryState,fileName"})["data"]["attributes"]
            state = (a.get("assetDeliveryState") or {}).get("state")
            if state == "COMPLETE":
                continue
            if state == "FAILED":
                errs = (a.get("assetDeliveryState") or {}).get("errors")
                sys.exit(f"{a.get('fileName')} failed Apple's processing: {errs}")
            still.append(sid)
        pending = still
        if pending:
            time.sleep(5)
    if pending:
        sys.exit(f"{len(pending)} screenshots still processing after {timeout:.0f}s")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", help="CFBundleShortVersionString, e.g. 1.15.0")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--replace", action="store_true", help="delete existing shots in each set first")
    ap.add_argument("--app-id", default=os.environ.get("APP_STORE_ID", "6809010622"))
    a = ap.parse_args()

    found = discover()
    for locale, by_type in sorted(found.items()):
        for dt, files in sorted(by_type.items()):
            print(f"{locale:6} {dt:24} {len(files)} file(s): {', '.join(f.name for f in files)}")
    if not found:
        sys.exit("no screenshots found under " + ", ".join(DIRS))
    if a.dry_run:
        print("\ndry run: nothing uploaded")
        return 0
    if not a.version:
        sys.exit("pass --version, or --dry-run")

    c = Client()
    vers = [v for v in c.all(f"/apps/{a.app_id}/appStoreVersions",
                             {"filter[platform]": "IOS", "limit": 20,
                              "fields[appStoreVersions]": "versionString"})
            if v["attributes"]["versionString"] == a.version]
    if not vers:
        sys.exit(f"no App Store version {a.version}")
    locs = {r["attributes"]["locale"]: r["id"]
            for r in c.all(f"/appStoreVersions/{vers[0]['id']}/appStoreVersionLocalizations",
                           {"fields[appStoreVersionLocalizations]": "locale"})}

    uploaded: list[str] = []
    for locale, by_type in sorted(found.items()):
        if locale not in locs:
            log(f"skipping {locale}: the version has no localisation for it")
            continue
        for dt, files in sorted(by_type.items()):
            set_id = screenshot_set(c, locs[locale], dt)
            if a.replace:
                for old in c.all(f"/appScreenshotSets/{set_id}/appScreenshots",
                                 {"fields[appScreenshots]": "fileName"}):
                    c.request("DELETE", f"/appScreenshots/{old['id']}")
                log(f"{locale} {dt}: cleared")
            have = {s["attributes"].get("fileName")
                    for s in c.all(f"/appScreenshotSets/{set_id}/appScreenshots",
                                   {"fields[appScreenshots]": "fileName"})}
            for f in files:
                if f.name in have:
                    log(f"{locale} {dt}: {f.name} already there")
                    continue
                uploaded.append(upload(c, set_id, f))
                log(f"{locale} {dt}: {f.name} uploaded")
    if uploaded:
        log(f"waiting for Apple to process {len(uploaded)} screenshots")
        wait_processed(c, uploaded)
    print(f"done: {len(uploaded)} uploaded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
