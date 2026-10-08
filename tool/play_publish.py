#!/usr/bin/env python3
"""Upload an Android App Bundle to Google Play and put it on a track. No browser, no Play Console UI.

    tool/play.sh                                    # build, sign and upload to internal testing
    tool/play_publish.py --aab path/to/app.aab      # upload one that already exists
    tool/play_publish.py --aab a.aab --track production --rollout 0.1
    tool/play_publish.py --promote 29858273 --track production
    tool/play_publish.py --status                   # what each track is serving right now

This is the Android twin of `tool/testflight.sh`. It talks to the Google Play Android Publisher API
with a service account, the same shape as App Store Connect's API key: a private key on disk, a signed
assertion, no human in the loop. Nothing Google-specific is committed; everything is read from
`~/.config/opentransit/play.env` and a key file beside it.

    GOOGLE_PLAY_SERVICE_ACCOUNT  path to the service-account JSON (mode 600)
    PACKAGE_NAME                 defaults to com.jeronimotech.opentransit
    PLAY_TRACK                   internal | alpha | beta | production  (default internal)

How Play's API works, because its shape is unusual and the errors are unhelpful otherwise: changes are
not applied one at a time. You open an **edit**, attach things to it, and commit; an uncommitted edit
changes nothing, and an edit goes stale if the app is touched elsewhere meanwhile, which is why a
failed commit here is worth retrying from a fresh edit rather than debugging.

A release needs release notes in every language the listing is published in, or Play rejects the
commit. `--notes-from` reads them from a directory of `<locale>.txt` files.
"""
from __future__ import annotations

import argparse
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
VENV = HERE / ".venv-play"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TRACKS = ("internal", "alpha", "beta", "production")


# ----------------------------------------------------------------------------- bootstrap
def _ensure_deps() -> None:
    try:
        import cryptography  # noqa: F401
        import jwt  # noqa: F401
        return
    except ImportError:
        pass
    if os.environ.get("PLAY_PUBLISH_BOOTSTRAPPED"):
        sys.exit("pyjwt/cryptography still missing after venv bootstrap")
    py = VENV / "bin" / "python"
    if not py.exists():
        print(f"[play] creating venv {VENV} with pyjwt + cryptography", file=sys.stderr)
        subprocess.run([sys.executable, "-m", "venv", str(VENV)], check=True)
        subprocess.run([str(py), "-m", "pip", "install", "-q", "pyjwt>=2.8", "cryptography>=42"], check=True)
    env = dict(os.environ, PLAY_PUBLISH_BOOTSTRAPPED="1")
    os.execve(str(py), [str(py), __file__, *sys.argv[1:]], env)


_ensure_deps()

import jwt  # noqa: E402


def log(msg: str) -> None:
    print(f"[play] {msg}", file=sys.stderr)


