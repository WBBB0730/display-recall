Status: ready-for-agent

# Simplify Settings Preferences

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Reduce Settings to a single untitled preference group focused only on app-wide behavior. Remove secondary information and diagnostics from Settings.

The remaining controls are Launch at Login, Dock Icon, Language, and Automatic Apply. Automatic Apply is one row that combines the global enabled switch and a numeric countdown seconds input.

## Acceptance criteria

- [ ] Settings shows one untitled preference group.
- [ ] Settings includes Launch at Login.
- [ ] Settings includes Dock Icon with Automatic, Always Show, and Always Hide choices.
- [ ] Settings includes Language with System, English, and Simplified Chinese choices.
- [ ] Settings includes one Automatic Apply row with global on/off and editable seconds.
- [ ] Automatic Apply seconds accepts integers from 0 through 30.
- [ ] Automatic Apply seconds defaults to 5.
- [ ] Automatic Apply seconds of 0 immediately applies the matching automatic configuration without showing the pending prevention panel.
- [ ] Nonzero Automatic Apply seconds keeps the pending prevention panel behavior.
- [ ] Settings no longer shows shortcut management or shortcut counts.
- [ ] Settings no longer shows backend status, advanced backend controls, update checks, Activity Log links, diagnostic export, or version information.
- [ ] Existing tests pass, with focused tests for countdown validation and 0-second automatic apply behavior.

## Blocked by

None - can start immediately.
