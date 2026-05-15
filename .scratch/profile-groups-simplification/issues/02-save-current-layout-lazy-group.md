Status: ready-for-agent

# Save Current Layout Lazy Group

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Make Save Current Layout work naturally with display setup groups. When the current display setup fingerprint has no group, saving the current layout should lazily create a group, generate a friendly group name, create the profile, and show it inside the current group. Empty states should stay focused on the single primary action: saving the current layout.

## Acceptance criteria

- [x] Saving the current layout creates a display setup group if the current fingerprint has no group.
- [x] Saving the current layout reuses the existing display setup group if the current fingerprint already has one.
- [x] Newly saved profiles appear in the current display setup group.
- [x] The current display setup group is visible even when it has no profiles.
- [x] If there are no profiles at all, the Profile module empty state shows only one primary action: Save Current Layout.
- [x] If there are historical profiles but no profile for the current display setup, the current display setup group still appears with a Save Current Layout action.
- [x] The empty state does not show long explanatory copy.
- [x] The empty state does not promote import, settings, logs, diagnostics, or advanced actions as primary actions.
- [x] The Save Current Layout naming flow continues to let the user name the profile before saving.
- [x] Profile generated names continue to use the existing first-non-conflicting rule.
- [x] Display setup group generated names use their own first-non-conflicting rule.
- [x] Tests cover lazy group creation when saving the first profile for a fingerprint.
- [x] Tests cover saving another profile into an existing group.
- [x] Tests cover current empty group visibility.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
