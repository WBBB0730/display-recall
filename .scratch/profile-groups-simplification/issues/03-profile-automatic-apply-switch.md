Status: ready-for-agent

# Profile Automatic Apply Switch

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Replace the Profile module's visible default-profile concept with a per-profile Automatic Apply Configuration switch. Continue using the existing automatic apply rule storage underneath, but present it as a simple switch on each profile row. Within a display setup group, enabling one profile's switch must disable every sibling profile's switch.

## Acceptance criteria

- [ ] Profile rows show an Automatic Apply Configuration switch.
- [ ] The Profile module no longer uses visible "default profile", "set default", or "clear default" wording.
- [ ] The switch continues to use the existing automatic apply rule semantics under the hood.
- [ ] Turning on a profile switch sets the automatic apply rule for that profile's display setup fingerprint.
- [ ] Turning on one profile switch turns off sibling switches in the same display setup group.
- [ ] Turning on one profile switch does not affect profiles in other display setup groups.
- [ ] Turning off the active profile switch clears the automatic apply rule for that display setup group.
- [ ] A display setup group may have no profile selected for automatic apply.
- [ ] Menu bar and automatic apply behavior continue to use the same persisted rule data.
- [ ] User-facing strings are localized in English and Simplified Chinese.
- [ ] Tests cover same-group single-selection behavior.
- [ ] Tests cover cross-group independence.
- [ ] Tests cover clearing the active switch.
- [ ] Tests cover that existing automatic apply rules load into the correct switch state.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
