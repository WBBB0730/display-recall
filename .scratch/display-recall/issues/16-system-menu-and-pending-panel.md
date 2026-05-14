Status: ready-for-agent

# System Menu And Pending Panel

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Convert the normal menu bar experience into a true system-style menu that contains only high-frequency actions. Move automatic-apply pending countdown UI out of the menu and into an independently shown non-blocking floating panel with only Apply Now and Stop actions.

## Acceptance criteria

- [x] Normal menu bar UI uses a system menu style instead of a custom popover-style panel.
- [x] The menu contains current matching profiles, an Other Profiles submenu, Save Current Layout, Open Display Recall, Settings, Automatic Apply toggle, Check for Updates, and Quit.
- [x] Menu profile items apply profiles directly and show automatic-default/high-risk state in a compact menu-appropriate way.
- [x] The menu does not contain Activity Log, import/export, acknowledgements, or long explanatory content.
- [x] Automatic-apply pending state opens a separate non-blocking floating panel proactively without requiring a menu click.
- [x] Pending panel shows trigger, profile name, countdown, Apply Now, and Stop.
- [x] Pending panel does not include Pause.
- [x] Stop cancels only the current pending apply and does not disable global automatic apply.
- [x] A new display change during countdown cancels/replaces the current pending panel after rereading display state.
- [x] Existing tests continue to pass, and new tests cover pending panel state transitions where practical.

## Blocked by

- `15-single-window-shell-and-menu-routing.md`
