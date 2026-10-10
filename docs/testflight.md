# Publishing to TestFlight

The `TestFlight` workflow (`.github/workflows/testflight.yml`) archives a signed Release
build on a GitHub macOS runner and uploads it to App Store Connect. No Mac is needed.
It runs only by hand (Actions → TestFlight → Run workflow), normally on `main`.

## One-time setup (maintainer)

1. **Apple Developer Program**: enrol as an individual (developer.apple.com/programs/enroll).
2. **App Store Connect → Apps → +**: New App, platform iOS, name "Lingleaf",
   primary language English, bundle ID `app.lingleaf` (register it if it isn't listed),
   SKU `lingleaf-ios`.
3. **App Store Connect → Users and Access → Integrations → App Store Connect API**:
   generate a team key with the **App Manager** role. Download the `.p8` file (only once)
   and note the **Key ID** and **Issuer ID**.
4. **Team ID**: developer.apple.com → Account → Membership details.
5. **GitHub → Settings → Environments → New environment `testflight`**. Optionally add
   yourself as a required reviewer, so every upload needs your approval. Add these
   environment secrets (paste values directly in GitHub, never in chats or issues):
   - `ASC_KEY_ID`: the Key ID
   - `ASC_ISSUER_ID`: the Issuer ID
   - `ASC_KEY_P8`: the whole contents of the `.p8` file, including the BEGIN/END lines
   - `APPLE_TEAM_ID`: the Team ID

## Each upload

1. Actions → TestFlight → Run workflow (branch `main`).
2. The build number is the workflow run number; the version is `MARKETING_VERSION` in
   `project.yml`.
3. After Apple processes the build (5–30 min) it appears in App Store Connect →
   TestFlight. Internal testers (up to 100 people on your team) can install it at once.
   External testers (up to 10,000, by email or public link) need Beta App Review first.

## App Store Connect answers

- **Export compliance**: answered in the app (`ITSAppUsesNonExemptEncryption = NO`):
  only HTTPS and on-device translation.
- **Privacy policy URL**: https://github.com/erobinsonc/lingleaf-ios/blob/main/PRIVACY.md
- **App privacy**: with in-app suggestions, declare *User Content* (other user content,
  photos) and *Diagnostics* (other diagnostic data), collected **only when the user sends
  them**, **not linked** to identity, **not used for tracking**. Without that feature: no
  data collected.
- **Age rating**: no objectionable content; 4+.
