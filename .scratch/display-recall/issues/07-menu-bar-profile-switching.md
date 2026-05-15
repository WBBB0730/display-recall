Status: ready-for-agent

# Menu Bar Profile Switching

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement the normal menu bar experience for quick one-shot profile application. It should prioritize profiles matching the current display setup, separate other profiles, expose save/open/settings/pause/quit actions, and show automation/status signals without claiming that any profile is the exact current layout.

## Acceptance criteria

- [x] Menu bar popover shows current detected state and automation status.
- [x] Profiles matching the current display setup are listed before other profiles.
- [x] Profile items do not use checkmarks or other long-lived active indicators to represent the current layout.
- [x] Automatic defaults are used for automatic apply decisions, not as profile active-state marks in the quick menu.
- [x] Other profiles are separated or collapsed away from the quick path.
- [x] Users can apply a matching profile from the menu bar as a one-shot command.
- [x] Users can attempt to apply a non-matching profile and route through high-risk handling.
- [x] Saving the current layout from the menu bar asks for a profile name before creating the profile.
- [x] Users can open Profiles and Settings from the menu bar.
- [x] Users can pause automation from the menu bar.
- [x] Menu bar icon/state can represent normal, paused, pending, error, and setup-required states.

## Blocked by

- `06-profiles-window-management.md`
