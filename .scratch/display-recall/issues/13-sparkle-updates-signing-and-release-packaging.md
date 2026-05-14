Status: ready-for-agent

# Sparkle Updates Signing And Release Packaging

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Prepare the app for direct distribution outside the Mac App Store. Release builds should be Universal 2, signed, notarized, packaged for GitHub Releases, and updateable through Sparkle stable channel with user-confirmed installation.

## Acceptance criteria

- [ ] Release builds are Universal 2.
- [ ] Release builds are Developer ID signed.
- [ ] Release builds are notarized.
- [ ] The packaged app includes the verified bundled backend for supported architectures.
- [ ] Sparkle is integrated for manual update checks.
- [ ] Sparkle supports optional automatic checks without silent forced installation.
- [ ] Update packages are signed according to Sparkle requirements.
- [ ] The app exposes version/build number in About.
- [ ] GitHub Release packaging produces a user-installable artifact.
- [ ] Mac App Store-specific assumptions are not introduced.

## Blocked by

- `02-bundle-and-verify-displayplacer-backend.md`
