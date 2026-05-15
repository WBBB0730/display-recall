Status: ready-for-agent

# Settings Language Login And Shortcuts

Superseded for Settings UI scope by `22-simplify-settings-preferences.md`. Shortcut data structures remain, but shortcut management is no longer part of the Settings page.

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement Settings for global app behavior: backend selection visibility, open at login, automation defaults, countdown duration, Dock icon preference, language selection, shortcut permissions, and optional global shortcut assignment per profile.

## Acceptance criteria

- [x] Settings exposes current backend source/version/path and allows advanced custom backend selection.
- [x] Settings can enable or disable launch at login.
- [x] Settings can enable or disable automatic apply globally.
- [x] Settings can configure the automatic apply countdown, defaulting to 5 seconds.
- [x] Settings can show or hide the Dock icon.
- [x] Settings supports language choices: System, English, 简体中文.
- [x] UI strings are localized in English and Simplified Chinese.
- [x] Profile auto-generated names use the current UI language.
- [x] Existing profile names do not change when language changes.
- [x] Each profile can optionally have a global shortcut.
- [x] Shortcuts default to empty.
- [x] Shortcut setup requests any required permission only when the user configures shortcuts.
- [x] In-app shortcut conflicts are blocked and common system shortcut conflicts are warned about.

## Blocked by

- `06-profiles-window-management.md`
