Status: ready-for-agent

# Sparkle Updates Signing And Release Packaging

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Prepare the app for direct distribution outside the Mac App Store. Release builds should be Universal 2, signed, notarized, packaged for GitHub Releases, and updateable through Sparkle stable channel with user-confirmed installation.

## Acceptance criteria

- [x] Release builds are Universal 2.
- [x] Release builds are Developer ID signed.
- [x] Release builds are notarized.
- [x] The packaged app includes the verified bundled backend for supported architectures.
- [x] Sparkle is integrated for manual update checks.
- [x] Sparkle supports optional automatic checks without silent forced installation.
- [x] Update packages are signed according to Sparkle requirements.
- [x] The app exposes version/build number in About.
- [x] GitHub Release packaging produces a user-installable artifact.
- [x] Mac App Store-specific assumptions are not introduced.

## Blocked by

- `02-bundle-and-verify-displayplacer-backend.md`
