# iOS: from git to your Apple Developer account

Everything needed to make `.github/workflows/release-ios.yml` build a signed IPA and put it
on TestFlight.

**You do steps 1–6. I cannot, and should not** — they create credentials tied to your Apple
account. Never paste a `.p12`, a `.p8`, or any password into a chat.

A **Mac is needed once**, for step 3 (exporting the certificate). Everything after that runs
on GitHub's macOS runners. If you have no Mac at all, see "No Mac?" at the end.

---

## 1. Register the Bundle ID

[developer.apple.com](https://developer.apple.com/account) → Certificates, IDs & Profiles →
**Identifiers** → **+**

- Type: **App IDs** → **App**
- Description: `JobPortal JobSeeker`
- Bundle ID: **Explicit** → `com.jobsflood.jobportalMobile`

> ⚠️ That capitalisation is exact — it is what
> `ios/Runner.xcodeproj/project.pbxproj` already contains. A mismatch here fails at codesign
> with a message that does not mention the bundle ID.

**Capabilities:** leave everything off. The app uses none — no push, no sign-in-with-Apple,
no iCloud. Enabling one you do not use means a profile that stops matching later.

## 2. Create the app record in App Store Connect

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App

- Platform **iOS**, Bundle ID as above
- SKU: anything unique, e.g. `jobportal-seeker`
- Name: what appears on the store

Without this record TestFlight has nowhere to put the build, and the upload fails at the very
end of a 20-minute job.

## 3. Distribution certificate → `.p12` *(needs a Mac)*

Identifiers → **Certificates** → **+** → **Apple Distribution**.

1. On the Mac: **Keychain Access → Certificate Assistant → Request a Certificate From a
   Certificate Authority**, save to disk. Upload that CSR.
2. Download the `.cer`, double-click to install.
3. In Keychain Access, **My Certificates**, right-click *Apple Distribution: …* → **Export** →
   `.p12`. **Set a password** — you will need it as a secret.

```bash
base64 -i Certificates.p12 | pbcopy      # → IOS_CERTIFICATE_BASE64
```

## 4. Provisioning profile → `.mobileprovision`

Identifiers → **Profiles** → **+** → **Distribution → App Store Connect**

- App ID: the one from step 1
- Certificate: the one from step 3
- Download it.

```bash
base64 -i JobPortal_AppStore.mobileprovision | pbcopy    # → IOS_PROVISIONING_PROFILE_BASE64
```

> Profiles **expire after a year**. When TestFlight uploads suddenly fail, this is the first
> thing to check.

## 5. App Store Connect API key → `.p8`

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **+**

- Access: **App Manager**
- Download the `.p8`. **It downloads exactly once.**
- Note the **Key ID** and the **Issuer ID** shown on that page.

An API key rather than an app-specific password: it is revocable on its own, scoped to what it
needs, and is not tied to a person's Apple ID — so it survives someone leaving.

## 6. Your Team ID

Developer portal → **Membership**. Ten characters, e.g. `A1B2C3D4E5`.

---

## 7. Add the secrets

GitHub → the repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret | From |
|---|---|
| `IOS_CERTIFICATE_BASE64` | step 3 |
| `IOS_CERTIFICATE_PASSWORD` | the password you set in step 3 |
| `IOS_PROVISIONING_PROFILE_BASE64` | step 4 |
| `IOS_TEAM_ID` | step 6 |
| `APPSTORE_KEY_ID` | step 5 |
| `APPSTORE_ISSUER_ID` | step 5 |
| `APPSTORE_PRIVATE_KEY` | contents of the `.p8`, **including** the `-----BEGIN…` and `-----END…` lines |

The first four build a signed IPA. The last three upload it. **Add the first four alone and
the workflow still works** — it produces a signed IPA as an artefact and skips the upload.

---

## 8. Run it

**Actions → release-ios → Run workflow.** Choose `production` or `staging`, and whether to
upload.

Or push a tag:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Takes 20–40 minutes. The build appears in App Store Connect → TestFlight, then sits in
"Processing" for 10–30 minutes before it is installable.

---

## What the workflow does with your credentials

- Writes them to a **throwaway keychain** with a random password, on an **ephemeral runner**.
- `security set-key-partition-list` so `codesign` does not open a prompt — on a headless
  runner that prompt would simply hang until the job times out.
- **Manual signing**, not automatic: automatic needs an interactive Xcode session to talk to
  Apple, which CI does not have.
- **Deletes the keychain, the profile and the `.p8` in an `always()` step**, so they go even
  when the build fails.
- Checks all four signing secrets **before** building, so a missing one fails in seconds
  rather than 20 minutes in, inside codesign, with something inscrutable.

Nothing is written to the repository. `.gitignore` already covers `*.p12`, `*.p8`,
`*.mobileprovision` and `key.properties`.

---

## Before your first submission

The build will upload without these; **App Review will reject it**:

- [ ] **Purpose strings** in `ios/Runner/Info.plist` — `NSCameraUsageDescription` and
      `NSPhotoLibraryUsageDescription`. The app picks a profile photo and a CV, so both are
      needed. Say *why*: "JobPortal uses your camera to take a profile photograph." A generic
      string is itself a rejection reason.
- [ ] **App icon.** Source is `assets/images/app-icon.png`.
- [ ] **Privacy policy URL** — mandatory, and this app collects personal data.
- [ ] **Privacy nutrition labels** in App Store Connect. Be accurate: contact info,
      employment history, and the CV are all collected.
- [ ] **A demo account** for the reviewer. The app is sign-in-only past the job listing, and a
      reviewer who cannot get in rejects it.
- [ ] **Screenshots** at the required sizes.
- [ ] Decide the **display name** — currently "Jobportal Mobile", which reads like a
      placeholder.

## Known gotchas

| | |
|---|---|
| **Four features fail against production** | Email-code sign-in, autosuggest, India locations, job benefits. Their endpoints are in the web working tree and **not deployed**. Build `staging` for TestFlight until they ship, or a reviewer will hit a broken sign-in. |
| **Session is 12 hours, no refresh** | Not a rejection risk, but testers will be signed out daily. |
| **Bundle ID capitalisation** | `com.jobsflood.jobportalMobile` — the `M` is capital. |
| **Version bumps** | App Store Connect refuses a build number it has seen. Bump `version:` in `pubspec.yaml` (`1.0.0+2`) every upload. |
| **`CODE_SIGN_STYLE` is `Automatic` in the project** | The workflow overrides it via `ExportOptions.plist`, so the checked-in value does not matter for CI. If you ever build from Xcode on a Mac, set your team there. |

## No Mac?

Step 3 needs one, once, to export the `.p12`. Options:

- Borrow one for twenty minutes.
- A cloud Mac (MacStadium, Scaleway) for an hour.
- Generate the CSR with OpenSSL on any machine and build the `.p12` yourself:

```bash
openssl genrsa -out ios_distribution.key 2048
openssl req -new -key ios_distribution.key -out CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=you@example.com, CN=Your Name, C=IN"
# upload the CSR to Apple, download distribution.cer, then:
openssl x509 -inform DER -in distribution.cer -out distribution.pem -outform PEM
openssl pkcs12 -export -inkey ios_distribution.key -in distribution.pem -out Certificates.p12
```

That last command asks for an export password — that is `IOS_CERTIFICATE_PASSWORD`.
