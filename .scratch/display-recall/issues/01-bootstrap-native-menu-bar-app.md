Status: ready-for-agent

# Bootstrap Native Menu Bar App

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Create the first runnable Display Recall macOS app as a native Swift/SwiftUI menu bar utility. The app should launch on macOS 13+, expose a menu bar extra, provide a Profiles window and Settings window entry point, and keep running when user-facing windows close. It should use the product name `Display Recall` and establish the basic app structure future slices will build on.

## Acceptance criteria

- [x] The app launches as `Display Recall` on macOS 13+.
- [x] A menu bar extra is visible while the app is running.
- [x] The menu bar extra can open the Profiles window.
- [x] The menu bar extra can open Settings.
- [x] Closing the Profiles window does not quit the app.
- [x] The app has an explicit Quit action from the menu bar.
- [x] The app can hide the Dock icon after setup-era behavior is no longer needed, with a setting-ready architecture for showing it later.
- [x] The app follows system light/dark appearance with native controls.

## Blocked by

None - can start immediately
