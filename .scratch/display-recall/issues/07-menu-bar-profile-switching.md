Status: ready-for-agent

# Menu Bar Profile Switching

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement the normal menu bar popover experience for quick profile switching. It should prioritize profiles matching the current display setup, separate other profiles, expose save/open/settings/pause/quit actions, and show current automation/status signals.

## Acceptance criteria

- [x] Menu bar popover shows current detected state and automation status.
- [x] Profiles matching the current display setup are listed before other profiles.
- [x] The automatic default profile is clearly marked.
- [x] Other profiles are separated or collapsed away from the quick path.
- [x] Users can apply a matching profile from the menu bar.
- [x] Users can attempt to apply a non-matching profile and route through high-risk handling.
- [x] Users can save the current layout from the menu bar.
- [x] Users can open Profiles and Settings from the menu bar.
- [x] Users can pause automation from the menu bar.
- [x] Menu bar icon/state can represent normal, paused, pending, error, and setup-required states.

## Blocked by

- `06-profiles-window-management.md`
