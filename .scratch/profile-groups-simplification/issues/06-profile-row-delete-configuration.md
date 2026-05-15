Status: ready-for-agent

# Profile Row Delete Configuration

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move profile deletion into the profile row More menu with a short native confirmation. Deleting a profile must keep the existing cleanup guarantees for automatic apply rules, shortcut bindings, and Activity Log entries. Deleting the last profile in a display setup group must not delete the display setup group entity.

## Acceptance criteria

- [x] Each profile row More menu includes Delete.
- [x] Delete uses a native confirmation dialog.
- [x] Delete confirmation copy is short.
- [x] Delete confirmation does not require typing the profile name.
- [x] Deleting a profile removes it from the profile list.
- [x] Deleting an automatic apply profile clears the related automatic apply rule.
- [x] Deleting a profile removes or disables related shortcut bindings using the existing cleanup behavior.
- [x] Deleting a profile writes an Activity Log entry.
- [x] Deleting the last profile in a display setup group does not delete the display setup group entity.
- [x] After deleting the last profile in the current display setup group, the empty current group remains visible.
- [x] After deleting the last profile in a non-current display setup group, that empty group becomes hidden.
- [x] If the display setup later becomes current, the preserved empty group is visible again.
- [x] User-facing strings are localized in English and Simplified Chinese.
- [x] Tests cover delete cleanup for automatic apply rules.
- [x] Tests cover delete cleanup for shortcut bindings.
- [x] Tests cover Activity Log entry creation.
- [x] Tests cover preserving empty display setup group entities after last-profile deletion.
- [x] Tests cover current and non-current empty group visibility after deletion.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
- `.scratch/profile-groups-simplification/issues/03-profile-automatic-apply-switch.md`
