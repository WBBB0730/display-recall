Status: ready-for-agent

# Import Export Entrypoints

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move import/export out of the primary toolbar and into More menus while preserving the existing backup format. The list-level More menu should import configurations and export all configurations. Each profile row More menu should export that single configuration. Both exports must use the same backup format.

## Acceptance criteria

- [x] The list-level More menu includes Import Configurations.
- [x] The list-level More menu includes Export Configurations.
- [x] The profile row More menu includes Export Configuration.
- [x] List-level export exports all profiles/configurations.
- [x] Row-level export exports only that profile/configuration.
- [x] List-level export and row-level export use the same backup format.
- [x] Import continues to support existing backup documents.
- [x] Import preview and conflict handling continue to preserve existing behavior.
- [x] Export preserves profile data that is hidden from the simplified UI, including notes and raw command data.
- [x] Export includes any display setup group data required by the new schema without breaking existing profile data.
- [x] The simplified UI does not expose multi-select export.
- [x] Import/export actions are available but do not dominate the main Profile surface.
- [x] User-facing strings are localized in English and Simplified Chinese.
- [x] Tests cover all-profile export.
- [x] Tests cover single-profile export.
- [x] Tests cover import compatibility with existing backup documents.
- [x] Tests cover preserving hidden fields through export/import.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
