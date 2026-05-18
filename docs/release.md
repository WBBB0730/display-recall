# Release Guide

Display Recall is distributed outside the Mac App Store through GitHub Releases.

## Backend

Release packages include a bundled displayplacer backend for supported architectures:

- Apple Silicon: `displayplacer-apple-v140`
- Intel: `displayplacer-intel-v140`

The app chooses the matching bundled backend at runtime. This keeps first-run setup simple and avoids requiring Homebrew. A system or custom backend path remains available as an advanced fallback for users who need to test a different `displayplacer` binary.

## Packaging

Use `scripts/package-release.sh` for release packaging. The current release package is an unsigned DMG that does not require an Apple Developer Program membership, Developer ID certificate, or notarization credentials.

1. Builds the app as Universal 2.
2. Verifies `arm64` and `x86_64` slices.
3. Creates an unsigned DMG with `sindresorhus/create-dmg`.
4. Optionally generates a Sparkle appcast when `SPARKLE_GENERATE_APPCAST` is set.

Because the DMG is not signed with Developer ID and not notarized, macOS Gatekeeper may require users to confirm that they want to open the app. A future signed release channel can add Developer ID signing, notarization, and stapling when the project has Apple Developer Program credentials.

## GitHub Releases

Pushing a tag named `vX.Y.Z` starts the release workflow. The workflow packages the unsigned DMG, then publishes it to the matching GitHub Release.

The unsigned workflow does not require repository secrets.

The tag version is passed to the packaging scripts as the app version, so `v1.2.3` produces a `1.2.3` release artifact.

## Version Bumps

Use `scripts/bump-version.swift` to update the app version before a release. The script is interactive by default, similar to `bumpp`: it reads the current version, shows stable and beta candidates, asks for confirmation, updates version references, and can create a git commit and tag.

Release tags use these formats:

- Stable: `vX.Y.Z`
- Beta: `vX.Y.Z-beta.N`

Examples:

```sh
scripts/bump-version.swift
scripts/bump-version.swift patch --commit --tag
scripts/bump-version.swift beta --commit --tag
scripts/bump-version.swift 1.2.3-beta.1 --commit --tag
```

The script does not push commits or tags automatically. Push the selected release tag when you want GitHub Actions to publish it.

## Sparkle

Sparkle update metadata uses the stable channel. Updates are user-confirmed and never silently forced. Appcast generation is optional for the unsigned release flow.

## No Mac App Store Assumptions

Display Recall does not rely on Mac App Store receipts, sandbox receipt checks, or StoreKit distribution flows.