# ----------------------------------------------------------------------------- client
class Client:
    def __init__(self, key_path: Path, package: str) -> None:
        try:
            acct = json.loads(key_path.read_text())
        except (OSError, ValueError) as e:
            sys.exit(f"cannot read the service account at {key_path}: {e}")
        for k in ("client_email", "private_key"):
            if not acct.get(k):
                sys.exit(f"the service account JSON has no {k}; it is not a key file")
        self.email = acct["client_email"]
        self.key = acct["private_key"]
        self.package = package
        self._token = ""
        self._exp = 0.0

    def token(self) -> str:
        now = time.time()
        if self._token and now < self._exp - 120:
            return self._token
        assertion = jwt.encode({"iss": self.email, "scope": SCOPE, "aud": TOKEN_URL,
                                "iat": int(now), "exp": int(now) + 3600}, self.key, algorithm="RS256")
        body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                       "assertion": assertion}).encode()
        req = urllib.request.Request(TOKEN_URL, data=body,
                                     headers={"Content-Type": "application/x-www-form-urlencoded"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.loads(r.read())
        self._token = data["access_token"]
        self._exp = now + float(data.get("expires_in", 3600))
        return self._token

    def request(self, method: str, path: str, *, body: dict | None = None, base: str = API,
                params: dict | None = None, data: bytes | None = None, content_type: str | None = None,
                timeout: int = 600) -> dict:
        url = f"{base}/applications/{self.package}{path}"
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        payload = data if data is not None else (json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(url, data=payload, method=method)
        req.add_header("Authorization", f"Bearer {self.token()}")
        if content_type:
            req.add_header("Content-Type", content_type)
        elif body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                err = json.loads(detail).get("error", {})
                msgs = [d.get("message") or d.get("reason") for d in err.get("errors", [])] or [err.get("message")]
                detail = "; ".join(m for m in msgs if m)
            except ValueError:
                pass
            hint = ""
            low = detail.lower()
            if "has not been used in project" in low or "is disabled" in low:
                # The first wall a new setup hits, and the message above buries it: the key is fine,
                # the API itself is off in the Cloud project.
                hint = ("\nThe key works — this is the Android Publisher API being switched off in the "
                        "Cloud project. Enable it at the URL in the message above, wait a minute, and "
                        "retry. Then, in Play Console: Setup -> API access to link the project, and "
                        "Users and permissions to invite this service account.")
            elif e.code == 401:
                hint = ("\nThe service account exists but Play is refusing it. In Play Console, under "
                        "Users and permissions, the account needs 'Release to testing tracks' or more, "
                        "and the Google Cloud project it belongs to must be linked under API access.")
            elif e.code == 403:
                # Granting only the release permissions is not enough and the message does not say so:
                # 'View app information' is a prerequisite, and without it the account cannot see the
                # app it is allowed to publish to. Play Console's own help text says this, in a
                # paragraph under a different checkbox.
                hint = ("\nAuthenticated but not permitted. In Play Console -> Users and permissions, "
                        "open this service account and check that Account permissions includes "
                        "'View app information and download bulk reports (read-only)'. It is a "
                        "prerequisite for the release permissions, and granting those alone leaves "
                        "exactly this error.")
            elif e.code == 404:
                hint = (f"\nPlay has no app with the package {self.package}. The first upload of a new "
                        "app has to go through the Play Console UI; the API can only add builds to an "
                        "app that already exists.")
            sys.exit(f"Play API {method} {path} -> HTTP {e.code}: {detail}{hint}")


# ----------------------------------------------------------------------------- actions
def read_notes(src: Path | None, fallback_locale: str) -> list[dict]:
    """Release notes per locale. Play rejects a commit that has none for a published language."""
    if src is None:
        return []
    if src.is_file():
        return [{"language": fallback_locale, "text": src.read_text().strip()[:500]}]
    out = []
    for f in sorted(src.glob("*.txt")):
        text = f.read_text().strip()
        if text:
            out.append({"language": f.stem, "text": text[:500]})
    if not out:
        sys.exit(f"no <locale>.txt files with content in {src}")
    return out


def status(c: Client) -> int:
    edit = c.request("POST", "/edits")["id"]
    try:
        tracks = c.request("GET", f"/edits/{edit}/tracks").get("tracks", [])
    finally:
        c.request("DELETE", f"/edits/{edit}")
    if not tracks:
        print("no tracks have a release yet")
        return 0
    for t in tracks:
        for rel in t.get("releases", []):
            codes = ", ".join(str(v) for v in rel.get("versionCodes", []) or [])
            frac = rel.get("userFraction")
            share = f" · {frac * 100:.0f}% of users" if frac else ""
            print(f"{t['track']:11} {rel.get('status', '?'):11} {rel.get('name') or '':10} "
                  f"versionCode {codes or '-'}{share}")
    return 0


def promote(c: Client, code: int, track: str, rollout: float | None, notes: list[dict],
            name: str | None, draft: bool) -> int:
    """Put a versionCode that is already uploaded onto another track.

    Promotion is the normal Play workflow and this had no way to do it: the only path to production
    was building again, which produces a *different* versionCode for identical code. Then the build
    testers approved is not the build users get, and nothing in either console says so.
    """
    log(f"opening an edit for {c.package}")
    edit = c.request("POST", "/edits")["id"]
    committed = False
    try:
        release: dict = {"versionCodes": [str(code)], "status": "draft" if draft else "completed"}
        if name:
            release["name"] = name
        if notes:
            release["releaseNotes"] = notes
        if rollout is not None and not draft:
            release["status"] = "inProgress"
            release["userFraction"] = rollout
        c.request("PUT", f"/edits/{edit}/tracks/{track}", body={"track": track, "releases": [release]})
        log(f"assigned versionCode {code} to {track} as {release['status']}")
        c.request("POST", f"/edits/{edit}:commit")
        committed = True
        log("committed")
    finally:
        if not committed:
            try:
                c.request("DELETE", f"/edits/{edit}")
                log("edit discarded, nothing was changed")
            except SystemExit:
                pass
    print(f"versionCode {code} is on {track}")
    return 0


def publish(c: Client, aab: Path, track: str, rollout: float | None, notes: list[dict],
            name: str | None, draft: bool) -> int:
    if not aab.is_file():
        sys.exit(f"no bundle at {aab}")
    log(f"opening an edit for {c.package}")
    edit = c.request("POST", "/edits")["id"]
    committed = False
    try:
        size_mb = aab.stat().st_size / 1e6
        log(f"uploading {aab.name} ({size_mb:.1f} MB) — this is the slow part")
        ct = mimetypes.types_map.get(".aab") or "application/octet-stream"
        info = c.request("POST", f"/edits/{edit}/bundles", base=UPLOAD, params={"uploadType": "media"},
                         data=aab.read_bytes(), content_type=ct, timeout=1800)
        code = info["versionCode"]
        log(f"uploaded as versionCode {code}")

        release: dict = {"versionCodes": [str(code)], "status": "draft" if draft else "completed"}
        if name:
            release["name"] = name
        if notes:
            release["releaseNotes"] = notes
        if rollout is not None and not draft:
            # A staged rollout is its own status; Play rejects a userFraction on a completed release.
            release["status"] = "inProgress"
            release["userFraction"] = rollout
        c.request("PUT", f"/edits/{edit}/tracks/{track}", body={"track": track, "releases": [release]})
        log(f"assigned to the {track} track as {release['status']}")

        c.request("POST", f"/edits/{edit}:commit")
        committed = True
        log("committed")
    finally:
        if not committed:
            # An abandoned edit would otherwise linger and make the next one fail as stale.
            try:
                c.request("DELETE", f"/edits/{edit}")
                log("edit discarded, nothing was changed")
            except SystemExit:
                pass
    print(f"versionCode {code} is on {track}"
          + (" as a draft; release it in Play Console" if draft else ""))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--aab", type=Path, help="the bundle to upload")
    ap.add_argument("--track", default=os.environ.get("PLAY_TRACK", "internal"), choices=TRACKS)
    ap.add_argument("--rollout", type=float, help="staged rollout fraction, e.g. 0.1 for 10%%")
    ap.add_argument("--notes-from", type=Path, help="a <locale>.txt directory, or one file")
    ap.add_argument("--notes-locale", default="en-US", help="locale for a single notes file")
    ap.add_argument("--name", help="release name shown in Play Console (default: the versionName)")
    ap.add_argument("--draft", action="store_true", help="attach it without releasing")
    ap.add_argument("--status", action="store_true", help="print what each track is serving")
    ap.add_argument("--promote", type=int, metavar="VERSIONCODE",
                    help="put a versionCode that is already uploaded onto --track")
    ap.add_argument("--package", default=os.environ.get("PACKAGE_NAME", "com.jeronimotech.opentransit"))
    ap.add_argument("--key", type=Path,
                    default=Path(os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT")
                                 or Path.home() / ".config/opentransit/play-service-account.json"))
    a = ap.parse_args()

    c = Client(a.key, a.package)
    if a.status:
        return status(c)
    if not a.aab and a.promote is None:
        ap.error("pass --aab, --promote, or --status")
    if a.aab and a.promote is not None:
        ap.error("--aab uploads a new bundle and --promote moves one that exists; pick one")
    notes = read_notes(a.notes_from, a.notes_locale)
    if a.rollout is not None and not 0 < a.rollout <= 1:
        ap.error("--rollout is a fraction between 0 and 1")
    if a.promote is not None:
        return promote(c, a.promote, a.track, a.rollout, notes, a.name, a.draft)
    return publish(c, a.aab, a.track, a.rollout, notes, a.name, a.draft)


if __name__ == "__main__":
    sys.exit(main())
