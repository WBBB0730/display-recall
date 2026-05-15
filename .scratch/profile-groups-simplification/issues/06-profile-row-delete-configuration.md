Status: ready-for-agent

# Profile Row Delete Configuration

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move profile deletion into the profile row More menu with a short native confirmation. Deleting a profile must keep the existing cleanup guarantees for automatic apply rules, shortcut bindings, and Activity Log entries. Deleting the last profile in a display setup group must not delete the display setup group entity.

## Acceptance criteria

- [ ] Each profile row More menu includes Delete.
- [ ] Delete uses a native confirmation dialog.
- [ ] Delete confirmation copy is short.
- [ ] Delete confirmation does not require typing the profile name.
- [ ] Deleting a profile removes it from the profile list.
- [ ] Deleting an automatic apply profile clears the related automatic apply rule.
- [ ] Deleting a profile removes or disables related shortcut bindings using the existing cleanup behavior.
- [ ] Deleting a profile writes an Activity Log entry.
- [ ] Deleting the last profile in a display setup group does not delete the display setup group entity.
- [ ] After deleting the last profile in the current display setup group, the empty current group remains visible.
- [ ] After deleting the last profile in a non-current display setup group, that empty group becomes hidden.
- [ ] If the display setup later becomes current, the preserved empty group is visible again.
- [ ] User-facing strings are localized in English and Simplified Chinese.
- [ ] Tests cover delete cleanup for automatic apply rules.
- [ ] Tests cover delete cleanup for shortcut bindings.
- [ ] Tests cover Activity Log entry creation.
- [ ] Tests cover preserving empty display setup group entities after last-profile deletion.
- [ ] Tests cover current and non-current empty group visibility after deletion.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
- `.scratch/profile-groups-simplification/issues/03-profile-automatic-apply-switch.md`
