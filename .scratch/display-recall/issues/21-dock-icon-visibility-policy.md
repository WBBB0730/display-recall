Status: ready-for-agent

# Dock Icon Visibility Policy

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Make Dock icon behavior match Display Recall's menu bar utility model without causing a launch-time Dock flash.

Display Recall should launch hidden from the Dock. The default Dock icon mode is Automatic: show the Dock icon while the main window is open, then hide it after the main window closes. Settings should also allow Always Show and Always Hide modes.

## Acceptance criteria

- [x] The packaged app declares UI-element launch behavior so the Dock icon does not flash during startup.
- [x] Dock icon visibility setting has three modes: Automatic, Always Show, and Always Hide.
- [x] Automatic is the default for new settings and migrated settings.
- [x] In Automatic mode, opening the main window shows the Dock icon.
- [x] In Automatic mode, closing the main window hides the Dock icon while the app keeps running in the menu bar.
- [x] In Always Show mode, the Dock icon stays visible regardless of main-window state.
- [x] In Always Show mode, clicking the Dock icon opens the main window when it is closed.
- [x] In Always Hide mode, the Dock icon stays hidden regardless of main-window state.
- [x] Switching to Always Hide while the main window is open keeps the main window open.
- [x] Settings exposes the three-mode choice with English and Simplified Chinese labels.
- [x] Existing settings that stored the old boolean Show Dock icon preference continue to load sensibly.
- [x] Tests cover Dock icon policy resolution and packaged app metadata.

## Blocked by

None - can start immediately.
