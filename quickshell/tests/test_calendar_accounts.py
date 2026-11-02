import importlib.util
import json
from pathlib import Path
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("station_calendar", ROOT / "dotfiles/.local/lib/station_calendar.py")
cal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cal)

class AccountsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.config, self.cache = root / "config", root / "cache"
        self.config.mkdir(); self.cache.mkdir()
        self.paths = patch.multiple(cal, CONFIG=self.config, CACHE=self.cache, ACCOUNTS=self.config / "accounts.json")
        self.paths.start()

    def tearDown(self):
        self.paths.stop(); self.tmp.cleanup()

    def feed(self):
        return cal.handle({"op": "feed", "label": "Personal", "url": "https://calendar.example/private-SECRET.ics"})["accounts"][0]

    def test_legacy_import_is_idempotent_and_keeps_original(self):
        old = "work gcal:primary\npersonal https://example.org/private-SECRET.ics\n"
        (self.config / "urls.conf").write_text(old)
        (self.config / "token-work.json").write_text('{"refresh_token":"SECRET"}')
        first = cal.load_accounts()
        self.assertEqual(first, cal.load_accounts())
        self.assertEqual(len(first["accounts"]), 2)
        self.assertEqual((self.config / "urls.conf").read_text(), old)
        view = json.dumps(cal.snapshot())
        self.assertNotIn("SECRET", view)
        self.assertNotIn("private-", view)
        for item in first["accounts"]:
            self.assertEqual(cal.credential_path(item["id"]).stat().st_mode & 0o777, 0o600)
        cal.handle({"op": "remove", "id": first["accounts"][0]["id"]})
        self.assertEqual(len(cal.load_accounts()["accounts"]), 1)

    def test_traversal_legacy_key_cannot_read_other_tokens(self):
        (self.config / "urls.conf").write_text("../../other gcal:primary\n")
        self.assertEqual(cal.load_accounts()["accounts"], [])
        with self.assertRaises(cal.CalendarError):
            cal.credential_path("../secret")

    def test_pause_prunes_published_events_and_late_sync(self):
        item = self.feed(); key = item["id"] + ":feed"
        value = dict(events=[dict(c=key, t="meeting")], cals={key: {"ok": True}}, days={"2026-10-30": {"e": [key], "h": ["holiday"]}})
        cal.publish(value)
        cal.handle({"op": "enable", "id": item["id"], "enabled": False})
        cal.publish(value)
        saved = cal.read_json(self.cache / "caldash.json")
        self.assertEqual(saved["events"], [])
        self.assertEqual(saved["days"]["2026-10-30"]["e"], [])
        self.assertEqual(saved["days"]["2026-10-30"]["h"], ["holiday"])

    def test_selection_validates_and_can_hide_every_calendar(self):
        item = self.feed()
        with self.assertRaises(cal.CalendarError):
            cal.handle({"op": "select", "id": item["id"], "calendars": ["other"]})
        cal.handle({"op": "select", "id": item["id"], "calendars": []})
        self.assertFalse(cal.find_account(item["id"])["calendars"][0]["selected"])

    def test_removal_purges_own_credentials_and_cache(self):
        item = self.feed()
        path = cal.event_path(item["id"], "feed")
        cal.write_json(path, {"events": [{"t": "Private meeting"}]})
        cal.handle({"op": "remove", "id": item["id"]})
        self.assertFalse(path.exists())
        self.assertFalse(cal.credential_path(item["id"]).exists())

    def test_bad_configuration_is_not_overwritten(self):
        (self.config / "accounts.json").write_text("BROKEN")
        with self.assertRaises(ValueError):
            cal.load_accounts()
        self.assertEqual((self.config / "accounts.json").read_text(), "BROKEN")

    def test_credentials_write_replaces_symlink_not_its_target(self):
        target = self.config / "other"
        target.write_text("KEEP")
        path = self.config / "token.json"
        path.symlink_to(target)
        cal.write_json(path, {"secret": "token"})
        self.assertEqual(target.read_text(), "KEEP")
        self.assertFalse(path.is_symlink())
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_safe_errors_do_not_echo_provider_payload(self):
        value = cal.safe_error(ValueError("SECRET https://private/feed?code=SECRET"))
        self.assertNotIn("SECRET", json.dumps(value))
        with self.assertRaises(cal.CalendarError) as error:
            cal.microsoft_result({"error": "access_denied", "error_description": "SECRET", "error_codes": [53003]})
        self.assertNotIn("SECRET", str(error.exception))
        self.assertIn("AADSTS53003", str(error.exception))
        with self.assertRaises(cal.CalendarError) as error:
            cal.microsoft_result({"error": "access_denied", "error_description": "AADSTS90094: SECRET user details"})
        self.assertIn("administrator", str(error.exception))
        self.assertIn("AADSTS90094", str(error.exception))
        self.assertNotIn("SECRET", str(error.exception))

    def test_feed_rejects_non_https_and_url_credentials(self):
        for url in ("file:///etc/passwd", "http://private/feed", "https://user:pass@example.org/feed"):
            with self.assertRaises(cal.CalendarError):
                cal.handle({"op": "feed", "label": "Calendar", "url": url})

    def test_google_pagination_and_graph_nextlink(self):
        with patch.object(cal, "api_json", side_effect=[{"items": [1], "nextPageToken": "p2"}, {"items": [2]}]) as api:
            self.assertEqual(list(cal.pages("https://www.googleapis.com/calendar/v3/x", "token", {"a": 1})), [1, 2])
            self.assertEqual(api.call_args.args[2], {"a": 1, "pageToken": "p2"})
        with patch.object(cal, "api_json", side_effect=[{"value": [1], "@odata.nextLink": cal.GRAPH + "next"}, {"value": [2]}]) as api:
            self.assertEqual(list(cal.pages(cal.GRAPH + "me/calendars", "token", graph=True)), [1, 2])
            self.assertEqual(api.call_args.args[0], cal.GRAPH + "next")
        with self.assertRaises(cal.CalendarError):
            cal.api_json("https://evil.example/next", "SECRET", graph=True)

    def test_offline_source_keeps_events_with_error(self):
        item = self.feed(); key = item["id"] + ":feed"
        cal.write_json(cal.event_path(item["id"], "feed"), {"ts": 100, "events": [{"s": "2026-10-30T10:00:00+02:00", "e": "2026-10-30T11:00:00+02:00", "t": "Meeting", "a": False, "c": key}]})
        start = datetime(2026, 10, 1, tzinfo=ZoneInfo("Europe/Vilnius"))
        end = datetime(2026, 11, 1, tzinfo=start.tzinfo)
        def offline(*_):
            raise TimeoutError("secret URL")
        events, states = cal.collect_sources(start, end, start.tzinfo, offline)
        self.assertEqual(len(events), 1)
        self.assertFalse(states[key]["ok"])
        self.assertEqual(states[key]["ts"], 100)
        self.assertNotIn("secret URL", states[key]["err"])

    def test_discovery_preserves_selection_and_legacy_primary(self):
        (self.config / "urls.conf").write_text("work gcal:primary\n")
        item = cal.load_accounts()["accounts"][0]
        with patch.object(cal, "discover", return_value=([{"id": "me@example.org", "name": "Work", "primary": True}, {"id": "team", "name": "Team"}], "me@example.org")):
            cal.refresh_calendars(item["id"])
        item = cal.find_account(item["id"])
        self.assertTrue(item["calendars"][0]["selected"])
        self.assertFalse(item["calendars"][1]["selected"])

    def test_google_dates_and_declined_cancelled_events(self):
        rows = [{"start": {"date": "2026-10-25"}, "end": {"date": "2026-10-26"}, "summary": "Holiday"},
                {"status": "cancelled"}, {"attendees": [{"self": True, "responseStatus": "declined"}]}]
        result = cal.normalized_google(rows, "key", ZoneInfo("Europe/Vilnius"))
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["s"], "2026-10-25T00:00:00+03:00")
        self.assertEqual(result[0]["e"], "2026-10-26T00:00:00+02:00")

    def test_microsoft_recurring_instances_and_utc_all_day(self):
        rows = [{"subject": "Call", "start": {"dateTime": "2026-10-30T08:00:00.0000000", "timeZone": "UTC"},
                 "end": {"dateTime": "2026-10-30T09:00:00", "timeZone": "UTC"}},
                {"subject": "Day", "isAllDay": True, "originalStartTimeZone": "FLE Standard Time",
                 "start": {"dateTime": "2026-10-29T22:00:00", "timeZone": "UTC"}, "end": {"dateTime": "2026-10-30T22:00:00", "timeZone": "UTC"}},
                {"isCancelled": True}, {"responseStatus": {"response": "declined"}}]
        result = cal.normalized_microsoft(rows, "key", ZoneInfo("Europe/Vilnius"))
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["s"], "2026-10-30T10:00:00+02:00")
        self.assertEqual(result[1]["s"], "2026-10-30T00:00:00+02:00")
        self.assertEqual(result[1]["e"], "2026-10-31T00:00:00+02:00")

    def test_callback_rejects_bad_state_without_consuming_login(self):
        with cal.CallbackServer() as server:
            result = []
            thread = threading.Thread(target=lambda: result.append(server.wait("right", timeout=3)))
            thread.start()
            base = "http://127.0.0.1:" + str(server.server_port)
            for path in ("/?code=SECRET&state=wrong", "/?code=SECRET&state=right&state=right", "/favicon.ico"):
                with self.assertRaises(urllib.error.HTTPError) as error:
                    urllib.request.urlopen(base + path, timeout=2)
                self.assertEqual(error.exception.code, 400)
                error.exception.close()
            response = urllib.request.urlopen(base + "/?code=SECRET&state=right", timeout=2)
            self.assertNotIn(b"SECRET", response.read())
            self.assertEqual(response.headers["Cache-Control"], "no-store")
            thread.join(3)
            self.assertEqual(result, [{"code": "SECRET", "state": "right"}])

    def test_callback_times_out_and_closes(self):
        with cal.CallbackServer() as server:
            with self.assertRaises(cal.CalendarError) as error:
                server.wait("right", timeout=0.01)
            self.assertEqual(error.exception.code, "timeout")

    def test_callback_accepts_microsoft_form_post(self):
        with cal.CallbackServer() as server:
            result = []
            thread = threading.Thread(target=lambda: result.append(server.wait("right", timeout=3)))
            thread.start()
            url = "http://127.0.0.1:" + str(server.server_port) + "/"
            with urllib.request.urlopen(url, data=b"state=right&code=TEST", timeout=2) as response:
                self.assertEqual(response.status, 200)
                self.assertNotIn(b"TEST", response.read())
            thread.join(3)
            self.assertEqual(result, [{"state": "right", "code": "TEST"}])

    def test_google_login_uses_pkce_and_cancel_keeps_existing_credentials(self):
        (self.config / "urls.conf").write_text("work gcal:primary\n")
        token = {"client_id": "example.apps.googleusercontent.com", "client_secret": "TEST", "refresh_token": "KEEP"}
        (self.config / "token-work.json").write_text(json.dumps(token))
        item = cal.load_accounts()["accounts"][0]
        messages = []
        with patch.object(cal.CallbackServer, "wait", side_effect=cal.CalendarError("timeout", "Cancelled")):
            with self.assertRaises(cal.CalendarError):
                cal.handle({"op": "connect", "id": item["id"]}, messages.append)
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(messages[0]["url"]).query)
        self.assertEqual(query["code_challenge_method"], ["S256"])
        self.assertEqual(query["scope"], [cal.GOOGLE_SCOPE])
        self.assertTrue(query["redirect_uri"][0].startswith("http://127.0.0.1:"))
        self.assertEqual(cal.read_json(cal.credential_path(item["id"])), token)

    def test_microsoft_login_uses_msal_pkce_without_mail_or_write_access(self):
        import msal
        from unittest.mock import Mock
        client = "11111111-2222-3333-4444-555555555555"
        cal.handle({"op": "setup", "provider": "microsoft", "client_id": client})
        metadata = {"authorization_endpoint": "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize",
                    "token_endpoint": "https://login.microsoftonline.com/organizations/oauth2/v2.0/token",
                    "issuer": "https://login.microsoftonline.com/{tenantid}/v2.0"}
        http = Mock()
        http.get.return_value = SimpleNamespace(status_code=200, text=json.dumps(metadata), headers={})
        def app(config, cache):
            return msal.PublicClientApplication(client, authority="https://login.microsoftonline.com/organizations",
                token_cache=cache, http_client=http, instance_discovery=False)
        messages = []
        with patch.object(cal, "microsoft_app", side_effect=app), patch.object(cal.CallbackServer, "wait", side_effect=cal.CalendarError("timeout", "Cancelled")):
            with self.assertRaises(cal.CalendarError):
                cal.handle({"op": "connect", "provider": "microsoft", "email": "user@example.org"}, messages.append)
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(messages[0]["url"]).query)
        self.assertEqual(query["code_challenge_method"], ["S256"])
        self.assertEqual(set(query["scope"][0].split()), {"Calendars.ReadBasic", "openid", "profile", "offline_access"})
        self.assertEqual(query["response_mode"], ["form_post"])
        self.assertTrue(query["redirect_uri"][0].startswith("http://localhost:"))
        self.assertEqual(cal.load_accounts()["accounts"], [])

    def test_successful_google_login_selects_primary_calendar(self):
        from google_auth_oauthlib.flow import InstalledAppFlow
        cal.load_accounts()
        cal.write_json(self.config / "client.json", {"installed": {"client_id": "example.apps.googleusercontent.com", "client_secret": "TEST"}})
        def exchange(flow, **_):
            flow.oauth2session.token = {"access_token": "TEST", "refresh_token": "TEST_REFRESH", "expires_at": 9999999999, "scope": cal.GOOGLE_SCOPE}
        choices = [{"id": "user@example.org", "name": "Primary", "primary": True}, {"id": "team", "name": "Team"}]
        with patch.object(cal.CallbackServer, "wait", return_value={"code": "TEST"}), patch.object(InstalledAppFlow, "fetch_token", exchange), patch.object(cal, "discover", return_value=(choices, "user@example.org")):
            result = cal.handle({"op": "connect", "provider": "google", "email": "user@example.org"})
        item = result["accounts"][0]
        self.assertEqual(item["email"], "user@example.org")
        self.assertEqual([c["selected"] for c in item["calendars"]], [True, False])
        self.assertNotIn("TEST_REFRESH", json.dumps(result))
        self.assertEqual(cal.credential_path(item["id"]).stat().st_mode & 0o777, 0o600)

if __name__ == "__main__":
    unittest.main()
