#!/usr/bin/env python3
"""App Store Connect signing helper — bundle id, distribution certificate, App Store profile, builds.

Idempotent: every subcommand returns the existing record when one matches and only creates
when nothing usable exists. Never prints key material (the .p8, private keys, or the certificate
bytes); certificates and profiles are written to files you name.

Environment (read at start; `set -a; source ~/.config/opentransit/apple.env; set +a`):
  ASC_KEY_ID, ASC_ISSUER_ID     App Store Connect API key (role App Manager is enough)
  ASC_KEY_PATH                  path to AuthKey_<ASC_KEY_ID>.p8
                                (default ~/.appstoreconnect/private_keys/AuthKey_<id>.p8)
  APPLE_TEAM_ID                 10-char team id (used to name records)
  BUNDLE_ID                     app bundle identifier (e.g. com.jeronimotech.opentransit)

Subcommands (all print one JSON object on stdout; diagnostics go to stderr):
  bundle-id                     get-or-create the bundle id record; enables ASSOCIATED_DOMAINS
  certificate --csr PATH [--out PATH]
                                get-or-create an IOS_DISTRIBUTION certificate whose public key matches
                                the CSR; writes the DER .cer to --out
  profile --cert-id ID [--name NAME] [--install]
                                get-or-create an IOS_APP_STORE profile for BUNDLE_ID + certificate;
                                --install saves it under ~/Library/MobileDevice/Provisioning Profiles
  builds [--limit N] [--wait] [--version BUILD] [--build-name NAME] [--timeout MIN]
                                list recent builds of the app; --wait polls until --version
                                (optionally narrowed by --build-name) is VALID

Dependencies: pyjwt + cryptography. If they are missing the script bootstraps a private venv in
tool/.venv-asc (git-ignored) and re-executes itself inside it.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import plistlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
VENV = HERE / ".venv-asc"
API = "https://api.appstoreconnect.apple.com/v1"


# ----------------------------------------------------------------------------- bootstrap
def _ensure_deps() -> None:
    try:
        import cryptography  # noqa: F401
        import jwt  # noqa: F401
        return
    except ImportError:
        pass
    if os.environ.get("ASC_SIGNING_BOOTSTRAPPED"):
        sys.exit("pyjwt/cryptography still missing after venv bootstrap")
    py = VENV / "bin" / "python"
    if not py.exists():
        print(f"[asc] creating venv {VENV} with pyjwt + cryptography", file=sys.stderr)
        subprocess.run([sys.executable, "-m", "venv", str(VENV)], check=True)
        subprocess.run([str(py), "-m", "pip", "install", "-q", "pyjwt>=2.8", "cryptography>=42"], check=True)
    env = dict(os.environ, ASC_SIGNING_BOOTSTRAPPED="1")
    os.execve(str(py), [str(py), __file__, *sys.argv[1:]], env)


_ensure_deps()

import jwt  # noqa: E402
from cryptography import x509  # noqa: E402
from cryptography.hazmat.primitives import serialization  # noqa: E402


# ----------------------------------------------------------------------------- client
class Env:
    def __init__(self) -> None:
        self.key_id = self._req("ASC_KEY_ID")
        self.issuer = self._req("ASC_ISSUER_ID")
        self.team = os.environ.get("APPLE_TEAM_ID", "")
        self.bundle_id = os.environ.get("BUNDLE_ID", "")
        default = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{self.key_id}.p8"
        self.key_path = Path(os.environ.get("ASC_KEY_PATH") or default)
        if not self.key_path.is_file():
            sys.exit(f"API key file not found: {self.key_path}")

    @staticmethod
    def _req(name: str) -> str:
        v = os.environ.get(name)
        if not v:
            sys.exit(f"missing env {name}")
        return v


class Client:
    def __init__(self, env: Env) -> None:
        self.env = env
        self._token = ""
        self._token_exp = 0.0

    def token(self) -> str:
        now = time.time()
        if now < self._token_exp - 60:
            return self._token
        key = self.env.key_path.read_text()
        payload = {"iss": self.env.issuer, "iat": int(now), "exp": int(now) + 15 * 60,
                   "aud": "appstoreconnect-v1"}
        self._token = jwt.encode(payload, key, algorithm="ES256",
                                 headers={"kid": self.env.key_id, "typ": "JWT"})
        self._token_exp = now + 15 * 60
        return self._token

    def request(self, method: str, path: str, body: dict | None = None, params: dict | None = None) -> dict:
        url = path if path.startswith("http") else API + path
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params, doseq=True)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token()}")
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                errs = json.loads(detail).get("errors", [])
                detail = "; ".join(f"{x.get('code')}: {x.get('detail') or x.get('title')}" for x in errs)
            except Exception:
                pass
            sys.exit(f"ASC API {method} {path} -> HTTP {e.code}: {detail}")

    def get_all(self, path: str, params: dict | None = None) -> list[dict]:
        out: list[dict] = []
        params = dict(params or {})
        params.setdefault("limit", 200)
        page = self.request("GET", path, params=params)
        out += page.get("data", [])
        nxt = page.get("links", {}).get("next")
        while nxt:
            page = self.request("GET", nxt)
            out += page.get("data", [])
            nxt = page.get("links", {}).get("next")
        return out


def log(msg: str) -> None:
    print(f"[asc] {msg}", file=sys.stderr)


def emit(obj: dict) -> None:
    print(json.dumps(obj, indent=2))


# ----------------------------------------------------------------------------- bundle-id
def cmd_bundle_id(c: Client, args: argparse.Namespace) -> None:
    ident = c.env.bundle_id or sys.exit("missing env BUNDLE_ID")
    recs = c.get_all("/bundleIds", {"filter[identifier]": ident, "filter[platform]": "IOS"})
    recs = [r for r in recs if r["attributes"]["identifier"] == ident]
    if recs:
        rec = recs[0]
        log(f"bundle id exists: {rec['id']} ({ident})")
    else:
        name = args.name or ident.split(".")[-1]
        body = {"data": {"type": "bundleIds", "attributes": {"identifier": ident, "name": name, "platform": "IOS"}}}
        rec = c.request("POST", "/bundleIds", body)["data"]
        log(f"bundle id created: {rec['id']} ({ident})")
    caps = c.request("GET", f"/bundleIds/{rec['id']}/bundleIdCapabilities").get("data", [])
    types = sorted({x["attributes"]["capabilityType"] for x in caps})
    if "ASSOCIATED_DOMAINS" not in types:
        body = {"data": {"type": "bundleIdCapabilities",
                         "attributes": {"capabilityType": "ASSOCIATED_DOMAINS"},
                         "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": rec["id"]}}}}}
        c.request("POST", "/bundleIdCapabilities", body)
        types.append("ASSOCIATED_DOMAINS")
        log("enabled ASSOCIATED_DOMAINS")
    emit({"id": rec["id"], "identifier": ident, "name": rec["attributes"].get("name"),
          "capabilities": sorted(types)})


# ----------------------------------------------------------------------------- certificate
def _pub_der(obj) -> bytes:
    return obj.public_key().public_bytes(serialization.Encoding.DER,
                                         serialization.PublicFormat.SubjectPublicKeyInfo)


def cmd_certificate(c: Client, args: argparse.Namespace) -> None:
    csr_path = Path(args.csr)
    csr = x509.load_pem_x509_csr(csr_path.read_bytes())
    want = _pub_der(csr)
    certs = c.get_all("/certificates", {"filter[certificateType]": "IOS_DISTRIBUTION,DISTRIBUTION"})
    match = None
    for cert in certs:
        try:
            der = base64.b64decode(cert["attributes"]["certificateContent"])
            if _pub_der(x509.load_der_x509_certificate(der)) == want:
                match = cert
                break
        except Exception:
            continue
    others = [f"{x['id']} ({x['attributes'].get('certificateType')}, exp {x['attributes'].get('expirationDate', '')[:10]})"
              for x in certs]
    if match:
        log(f"certificate matching the CSR key exists: {match['id']}")
    else:
        if others:
            log(f"{len(others)} distribution certificate(s) exist with other keys: {', '.join(others)}")
        pem = csr_path.read_text()
        body = {"data": {"type": "certificates",
                         "attributes": {"certificateType": "IOS_DISTRIBUTION", "csrContent": pem}}}
        match = c.request("POST", "/certificates", body)["data"]
        log(f"certificate created: {match['id']}")
    out = None
    if args.out:
        out = Path(args.out)
        out.write_bytes(base64.b64decode(match["attributes"]["certificateContent"]))
        os.chmod(out, 0o644)
    a = match["attributes"]
    emit({"id": match["id"], "name": a.get("name"), "type": a.get("certificateType"),
          "serialNumber": a.get("serialNumber"), "expirationDate": a.get("expirationDate"),
          "matchesCsr": True, "written": str(out) if out else None})


# ----------------------------------------------------------------------------- profile
def _profile_plist(content_b64: str) -> dict:
    der = base64.b64decode(content_b64)
    out = subprocess.run(["security", "cms", "-D"], input=der, capture_output=True, check=True).stdout
    return plistlib.loads(out)


def cmd_profile(c: Client, args: argparse.Namespace) -> None:
    ident = c.env.bundle_id or sys.exit("missing env BUNDLE_ID")
    name = args.name or "opentransit App Store"
    bundles = [b for b in c.get_all("/bundleIds", {"filter[identifier]": ident, "filter[platform]": "IOS"})
               if b["attributes"]["identifier"] == ident]
    if not bundles:
        sys.exit(f"bundle id {ident} not registered; run `bundle-id` first")
    bundle = bundles[0]
    profs = [p for p in c.get_all("/profiles", {"filter[name]": name, "filter[profileType]": "IOS_APP_STORE"})
             if p["attributes"]["name"] == name]
    rec = None
    for p in profs:
        if p["attributes"].get("profileState") != "ACTIVE":
            log(f"profile {p['id']} is {p['attributes'].get('profileState')}; deleting")
            c.request("DELETE", f"/profiles/{p['id']}")
            continue
        certs = c.request("GET", f"/profiles/{p['id']}/certificates").get("data", [])
        pb = c.request("GET", f"/profiles/{p['id']}/bundleId")["data"]
        if args.cert_id in {x["id"] for x in certs} and pb["id"] == bundle["id"]:
            rec = p
            log(f"profile exists: {p['id']} ({name})")
            break
        log(f"profile {p['id']} does not include certificate {args.cert_id} / bundle {bundle['id']}; deleting")
        c.request("DELETE", f"/profiles/{p['id']}")
    if rec is None:
        body = {"data": {"type": "profiles", "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                         "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                                           "certificates": {"data": [{"type": "certificates", "id": args.cert_id}]}}}}
        rec = c.request("POST", "/profiles", body)["data"]
        log(f"profile created: {rec['id']} ({name})")
    a = rec["attributes"]
    meta = _profile_plist(a["profileContent"])
    path = None
    if args.install:
        d = Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles"
        d.mkdir(parents=True, exist_ok=True)
        path = d / f"{meta['UUID']}.mobileprovision"
        if not path.exists():
            path.write_bytes(base64.b64decode(a["profileContent"]))
            log(f"installed {path}")
        else:
            log(f"already installed {path}")
    emit({"id": rec["id"], "uuid": meta["UUID"], "name": a["name"], "state": a.get("profileState"),
          "expirationDate": a.get("expirationDate"), "bundleIdRecord": bundle["id"],
          "teamId": meta.get("TeamIdentifier", [""])[0], "path": str(path) if path else None})


# ----------------------------------------------------------------------------- builds
def cmd_builds(c: Client, args: argparse.Namespace) -> None:
    ident = c.env.bundle_id or sys.exit("missing env BUNDLE_ID")
    apps = [a for a in c.get_all("/apps", {"filter[bundleId]": ident}) if a["attributes"]["bundleId"] == ident]
    if not apps:
        sys.exit(f"no App Store Connect app record for {ident} (create it in App Store Connect → Apps)")
    app = apps[0]
    deadline = time.time() + args.timeout * 60

    def fetch() -> list[dict]:
        params = {"filter[app]": app["id"], "sort": "-uploadedDate", "limit": str(args.limit),
                  "fields[builds]": "version,processingState,uploadedDate,expired"}
        page = c.request("GET", "/builds", params)
        out = []
        for b in page.get("data", [])[: args.limit]:
            # `include=preReleaseVersion` returns nothing for builds; the relationship link does
            pv = c.request("GET", f"/builds/{b['id']}/preReleaseVersion").get("data") or {}
            out.append({"id": b["id"], "version": b["attributes"]["version"],
                        "buildName": (pv.get("attributes") or {}).get("version"),
                        "state": b["attributes"]["processingState"],
                        "uploaded": b["attributes"].get("uploadedDate")})
        if args.build_name:  # Apple ignores filter[preReleaseVersion.version]; match client-side
            out = [b for b in out if b["buildName"] == args.build_name]
        return out

    while True:
        builds = fetch()
        if not args.wait:
            emit({"app": {"id": app["id"], "name": app["attributes"].get("name"), "bundleId": ident},
                  "builds": builds})
            return
        mine = builds
        if args.version:
            mine = [b for b in mine if str(b["version"]) == str(args.version)]
        mine = mine[:1]
        state = mine[0]["state"] if mine else "NOT_YET_LISTED"
        log(f"build {args.version or '(latest)'}: {state}")
        if state == "VALID":
            emit({"app": {"id": app["id"], "name": app["attributes"].get("name"), "bundleId": ident},
                  "build": mine[0]})
            return
        if state in ("FAILED", "INVALID"):
            emit({"build": mine[0]})
            sys.exit(f"build processing ended in {state}")
        if time.time() > deadline:
            sys.exit(f"timed out after {args.timeout} min waiting for build {args.version} (last state {state})")
        time.sleep(30)


# ----------------------------------------------------------------------------- main
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("bundle-id"); p.add_argument("--name")
    p = sub.add_parser("certificate"); p.add_argument("--csr", required=True); p.add_argument("--out")
    p = sub.add_parser("profile"); p.add_argument("--cert-id", required=True); p.add_argument("--name")
    p.add_argument("--install", action="store_true")
    p = sub.add_parser("builds"); p.add_argument("--limit", type=int, default=10)
    p.add_argument("--wait", action="store_true"); p.add_argument("--version")
    p.add_argument("--build-name", help="CFBundleShortVersionString to narrow the match, e.g. 1.4.0")
    p.add_argument("--timeout", type=float, default=20)
    args = ap.parse_args()
    c = Client(Env())
    {"bundle-id": cmd_bundle_id, "certificate": cmd_certificate,
     "profile": cmd_profile, "builds": cmd_builds}[args.cmd](c, args)


if __name__ == "__main__":
    main()
