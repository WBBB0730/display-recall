Status: ready-for-agent

# Rename Profile And Display Setup Group

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Add lightweight rename flows for both profiles and display setup groups. Renaming should live in More menus and use a small focused dialog with one text field and Cancel/Save actions. This keeps editing available without reintroducing the old detail-form surface.

## Acceptance criteria

- [x] Each profile row has a More menu that includes Rename.
- [x] Each display setup group header has a More menu that includes Rename.
- [x] Profile rename uses a small focused dialog with one text field.
- [x] Display setup group rename uses the same dialog pattern.
- [x] Rename dialogs have Cancel and Save actions.
- [x] Empty or whitespace-only rename submissions do not replace the existing name.
- [x] Renaming a profile updates the profile and preserves all other profile data.
- [x] Renaming a display setup group updates the group and preserves the group fingerprint.
- [x] Renamed display setup groups keep their names when all profiles in the group are deleted.
- [x] Existing renamed profile and group names do not change when language changes.
- [x] The main Profile UI does not expose inline editing.
- [x] The main Profile UI does not reintroduce notes editing.
- [x] The main Profile UI does not reintroduce raw command editing.
- [x] User-facing strings are localized in English and Simplified Chinese.
- [x] Tests cover profile rename.
- [x] Tests cover display setup group rename.
- [x] Tests cover preserving a renamed empty display setup group.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
