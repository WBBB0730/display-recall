Status: ready-for-agent

# Settings Language Login And Shortcuts

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement Settings for global app behavior: backend selection visibility, open at login, automation defaults, countdown duration, Dock icon preference, language selection, shortcut permissions, and optional global shortcut assignment per profile.

## Acceptance criteria

- [ ] Settings exposes current backend source/version/path and allows advanced custom backend selection.
- [ ] Settings can enable or disable launch at login.
- [ ] Settings can enable or disable automatic apply globally.
- [ ] Settings can configure the automatic apply countdown, defaulting to 5 seconds.
- [ ] Settings can show or hide the Dock icon.
- [ ] Settings supports language choices: System, English, 简体中文.
- [ ] UI strings are localized in English and Simplified Chinese.
- [ ] Profile auto-generated names use the current UI language.
- [ ] Existing profile names do not change when language changes.
- [ ] Each profile can optionally have a global shortcut.
- [ ] Shortcuts default to empty.
- [ ] Shortcut setup requests any required permission only when the user configures shortcuts.
- [ ] In-app shortcut conflicts are blocked and common system shortcut conflicts are warned about.

## Blocked by

- `06-profiles-window-management.md`
