#!/usr/bin/env python3
"""Public-only Google OAuth start/callback preflight for the SAME Flutter Pages URL.

No Google login, member identity, tokens, credentials, cookies or callbacks are
used. This verifies Supabase's public authorization handoff but cannot prove
Google Cloud consent/audience, registered redirect URI or successful sign-in.
"""
import json
import os
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen

APP_URL = "https://app.sukunlife.com/"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_google_redirect(location: str, supabase_url: str) -> None:
    parsed = urlsplit(location)
    if parsed.scheme != "https" or parsed.hostname != "accounts.google.com":
        raise ValueError("Google OAuth did not reach Google's approved origin.")
    if parsed.username or parsed.password or parsed.port:
        raise ValueError("Unexpected Google OAuth redirect authority.")
    args = parse_qs(parsed.query)
    expected = supabase_url.rstrip("/") + "/auth/v1/callback"
    if args.get("redirect_uri") != [expected]:
        raise ValueError("Supabase callback URL differs from selected project.")
    if not args.get("client_id") or args.get("response_type") != ["code"]:
        raise ValueError("Incomplete Google authorization configuration.")


def main() -> None:
    base = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_PUBLISHABLE_KEY"]
    parsed = urlsplit(base)
    if parsed.scheme != "https" or not parsed.hostname or not parsed.hostname.endswith(".supabase.co"):
        raise SystemExit("Only an approved HTTPS Supabase project may be probed.")
    if not key.startswith("sb_publishable_"):
        raise SystemExit("Public publishable key required.")
    headers = {"apikey": key, "Accept": "application/json"}
    try:
        with urlopen(Request(base + "/auth/v1/settings", headers=headers), timeout=20) as r:
            settings = json.load(r)
        if settings.get("external", {}).get("google") is not True:
            raise ValueError("Google provider is disabled in selected Supabase project.")
        target = base + "/auth/v1/authorize?" + urlencode(
            {"provider": "google", "redirect_to": APP_URL}
        )
        opener = build_opener(NoRedirect())
        try:
            response = opener.open(Request(target, headers=headers), timeout=20)
            status, location = response.status, response.headers.get("Location", "")
            response.close()
        except HTTPError as exc:
            status, location = exc.code, exc.headers.get("Location", "")
            exc.close()
        if status not in (302, 303):
            raise ValueError("Google provider failed before the browser consent step.")
        validate_google_redirect(location, base)
    except (HTTPError, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        # Never print raw responses, request URLs or third-party error content.
        raise SystemExit("Google OAuth public handoff FAILED (S-OAUTH-GATE).") from None
    print("PASS: public Google OAuth handoff uses exact Supabase callback.")
    print("PENDING: Google Cloud consent/test-user and authenticated browser return.")


if __name__ == "__main__":
    main()
