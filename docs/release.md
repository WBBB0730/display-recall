# Release Guide

Display Recall is distributed outside the Mac App Store through GitHub Releases.

## Backend

Release packages include a bundled displayplacer backend for supported architectures:

- Apple Silicon: `displayplacer-apple-v140`
- Intel: `displayplacer-intel-v140`

The app chooses the matching bundled backend at runtime. This keeps first-run setup simple and avoids requiring Homebrew. A system or custom backend path remains available as an advanced fallback for users who need to test a different `displayplacer` binary.

## Packaging

Use `scripts/package-release.sh` for release packaging. The script expects Developer ID and Apple notarization credentials in environment variables, then:

1. Builds the app as Universal 2.
2. Verifies `arm64` and `x86_64` slices.
3. Signs the app with Developer ID and hardened runtime.
4. Creates a DMG with `sindresorhus/create-dmg`.
5. Submits the DMG for notarization.
6. Staples the notarization ticket to the DMG.
7. Optionally generates a Sparkle appcast when `SPARKLE_GENERATE_APPCAST` is set.

## GitHub Releases

Pushing a tag named `vX.Y.Z` starts the production release workflow. The workflow packages the signed and notarized DMG, then publishes it to the matching GitHub Release.

The workflow requires these repository secrets:

- `DEVELOPER_ID_APPLICATION`
- `DEVELOPER_ID_CERTIFICATE_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `SPARKLE_PUBLIC_ED_KEY`

The tag version is passed to the packaging scripts as the app version, so `v1.2.3` produces a `1.2.3` release artifact.

## Sparkle

Sparkle update metadata uses the stable channel. Updates are user-confirmed and never silently forced. Release artifacts must be signed according to Sparkle's EdDSA update signing requirements before publication.

## No Mac App Store Assumptions

Display Recall does not rely on Mac App Store receipts, sandbox receipt checks, or StoreKit distribution flows.
