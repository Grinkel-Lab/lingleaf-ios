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
   generate a team key with the **App Manager** role (the least role that can sign with
   cloud-managed certificates and upload; never Admin). Download the `.p8` file (only once)
   and note the **Key ID** and **Issuer ID**. If the key leaks or is no longer needed,
   **revoke** it on the same page and replace the `ASC_KEY_P8` / `ASC_KEY_ID` secrets.
4. **Team ID**: developer.apple.com → Account → Membership details.
5. **GitHub → Settings → Environments → New environment `testflight`**:
   - **Required reviewers**: add yourself (mandatory). Every upload waits for your approval.
   - **Deployment branches and tags**: *Selected branches and tags* → add `main` only.
   - Add these environment secrets (paste values directly in GitHub, never in chats or issues):
   - `ASC_KEY_ID`: the Key ID
   - `ASC_ISSUER_ID`: the Issuer ID
   - `ASC_KEY_P8`: the whole contents of the `.p8` file, including the BEGIN/END lines
   - `APPLE_TEAM_ID`: the Team ID

## Each upload

1. Actions → TestFlight → Run workflow (branch `main`; any other branch is skipped), then approve the deployment.
2. The build number is the workflow run number; the version is `MARKETING_VERSION` in
   `project.yml`.
3. After Apple processes the build (5–30 min) it appears in App Store Connect →
   TestFlight. Internal testers (up to 100 people on your team) can install it at once.
   External testers (up to 10,000, by email or public link) need Beta App Review first.

## App Store Connect answers

- **Export compliance**: answered in the app (`ITSAppUsesNonExemptEncryption = NO`):
  only HTTPS and on-device translation.
- **Privacy policy URL**: https://github.com/erobinsonc/lingleaf-ios/blob/main/PRIVACY.md
- **App privacy**: until in-app suggestions ship on iOS, declare **No data collected**
  (it matches `PrivacyInfo.xcprivacy`). Once they ship, declare *User Content* (other user content,
  photos) and *Diagnostics* (other diagnostic data), collected **only when the user sends
  them**, **not linked** to identity, **not used for tracking**. Without that feature: no
  data collected.
- **Age rating**: no objectionable content; 4+.
