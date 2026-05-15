Status: ready-for-agent

# Rename Profile And Display Setup Group

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Add lightweight rename flows for both profiles and display setup groups. Renaming should live in More menus and use a small focused dialog with one text field and Cancel/Save actions. This keeps editing available without reintroducing the old detail-form surface.

## Acceptance criteria

- [ ] Each profile row has a More menu that includes Rename.
- [ ] Each display setup group header has a More menu that includes Rename.
- [ ] Profile rename uses a small focused dialog with one text field.
- [ ] Display setup group rename uses the same dialog pattern.
- [ ] Rename dialogs have Cancel and Save actions.
- [ ] Empty or whitespace-only rename submissions do not replace the existing name.
- [ ] Renaming a profile updates the profile and preserves all other profile data.
- [ ] Renaming a display setup group updates the group and preserves the group fingerprint.
- [ ] Renamed display setup groups keep their names when all profiles in the group are deleted.
- [ ] Existing renamed profile and group names do not change when language changes.
- [ ] The main Profile UI does not expose inline editing.
- [ ] The main Profile UI does not reintroduce notes editing.
- [ ] The main Profile UI does not reintroduce raw command editing.
- [ ] User-facing strings are localized in English and Simplified Chinese.
- [ ] Tests cover profile rename.
- [ ] Tests cover display setup group rename.
- [ ] Tests cover preserving a renamed empty display setup group.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
