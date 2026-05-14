# Display Recall

Display Recall is a native macOS menu bar companion for `displayplacer`.

It saves display layouts as profiles, switches them from the menu bar, and can automatically apply a chosen profile after display changes or login startup. It is an independent companion app, not an official `displayplacer` app or replacement.

## Current Scope

- Native Swift/SwiftUI macOS app targeting macOS 13 and newer.
- Bundled `displayplacer` backend for Apple Silicon and Intel Macs.
- Profiles window for saving, editing, applying, importing, and exporting layouts.
- Menu bar quick switching and automatic apply with a stoppable countdown.
- Activity Log and diagnostic export.
- English and Simplified Chinese UI resources.
- Direct distribution preparation for signed and notarized GitHub Releases.

## Backend Behavior

Display Recall defaults to its bundled `displayplacer` 1.4.0 binaries. This avoids making first-run setup depend on Homebrew or a manual command-line install.

Advanced users can configure a system or custom backend path from Settings. Backend updates are shipped with Display Recall app updates; there is no separate backend updater.

## License

Display Recall is open source under the MIT License. See `LICENSE`.

Third-party notices are listed in `THIRD_PARTY_NOTICES.md`.
