Status: ready-for-agent

# Localization Hot Switch

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement app-wide English and Simplified Chinese localization coverage with immediate in-app language switching. Visible UI strings should no longer be hardcoded directly in views. Changing language in Settings should refresh already-open main window, menu, and floating panels without requiring relaunch or reopening windows.

## Acceptance criteria

- [x] All visible user-facing strings in the main window, menu bar menu, pending panel, settings, activity log, about, import/export, and profile management surfaces use the app localization layer.
- [x] English and Simplified Chinese translations are complete for the visible UI.
- [x] The language setting supports System, English, and Simplified Chinese.
- [x] Changing language in Settings immediately updates already-open SwiftUI surfaces.
- [x] Menu bar content uses the selected language the next time it opens, without relaunch.
- [x] Pending and other floating panels update their text while visible when the language changes.
- [x] Technical fields remain unlocalized: commands, paths, IDs, stdout, stderr, backend names, and raw fingerprints.
- [x] System language is resolved when System is selected; live OS language-change listening is not required.
- [x] Existing tests continue to pass, and localization tests cover key English/Chinese strings plus technical-field preservation.

## Blocked by

- `15-single-window-shell-and-menu-routing.md`
