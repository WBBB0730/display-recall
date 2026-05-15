Status: ready-for-agent

# Save Current Layout Lazy Group

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Make Save Current Layout work naturally with display setup groups. When the current display setup fingerprint has no group, saving the current layout should lazily create a group, generate a friendly group name, create the profile, and show it inside the current group. Empty states should stay focused on the single primary action: saving the current layout.

## Acceptance criteria

- [ ] Saving the current layout creates a display setup group if the current fingerprint has no group.
- [ ] Saving the current layout reuses the existing display setup group if the current fingerprint already has one.
- [ ] Newly saved profiles appear in the current display setup group.
- [ ] The current display setup group is visible even when it has no profiles.
- [ ] If there are no profiles at all, the Profile module empty state shows only one primary action: Save Current Layout.
- [ ] If there are historical profiles but no profile for the current display setup, the current display setup group still appears with a Save Current Layout action.
- [ ] The empty state does not show long explanatory copy.
- [ ] The empty state does not promote import, settings, logs, diagnostics, or advanced actions as primary actions.
- [ ] The Save Current Layout naming flow continues to let the user name the profile before saving.
- [ ] Profile generated names continue to use the existing first-non-conflicting rule.
- [ ] Display setup group generated names use their own first-non-conflicting rule.
- [ ] Tests cover lazy group creation when saving the first profile for a fingerprint.
- [ ] Tests cover saving another profile into an existing group.
- [ ] Tests cover current empty group visibility.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
