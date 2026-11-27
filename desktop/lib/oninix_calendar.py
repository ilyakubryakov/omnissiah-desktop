
import contextlib
import fcntl
import hashlib
import hmac
import html
import json
import os
import re
import secrets
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import datetime, time as wall_time, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from zoneinfo import ZoneInfo

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "caldash"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
ACCOUNTS = CONFIG / "accounts.json"
GOOGLE_SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
MICROSOFT_SCOPES = ["Calendars.ReadBasic"]
GRAPH = "https://graph.microsoft.com/v1.0/"
TIMEOUT = 20
AUTH_TIMEOUT = 300

class CalendarError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code

def with_place(event, location):
    place = " ".join(str(location or "").split())[:200]
    if place and not re.search(r"https?://|teams|zoom|meet\.google|webex", place, re.I):
        event["l"] = place
    return event

def private_dir(path):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".calendar-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(value, f, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)

def read_json(path, default=None):
    if not path.exists():
        return default
    return json.loads(path.read_text())

def read_cache(path, default):
    try:
        return read_json(path, default)
    except (ValueError, OSError):
        return default

@contextlib.contextmanager
def lock(name, blocking=True):
    private_dir(CONFIG)
    fd = os.open(CONFIG / (name + ".lock"), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield
    finally:
        os.close(fd)

def account_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{32}", value):
        raise CalendarError("invalid", "Invalid calendar account.")
    return value

def credential_path(ident):
    return CONFIG / "credentials" / (account_id(ident) + ".json")

def event_path(ident, calendar):
    digest = hashlib.sha256(calendar.encode()).hexdigest()[:24]
    return CACHE / ("caldash-" + account_id(ident) + "-" + digest + ".events.json")

def load_accounts():
    with lock("accounts"):
        if ACCOUNTS.exists():
            value = read_json(ACCOUNTS)
            if value.get("version") != 1 or not isinstance(value.get("accounts"), list):
                raise CalendarError("configuration", "Calendar settings need repair; existing files were kept.")
            return value
        private_dir(CONFIG / "credentials")
        accounts = []
        legacy = CONFIG / "urls.conf"
        for line in legacy.read_text().splitlines() if legacy.exists() else []:
            parts = line.strip().split(None, 1)
            if len(parts) != 2 or parts[0].startswith("#"):
                continue
            key, spec = parts
            if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", key) or key in (".", ".."):
                continue
            ident = hashlib.sha256(("legacy:" + key).encode()).hexdigest()[:32]
            provider = "google" if spec.startswith("gcal:") else "ics"
            calendar = (spec[5:].strip() or "primary") if provider == "google" else "feed"
            entry = dict(id=ident, provider=provider, label=key, email="", enabled=True,
                         legacy_key=key, calendars=[dict(id=calendar, name=key, selected=True)])
            credentials = read_json(CONFIG / ("token-" + key + ".json"), {}) if provider == "google" else {"url": spec}
            write_json(credential_path(ident), credentials)
            old_cache = read_cache(CACHE / ("caldash-" + key + ".events.json"), None)
            if isinstance(old_cache, list):
                write_json(event_path(ident, calendar), old_cache)
            accounts.append(entry)
        result = {"version": 1, "accounts": accounts}
        write_json(ACCOUNTS, result)
        return result

def find_account(ident):
    account_id(ident)
    for item in load_accounts()["accounts"]:
        if item["id"] == ident:
            return item
    raise CalendarError("removed", "This account was removed. Refresh the calendar list.")

def edit_account(ident, change):
    load_accounts()
    with lock("accounts"):
        data = read_json(ACCOUNTS)
        for item in data["accounts"]:
            if item["id"] == account_id(ident):
                change(item)
                write_json(ACCOUNTS, data)
                return
    raise CalendarError("removed", "This account was removed.")

def safe_error(exc):
    if isinstance(exc, CalendarError):
        return {"code": exc.code, "message": str(exc)}
    name = type(exc).__name__
    if name in ("RefreshError", "InvalidGrantError", "TokenExpiredError"):
        return {"code": "signin", "message": "Sign in again to reconnect this account."}
    if name in ("Timeout", "ReadTimeout", "ConnectTimeout", "ConnectionError", "URLError", "TimeoutError"):
        return {"code": "network", "message": "Cannot reach the calendar service. Saved events are still available."}
    return {"code": "failed", "message": "Calendar operation failed (" + name + "). Existing settings were kept."}

BUILTIN = Path(__file__).resolve().with_name("oauth-clients.json")

def builtin(provider):
    return read_json(BUILTIN, {}).get(provider, {})

def google_client(path=None):
    if path:
        value = read_json(Path(path).expanduser(), {})
    elif (CONFIG / "client.json").is_file():
        value = read_json(CONFIG / "client.json", {})
    else:
        value = {"installed": builtin("google")}
    app = value.get("installed", {})
    if not app.get("client_id", "").endswith(".apps.googleusercontent.com") or not app.get("client_secret"):
        raise CalendarError("setup", "Choose a Google OAuth Desktop app JSON file in App setup.")
    return {"installed": {"client_id": app["client_id"], "client_secret": app["client_secret"],
                          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                          "token_uri": "https://oauth2.googleapis.com/token",
                          "redirect_uris": ["http://localhost"]}}

def microsoft_client(value=None):
    if value is not None:
        app = value
    elif (CONFIG / "microsoft.json").is_file():
        app = read_json(CONFIG / "microsoft.json", {})
    else:
        app = builtin("microsoft")
    client = app.get("client_id", "").strip()
    tenant = app.get("tenant", "organizations").strip() or "organizations"
    if not re.fullmatch(r"[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}", client):
        raise CalendarError("setup", "Add a Microsoft Entra Desktop app Client ID in App setup.")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", tenant):
        raise CalendarError("invalid", "Use a tenant ID, verified domain or organizations.")
    return {"client_id": client, "tenant": tenant}

def google_credentials(ident):
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    path = credential_path(ident)
    value = read_json(path, {})
    if not value.get("refresh_token"):
        raise CalendarError("signin", "Sign in to connect this Google account.")
    value["token_uri"] = "https://oauth2.googleapis.com/token"
    creds = Credentials.from_authorized_user_info(value, [GOOGLE_SCOPE])
    if not creds.valid:
        creds.refresh(lambda **kw: Request()(**dict(kw, timeout=TIMEOUT)))
        write_json(path, json.loads(creds.to_json()))
    return creds

def microsoft_app(app_config, cache=None):
    import msal
    app_config = microsoft_client(app_config)
    return msal.PublicClientApplication(app_config["client_id"],
        authority="https://login.microsoftonline.com/" + app_config["tenant"],
        token_cache=cache, timeout=TIMEOUT)

def microsoft_result(result):
    if result and result.get("access_token"):
        return result
    code = (result or {}).get("error", "interaction_required")
    codes = (result or {}).get("error_codes", [])
    if not codes:
        codes = [int(c) for c in re.findall(r"\bAADSTS(\d{4,8})\b", str((result or {}).get("error_description", "")))]
    if any(c in codes for c in (53000, 53001, 53002, 53003, 50097)):
        message = "Your organization requires an approved app or compliant device. Contact your administrator."
    elif 65001 in codes or 90094 in codes or code == "consent_required":
        message = "Microsoft requires consent or administrator approval for this app."
    elif code == "access_denied":
        message = "Access was declined. Retry when you are ready to grant calendar access."
    elif code in ("invalid_client", "unauthorized_client") or 700016 in codes:
        message = "Check the app Client ID, tenant and Desktop redirect URI in App setup."
    else:
        message = "Sign in again. Microsoft could not authorize calendar access."
    suffix = " · AADSTS" + str(codes[0]) if codes and isinstance(codes[0], int) else ""
    raise CalendarError("signin", message + suffix)

def microsoft_token(ident):
    import msal
    path = credential_path(ident)
    value = read_json(path, {})
    cache = msal.SerializableTokenCache()
    if not value.get("cache"):
        raise CalendarError("signin", "Sign in to connect this Microsoft account.")
    cache.deserialize(value["cache"])
    app = microsoft_app(value["app"], cache)
    accounts = app.get_accounts()
    match = next((a for a in accounts if a.get("home_account_id") == value.get("home_account_id")), None)
    result = app.acquire_token_silent_with_error(MICROSOFT_SCOPES, account=match) if match else None
    if cache.has_state_changed:
        value["cache"] = cache.serialize()
        write_json(path, value)
    return microsoft_result(result)["access_token"]

def api_json(url, token, params=None, graph=False):
    import requests
    base = GRAPH if graph else "https://www.googleapis.com/calendar/v3/"
    if not url.startswith(base):
        raise CalendarError("response", "The calendar service returned an unexpected page address.")
    response = requests.get(url, params=params, headers={"Authorization": "Bearer " + token,
        "Prefer": 'outlook.timezone="UTC"'} if graph else {"Authorization": "Bearer " + token},
        timeout=TIMEOUT, allow_redirects=False)
    if response.status_code == 401:
        raise CalendarError("signin", "Sign in again to reconnect this calendar.")
    if response.status_code == 403:
        raise CalendarError("permission", "Calendar access is blocked. Check consent, Calendar API access and your organization's app policy.")
    if response.status_code == 404:
        raise CalendarError("missing", "This calendar is no longer available. Refresh the calendar list.")
    if response.status_code == 429:
        raise CalendarError("rate_limit", "The calendar service is busy. Try syncing later.")
    if response.status_code != 200:
        raise CalendarError("network", "Calendar service unavailable (HTTP " + str(response.status_code) + ").")
    return response.json()

def pages(url, token, params=None, graph=False):
    for _ in range(100):
        data = api_json(url, token, params, graph)
        yield from data.get("value" if graph else "items", [])
        if graph:
            url = data.get("@odata.nextLink")
            params = None
            if not url:
                return
        else:
            page = data.get("nextPageToken")
            if not page:
                return
            params = dict(params or {}, pageToken=page)
    raise CalendarError("limit", "Calendar response is too large. Saved events were kept.")

def discover(item):
    ident, provider = item["id"], item["provider"]
    if provider == "ics":
        return item["calendars"], item.get("email", "")
    if provider == "google":
        token = google_credentials(ident).token
        data = list(pages("https://www.googleapis.com/calendar/v3/users/me/calendarList", token, {"maxResults": 250}))
        email = next((c["id"] for c in data if c.get("primary")), item.get("email", ""))
        return [dict(id=c["id"], name=str(c.get("summaryOverride") or c.get("summary") or "Calendar")[:120],
                     primary=c.get("primary", False)) for c in data if not c.get("deleted")], email
    token = microsoft_token(ident)
    data = pages(GRAPH + "me/calendars", token, {"$select": "id,name,isDefaultCalendar", "$top": 100}, True)
    return [dict(id=c["id"], name=str(c.get("name") or "Calendar")[:120], primary=c.get("isDefaultCalendar", False))
            for c in data], item.get("email", "")

def refresh_calendars(ident):
    with lock("credential-" + account_id(ident)):
        item = find_account(ident)
        choices, email = discover(item)
        def change(current):
            previous = {c["id"]: c["selected"] for c in current["calendars"]}
            legacy_primary = previous.get("primary") if current.get("legacy_key") else None
            for choice in choices:
                choice["selected"] = previous.get(choice["id"],
                    legacy_primary if choice.get("primary") and legacy_primary is not None else False)
            current.update(calendars=choices, email=email, error=None)
        edit_account(ident, change)

class CallbackServer(HTTPServer):
    def __init__(self):
        super().__init__(("127.0.0.1", 0), CallbackHandler)
        self.timeout = 0.5
        self.state = None
        self.result = None
        self.path = "/"

    def wait(self, state, timeout=AUTH_TIMEOUT):
        self.state = state
        deadline = time.monotonic() + timeout
        while self.result is None and time.monotonic() < deadline:
            self.handle_request()
        if self.result is None:
            raise CalendarError("timeout", "Sign-in timed out after five minutes. You can try again.")
        return self.result

class CallbackHandler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(2)

    def log_message(self, *_):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        self.respond(parsed.path, urllib.parse.parse_qs(parsed.query))

    def do_POST(self):
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            size = 0
        if not 0 < size <= 16384 or self.headers.get_content_type() != "application/x-www-form-urlencoded":
            self.respond("", {})
            return
        values = urllib.parse.parse_qs(self.rfile.read(size).decode("utf-8", "replace"))
        self.respond(urllib.parse.urlsplit(self.path).path, values)

    def respond(self, path, values):
        valid = path == self.server.path and len(values.get("state", [])) == 1
        valid = valid and bool(self.server.state) and hmac.compare_digest(values["state"][0], self.server.state)
        valid = valid and (len(values.get("code", [])) == 1 or len(values.get("error", [])) == 1)
        if valid:
            self.server.result = {k: v[0] for k, v in values.items() if len(v) == 1}
        self.send_response(200 if valid else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
        self.end_headers()
        message = "Sign-in response received. You can close this tab and return to the application." if valid else "This sign-in response could not be verified. Return to the original sign-in tab."
        title = "OniNix Calendar"
        self.wfile.write(("<!doctype html><meta name=viewport content='width=device-width'><title>" + title + "</title>"
            "<style>body{font:18px system-ui;max-width:38em;margin:12vh auto;padding:2em;color:CanvasText;background:Canvas;color-scheme:light dark}h1{font-size:26px}</style>"
            "<h1>" + title + "</h1><p>" + message + "</p>").encode())

def authorize(request, emit):
    old = find_account(request["id"]) if request.get("id") else None
    provider = old["provider"] if old else request.get("provider")
    if provider not in ("google", "microsoft"):
        raise CalendarError("invalid", "Choose Google or Microsoft 365.")
    email = str(request.get("email", old.get("email", "") if old else "")).strip()
    if email and (len(email) > 254 or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email)):
        raise CalendarError("invalid", "Enter a valid email address.")
    if not old and email and any(a["provider"] == provider and a.get("email", "").casefold() == email.casefold()
                                 for a in load_accounts()["accounts"]):
        raise CalendarError("duplicate", "This account is already connected. Use Sign in again on its account card.")
    ident = old["id"] if old else secrets.token_hex(16)
    with CallbackServer() as server:
        if provider == "google":
            from google_auth_oauthlib.flow import InstalledAppFlow
            stored = read_json(credential_path(ident), {}) if old else {}
            if stored.get("client_id") and stored.get("client_secret"):
                client = {"installed": {"client_id": stored["client_id"], "client_secret": stored["client_secret"],
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth", "token_uri": "https://oauth2.googleapis.com/token"}}
            else:
                client = google_client()
            flow = InstalledAppFlow.from_client_config(client, [GOOGLE_SCOPE], autogenerate_code_verifier=True)
            flow.redirect_uri = "http://127.0.0.1:" + str(server.server_port) + "/"
            url, state = flow.authorization_url(prompt="consent", login_hint=email or None)
            emit({"type": "browser", "url": url})
            reply = server.wait(state)
            if "error" in reply:
                raise CalendarError("declined", "Google sign-in was declined. No account was changed.")
            flow.fetch_token(code=reply["code"], timeout=TIMEOUT)
            value = json.loads(flow.credentials.to_json())
            if not value.get("refresh_token"):
                raise CalendarError("signin", "Google did not grant offline calendar access. Please try again.")
        else:
            import msal
            saved = read_json(credential_path(ident), {}) if old else {}
            app_config = microsoft_client(saved.get("app"))
            cache = msal.SerializableTokenCache()
            app = microsoft_app(app_config, cache)
            flow = app.initiate_auth_code_flow(MICROSOFT_SCOPES,
                redirect_uri="http://localhost:" + str(server.server_port) + "/",
                login_hint=email or None, prompt="select_account", response_mode="form_post")
            emit({"type": "browser", "url": flow["auth_uri"]})
            reply = server.wait(flow["state"])
            result = microsoft_result(app.acquire_token_by_auth_code_flow(flow, reply))
            email = result.get("id_token_claims", {}).get("preferred_username", email)
            match = app.get_accounts()
            if len(match) != 1:
                raise CalendarError("signin", "Microsoft did not return an unambiguous account. Please try again.")
            value = {"app": app_config, "cache": cache.serialize(), "home_account_id": match[0]["home_account_id"]}
    with lock("credential-" + ident):
        if old:
            find_account(ident)
        private_dir(CONFIG / "credentials")
        write_json(credential_path(ident), value)
        if old:
            edit_account(ident, lambda item: item.update(email=email, error=None))
        else:
            with lock("accounts"):
                data = read_json(ACCOUNTS)
                data["accounts"].append(dict(id=ident, provider=provider, label=email or "Google", email=email,
                    enabled=True, calendars=[], error=None))
                write_json(ACCOUNTS, data)
    try:
        refresh_calendars(ident)
        if not old:
            edit_account(ident, lambda item: [c.update(selected=c.get("primary", False)) for c in item["calendars"]])
    except Exception as exc:
        error = safe_error(exc)
        edit_account(ident, lambda item: item.update(error=error))
        raise
    return ident

JOIN_HOSTS = ("teams.microsoft.com", "teams.live.com", "meet.google.com", "zoom.us", "webex.com")
JOIN_URL = re.compile(r"""https://[^\s<>"'\\]+""", re.I)

def with_join(event, *texts):
    for text in texts:
        for candidate in JOIN_URL.findall(html.unescape(str(text or ""))):
            url = candidate.rstrip(".,;)")
            address = feed_address(url)
            if address is None or len(url) > 1000:
                continue
            host = address.hostname
            if re.fullmatch(r"[a-z0-9.-]+", host) and any(host == suffix or host.endswith("." + suffix)
                                                        for suffix in JOIN_HOSTS):
                event.update(j=url, m=True)
                return event
    return event

def normalized_google(events, key, tz):
    result = []
    for ev in events:
        if ev.get("status") == "cancelled" or any(a.get("self") and a.get("responseStatus") == "declined" for a in ev.get("attendees", [])):
            continue
        start, end = ev.get("start", {}), ev.get("end", {})
        allday = "date" in start
        def parse(value):
            dt = datetime.fromisoformat(value["date"] if allday else value["dateTime"])
            return (dt.replace(tzinfo=tz) if dt.tzinfo is None else dt.astimezone(tz)).isoformat()
        others = [a for a in ev.get("attendees", []) if not a.get("self") and not a.get("resource")]
        conference = ev.get("conferenceData") or {}
        video = [point.get("uri") for point in conference.get("entryPoints", []) if point.get("entryPointType") == "video"]
        call = bool(ev.get("hangoutLink") or conference or others)
        place = ev.get("location")
        event = with_place(dict(s=parse(start), e=parse(end or start), t=str(ev.get("summary") or "(no title)")[:160],
                                c=key, a=allday, m=call), place)
        result.append(with_join(event, ev.get("hangoutLink"), *video, place, ev.get("description")))
    return result

def normalized_microsoft(events, key, tz):
    result = []
    for ev in events:
        if ev.get("isCancelled") or ev.get("responseStatus", {}).get("response") == "declined":
            continue
        allday = ev.get("isAllDay", False)
        def parse(value):
            dt = datetime.fromisoformat(value["dateTime"])
            if dt.tzinfo is None:
                if value.get("timeZone", "UTC") not in ("UTC", "Etc/UTC"):
                    raise CalendarError("response", "Microsoft returned an unexpected event time zone.")
                dt = dt.replace(tzinfo=timezone.utc)
            if allday:
                from babel.core import get_global
                zone = ev.get("originalStartTimeZone") or "UTC"
                zone = get_global("windows_zone_mapping").get(zone, zone)
                day = dt.astimezone(ZoneInfo(zone)).date()
                return datetime.combine(day, datetime.min.time(), tz).isoformat()
            return dt.astimezone(tz).isoformat()
        place = (ev.get("location") or {}).get("displayName")
        call = bool(ev.get("isOnlineMeeting") or ev.get("attendees"))
        event = with_place(dict(s=parse(ev["start"]), e=parse(ev["end"]), t=str(ev.get("subject") or "(no title)")[:160],
                                c=key, a=allday, m=call), place)
        result.append(with_join(event, (ev.get("onlineMeeting") or {}).get("joinUrl"), place))
    return result

def feed_address(url):
    try:
        parsed = urllib.parse.urlsplit(url)
        parsed.port
    except ValueError:
        return None
    if not parsed.hostname or parsed.username is not None or parsed.password is not None or len(url) > 4096:
        return None
    if parsed.scheme == "https" or (parsed.scheme == "http" and parsed.hostname in {"localhost", "127.0.0.1", "::1"}):
        return parsed
    return None

class FeedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        next_address = feed_address(newurl)
        if next_address is None or (req.type == "https" and next_address.scheme != "https"):
            raise CalendarError("feed", "The calendar feed redirected to an insecure address.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def source_ics(key, url, start, end):
    from icalendar import Calendar
    import recurring_ical_events

    if feed_address(url) is None:
        raise CalendarError("feed", "Calendar feeds require HTTPS or a local HTTP address.")
    req = urllib.request.Request(url, headers={"User-Agent": "OniNix Calendar"})
    limit = 8 * 1024 * 1024
    with urllib.request.build_opener(FeedRedirect).open(req, timeout=TIMEOUT) as response:
        body = response.read(limit + 1)
    if len(body) > limit:
        raise CalendarError("feed", "The calendar feed exceeds the 8 MiB limit.")

    def local(value):
        if not isinstance(value, datetime):
            return datetime.combine(value, wall_time.min, start.tzinfo)
        return value.replace(tzinfo=start.tzinfo) if value.tzinfo is None else value.astimezone(start.tzinfo)

    result = []
    for event in recurring_ical_events.of(Calendar.from_ical(body)).between(start, end):
        if event.get("STATUS") == "CANCELLED" or "DTSTART" not in event:
            continue
        raw_start = event.decoded("DTSTART")
        raw_end = event.decoded("DTEND", raw_start)
        place = event.get("LOCATION")
        row = with_place(dict(
            s=local(raw_start).isoformat(), e=local(raw_end).isoformat(),
            t=str(event.get("SUMMARY") or "(no title)")[:160], c=key,
            a=not isinstance(raw_start, datetime), m=bool(event.get("CONFERENCE") or event.get("ATTENDEE")),
        ), place)
        result.append(with_join(row, event.get("CONFERENCE"), event.get("URL"), place, event.get("DESCRIPTION")))
    return result

def sync():
    try:
        with open("/etc/localtime", "rb") as localtime:
            tz = ZoneInfo.from_file(localtime)
    except (OSError, ValueError):
        tz = timezone.utc
    now = datetime.now(tz)
    start = datetime.combine(now.date() - timedelta(days=62), wall_time.min, tz)
    end = datetime.combine(now.date() + timedelta(days=100), wall_time.min, tz)
    with lock("sync"):
        events, status = collect_sources(start, end, tz, source_ics)
        events.sort(key=lambda event: datetime.fromisoformat(event["s"]))
        publish({"ts": time.time(), "events": events, "cals": status})

def collect_sources(start, end, tz, source_ics):
    events, status = [], {}
    for entry in load_accounts()["accounts"]:
        ident = entry["id"]
        with lock("credential-" + ident):
            try:
                item = find_account(ident)
            except CalendarError:
                continue
            if not item.get("enabled", True):
                continue
            token, token_error = None, None
            selected = [c for c in item["calendars"] if c["selected"]]
            try:
                if selected and item["provider"] == "google":
                    token = google_credentials(ident).token
                elif selected and item["provider"] == "microsoft":
                    token = microsoft_token(ident)
            except Exception as exc:
                token_error = exc
            for calendar in selected:
                cid = calendar["id"]
                key = ident + ":" + cid
                cached = event_path(ident, cid)
                previous = read_cache(cached, {})
                try:
                    if token_error:
                        raise token_error
                    if item["provider"] == "ics":
                        found = source_ics(key, read_json(credential_path(ident))["url"], start, end)
                    elif item["provider"] == "google":
                        data = pages("https://www.googleapis.com/calendar/v3/calendars/" + urllib.parse.quote(cid, safe="") + "/events", token,
                            {"timeMin": start.isoformat(), "timeMax": end.isoformat(), "singleEvents": "true", "orderBy": "startTime", "maxResults": 2500})
                        found = normalized_google(data, key, tz)
                    else:
                        data = pages(GRAPH + "me/calendars/" + urllib.parse.quote(cid, safe="") + "/calendarView", token,
                            {"startDateTime": start.isoformat(), "endDateTime": end.isoformat(), "$top": 1000,
                             "$select": "subject,start,end,isAllDay,isCancelled,responseStatus,originalStartTimeZone,isOnlineMeeting,onlineMeeting,attendees,location"}, True)
                        found = normalized_microsoft(data, key, tz)
                    previous = {"ts": time.time(), "events": found}
                    write_json(cached, previous)
                    state = {"ok": True, "n": len(found), "ts": previous["ts"]}
                except Exception as exc:
                    found = previous if isinstance(previous, list) else previous.get("events", [])
                    error = safe_error(exc)
                    state = {"ok": False, "err": error["message"], "code": error["code"],
                             "ts": previous.get("ts", 0) if isinstance(previous, dict) else 0}
                state.update(account=ident, calendar=cid, name=calendar["name"], provider=item["provider"], kind=item.get("legacy_key", item["provider"]))
                status[key] = state
                for ev in found:
                    events.append(dict(ev, c=key, cn=calendar["name"], kind=item.get("legacy_key", item["provider"]), account=ident))
    return events, status

def publish(collected=None):
    with lock("publish"):
        if collected is None:
            collected = read_cache(CACHE / "caldash.json", {})
        if not collected:
            return
        data = load_accounts()
        active = {a["id"] + ":" + c["id"] for a in data["accounts"] if a.get("enabled", True)
                  for c in a["calendars"] if c["selected"]}
        collected["events"] = [e for e in collected.get("events", []) if e.get("c") in active]
        collected["cals"] = {k: v for k, v in collected.get("cals", {}).items() if k in active}
        for value in collected.get("days", {}).values():
            if "e" in value:
                value["e"] = [key for key in value["e"] if key in active]
        collected["configured"] = bool(data["accounts"])
        write_json(CACHE / "caldash.json", collected)

def snapshot():
    data = load_accounts()
    collected = read_cache(CACHE / "caldash.json", {})
    states = collected.get("cals", {})
    rows = []
    for entry in data["accounts"]:
        item = dict(entry)
        item["calendars"] = [dict(c, sync=states.get(entry["id"] + ":" + c["id"], {})) for c in entry["calendars"]]
        item["connected"] = bool(read_json(credential_path(item["id"]), {}))
        rows.append(item)
    providers = {}
    for provider, fn in (("google", google_client), ("microsoft", microsoft_client)):
        try:
            fn()
            providers[provider] = True
        except (CalendarError, ValueError, OSError):
            providers[provider] = False
    return {"accounts": rows, "providers": providers, "ts": collected.get("ts", 0)}

def handle(request, emit=lambda value: None):
    load_accounts()
    operation = request.get("op", "status")
    if operation == "status":
        return snapshot()
    if operation == "setup":
        if request.get("provider") == "google":
            write_json(CONFIG / "client.json", google_client(request.get("path")))
        elif request.get("provider") == "microsoft":
            write_json(CONFIG / "microsoft.json", microsoft_client(request))
        else:
            raise CalendarError("invalid", "Unknown calendar provider.")
    elif operation == "connect":
        authorize(request, emit)
    elif operation == "discover":
        ident = account_id(request.get("id"))
        try:
            refresh_calendars(ident)
        except Exception as exc:
            error = safe_error(exc)
            edit_account(ident, lambda item: item.update(error=error))
            raise
    elif operation == "select":
        def select(item):
            ids = request.get("calendars")
            if not isinstance(ids, list) or not all(isinstance(c, str) for c in ids) or not set(ids) <= {c["id"] for c in item["calendars"]}:
                raise CalendarError("invalid", "Refresh the calendar list before choosing calendars.")
            for calendar in item["calendars"]:
                calendar["selected"] = calendar["id"] in ids
        edit_account(request.get("id"), select)
    elif operation == "enable":
        if not isinstance(request.get("enabled"), bool):
            raise CalendarError("invalid", "Invalid account switch.")
        edit_account(request.get("id"), lambda item: item.update(enabled=request["enabled"]))
    elif operation == "remove":
        ident = account_id(request.get("id"))
        with lock("credential-" + ident):
            find_account(ident)
            with lock("accounts"):
                data = read_json(ACCOUNTS)
                data["accounts"] = [a for a in data["accounts"] if a["id"] != ident]
                write_json(ACCOUNTS, data)
            credential_path(ident).unlink(missing_ok=True)
            for path in CACHE.glob("caldash-" + ident + "-*.events.json"):
                path.unlink(missing_ok=True)
    elif operation == "feed":
        url = str(request.get("url", "")).strip()
        label = str(request.get("label", "")).strip()[:120]
        if not label or feed_address(url) is None:
            raise CalendarError("invalid", "Enter a name and an HTTPS or local HTTP iCalendar subscription URL.")
        ident = secrets.token_hex(16)
        private_dir(CONFIG / "credentials")
        write_json(credential_path(ident), {"url": url})
        with lock("accounts"):
            data = read_json(ACCOUNTS)
            data["accounts"].append(dict(id=ident, provider="ics", label=label, email="", enabled=True,
                calendars=[dict(id="feed", name=label, selected=True)]))
            write_json(ACCOUNTS, data)
    elif operation != "sync":
        raise CalendarError("invalid", "Unknown calendar action.")
    if operation in ("select", "enable", "remove"):
        publish()
    return snapshot()
