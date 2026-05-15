Status: ready-for-agent

# Import Export Entrypoints

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move import/export out of the primary toolbar and into More menus while preserving the existing backup format. The list-level More menu should import configurations and export all configurations. Each profile row More menu should export that single configuration. Both exports must use the same backup format.

## Acceptance criteria

- [ ] The list-level More menu includes Import Configurations.
- [ ] The list-level More menu includes Export Configurations.
- [ ] The profile row More menu includes Export Configuration.
- [ ] List-level export exports all profiles/configurations.
- [ ] Row-level export exports only that profile/configuration.
- [ ] List-level export and row-level export use the same backup format.
- [ ] Import continues to support existing backup documents.
- [ ] Import preview and conflict handling continue to preserve existing behavior.
- [ ] Export preserves profile data that is hidden from the simplified UI, including notes and raw command data.
- [ ] Export includes any display setup group data required by the new schema without breaking existing profile data.
- [ ] The simplified UI does not expose multi-select export.
- [ ] Import/export actions are available but do not dominate the main Profile surface.
- [ ] User-facing strings are localized in English and Simplified Chinese.
- [ ] Tests cover all-profile export.
- [ ] Tests cover single-profile export.
- [ ] Tests cover import compatibility with existing backup documents.
- [ ] Tests cover preserving hidden fields through export/import.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
