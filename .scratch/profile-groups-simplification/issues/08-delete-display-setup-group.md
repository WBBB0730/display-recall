Status: ready-for-agent

# Delete Display Setup Group

## Context

Display setup groups are now first-class user-facing containers for configurations, but users cannot delete obsolete groups directly. The previous PRD intentionally excluded group deletion while the profile list model was stabilizing. The product decision has changed: every visible display setup group should expose deletion.

## Scope

Add Delete Display Setup Group as a group-level action in the Profile page.

## Acceptance Criteria

- [ ] Every visible display setup group header exposes a delete icon beside the rename icon.
- [ ] The group header action order is Rename, then Delete.
- [ ] The delete icon uses the same neutral hover treatment as other icon actions.
- [ ] Deleting an empty group removes the stored display setup group.
- [ ] Deleting a non-empty group removes the stored display setup group and every configuration in that group.
- [ ] Deleting a group clears automatic apply rules for every deleted configuration.
- [ ] Deleting a group clears shortcut bindings for every deleted configuration.
- [ ] Deleting the current display setup group causes the Profile page to show a new empty current group for the current fingerprint.
- [ ] Deleting a non-current display setup group removes it from the visible list.
- [ ] Delete confirmation uses concise native copy.
- [ ] Delete confirmation for non-empty groups states how many configurations will also be deleted.
- [ ] Group deletion records one group-level activity log entry with group name, deleted configuration count, and deleted configuration identifiers/names in diagnostics metadata.
- [ ] Existing profile delete behavior still deletes only the selected configuration and does not automatically delete its group.
- [ ] Existing tests continue to pass.

## Out Of Scope

- Display setup group sorting.
- Display setup group merge or split.
- Display setup group icons, colors, notes, or details page.
- Changing profile import/export backup format.
