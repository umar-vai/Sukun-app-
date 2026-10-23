import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_google_oauth_handoff import validate_google_redirect


class GoogleOauthHandoffTests(unittest.TestCase):
    BASE = "https://qacklgqvxvjjzsimjoip.supabase.co"
    CALLBACK = BASE + "/auth/v1/callback"

    def test_exact_google_redirect(self):
        from urllib.parse import urlencode
        url = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode({
            "client_id": "synthetic-id.apps.googleusercontent.com",
            "redirect_uri": self.CALLBACK,
            "response_type": "code",
        })
        validate_google_redirect(url, self.BASE)

    def test_rejects_other_project_callback(self):
        from urllib.parse import urlencode
        url = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode({
            "client_id": "synthetic",
            "redirect_uri": "https://vydfafumxptanpkmtrpr.supabase.co/auth/v1/callback",
            "response_type": "code",
        })
        with self.assertRaises(ValueError):
            validate_google_redirect(url, self.BASE)

    def test_rejects_non_google_host_and_missing_client(self):
        with self.assertRaises(ValueError):
            validate_google_redirect(
                "https://accounts.google.com.evil.example/path", self.BASE
            )
        with self.assertRaises(ValueError):
            validate_google_redirect(
                "https://accounts.google.com/o/oauth2/v2/auth?response_type=code",
                self.BASE,
            )


if __name__ == "__main__":
    unittest.main()
