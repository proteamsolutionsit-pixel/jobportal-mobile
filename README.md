# JobPortal — JobSeeker mobile app

Flutter app for Android and iOS. A **second client** of the same API the web
application uses, built for the JobSeeker role.

The web application at `../jobportal-python/` is the functional source of truth.
`../jobportal-python/CLAUDE.md` is authoritative for the server; `../CLAUDE.md`
governs the ecosystem; `../docs/` carries the analysis and decisions.

---

## Running it

`flutter` is not on PATH on the development machine — it lives at
`D:\flutter\bin`.

```bash
# 1. the API must be up. From ../jobportal-python:
#    MariaDB on port 3308 (NOT a Windows service — start it by hand)
#    cd backend && .venv/Scripts/python.exe -m uvicorn app.main:app \
#        --host 127.0.0.1 --port 8000

# 2. the app
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

On an **Android emulator** the host is `10.0.2.2`, not `127.0.0.1`:

```bash
flutter run --dart-define=APP_ENV=development \
            --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Configuration is compile-time (`--dart-define`), never a bundled `.env` — see
`.env.example` for why, and for the staging and production commands.

## Verifying

```bash
flutter analyze     # must be clean
flutter test        # 180 tests, headless, no device needed
```

On-device, with an emulator or handset attached:

```bash
flutter test integration_test/app_test.dart --dart-define=...
```

---

## Layout

```
lib/
├── core/
│   ├── config/       environment; refuses http outside dev, refuses www.
│   ├── constants/    the 17 controlled vocabularies, copied from the server
│   ├── errors/       one ApiException; 422 → field errors keyed by `loc`
│   ├── network/      Dio + persisted cookie jar + the CSRF interceptor
│   ├── storage/      cookie jar over Keystore / Keychain
│   ├── theme/        the palette and type scale from the web stylesheet
│   ├── utils/        format.dart — the single UTC parse, and the money/date copy
│   └── widgets/      states, chips, cards, autosuggest
├── data/
│   ├── models/       strict wire types (wire.dart explains "strict")
│   └── repositories/ auth, jobs, seeker
├── domain/           reserved; the repositories are thin enough not to need it yet
├── features/jobseeker/
│   ├── authentication/  register, password login, emailed-code login, reset
│   ├── home/            curated rail + completeness prompt
│   ├── jobs/            search, filters, detail, apply
│   ├── applications/    history and withdrawal
│   ├── saved_jobs/
│   ├── profile/         sections, history, skills, links, CV
│   ├── notifications/
│   └── settings/        alerts, notification prefs, sign-out, delete
├── routing/          router, shell, splash
└── main.dart
```

---

## The rules this code follows

Each one exists because the web build paid for it. Full detail in `../docs/`.

1. **The session is a cookie, not a bearer token.** `hh_token` (httpOnly) plus
   `hh_csrf`, which is echoed in `X-CSRF-Token` on every unsafe verb — omit it
   and every write is a **403**. No backend change was needed. `../docs/decisions.md` D-001.
2. **Models are strict.** One declared shape, throw on mismatch. No
   `json['x'] ?? json['data']?['x']` — a client that accepts two shapes hides a
   server sending the wrong one, and that cost the web build four screens.
3. **Bare timestamps are UTC.** Everything goes through `parseStamp`;
   `DateTime.parse` would read them as local and be wrong, silently.
4. **Money is a `String` out and a number in.** `min_salary`, `max_salary`,
   `current_ctc`, `expected_ctc`.
5. **Read `total`, never `items.length`** — and when `total_capped` is true,
   render "500+".
6. **`hide_salary` is informational.** The server already blanked the figures.
7. **A resume is never cached to disk.** Photos and logos cache normally.
8. **Withdrawing is permanent** and the dialog says so.
9. **Autosuggest never swallows submit** — a suggestion list is not a whitelist.
10. **A notification `link` becomes a route, never a URL.**
11. **`/login-code` gets one message for every outcome** — registered,
    unregistered, malformed, throttled or over-cap. Branching on it would
    rebuild an enumeration oracle the server closed after a measured leak.
12. **Mobile number verification is not built.** The owner deferred it.

---

## Not done here

- **No Android or iOS build has been produced.** The development machine has no
  Android SDK, and iOS requires macOS. `flutter analyze` and `flutter test`
  both pass; platform integration — Keystore/Keychain, file picking,
  permissions, signing — is untested by definition until a build runs.
- **No push notifications.** `/api/notifications` is in-app and email only;
  FCM/APNs needs a backend half (task MOB-B-004).
- **No Google sign-in** — blocked on the owner for a client id and secret.
- **Resume builder and the assistant** are deferred (MOB-F-090, MOB-F-091).
