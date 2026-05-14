Status: ready-for-agent

# Menu Bar Profile Switching

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement the normal menu bar popover experience for quick profile switching. It should prioritize profiles matching the current display setup, separate other profiles, expose save/open/settings/pause/quit actions, and show current automation/status signals.

## Acceptance criteria

- [ ] Menu bar popover shows current detected state and automation status.
- [ ] Profiles matching the current display setup are listed before other profiles.
- [ ] The automatic default profile is clearly marked.
- [ ] Other profiles are separated or collapsed away from the quick path.
- [ ] Users can apply a matching profile from the menu bar.
- [ ] Users can attempt to apply a non-matching profile and route through high-risk handling.
- [ ] Users can save the current layout from the menu bar.
- [ ] Users can open Profiles and Settings from the menu bar.
- [ ] Users can pause automation from the menu bar.
- [ ] Menu bar icon/state can represent normal, paused, pending, error, and setup-required states.

## Blocked by

- `06-profiles-window-management.md`
