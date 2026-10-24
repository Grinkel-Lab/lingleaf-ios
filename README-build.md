# Build Lingleaf iOS without a Mac

This repository has a GitHub Actions workflow that builds Lingleaf on a hosted macOS runner.

## Run the build
1. Open the repository's Actions tab.
2. Select **Build unsigned IPA**.
3. Tap **Run workflow** on the `main` branch.
4. When it completes, open the run and download the `lingleaf-unsigned-ios` artifact.

## Important: installation
The workflow creates an **unsigned** IPA. iOS does not install unsigned apps directly. To install it, you must sign it with a development signing identity and provisioning profile, or use a compatible sideloading tool with your own Apple ID. Free Apple ID sideloading usually requires refreshing the signature periodically and the app may stop launching if not refreshed.

Do not upload Apple certificates, private keys, or passwords to this repository. If later setting up signing in CI, use GitHub Actions secrets and follow Apple's official signing requirements.

Lingleaf uses Apple Translation on-device; translation needs a real iPhone and downloaded language resources. The simulator is not a substitute for that functionality.
