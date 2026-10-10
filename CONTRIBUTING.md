# Contributing

Thanks for helping! Code, graded stories, translations of the interface and bug reports are all welcome.

1. Fork and branch: `git checkout -b feat/my-change`.
2. Run the checks before opening a pull request:
   ```bash
   swift test --package-path LingleafCore
   swiftlint lint
   xcodegen generate && xcodebuild test -project Lingleaf.xcodeproj -scheme Lingleaf -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
3. Behaviour changes update [SPEC.md](SPEC.md) here **and** in
   [lingleaf-android](https://github.com/erobinsonc/lingleaf-android), so both apps stay in sync.
4. Every user-facing string is translated in `Lingleaf/Resources/Localizable.xcstrings` (English and Spanish).
5. Open the pull request. CI must be green before merging.

## Principles

- Same behaviour on iOS and Android.
- No analytics, ads or tracking. Any new network host is documented in the README.
- Accessible by default: Dynamic Type, VoiceOver labels, the accessibility audit passes.
