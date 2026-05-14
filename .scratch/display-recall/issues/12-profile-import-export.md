Status: ready-for-agent

# Profile Import Export

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement backup and sharing flows for all profiles, selected profiles, and settings. Imports should preview profile count, conflicts, schema compatibility, and matching status before the user confirms merge/replace/skip behavior.

## Acceptance criteria

- [x] Users can export all profiles and settings as a standard backup.
- [x] Users can export a selected single profile.
- [x] Users can export selected multiple profiles.
- [x] Standard backups include schema version metadata and exclude logs and restore points.
- [x] Users can import one or more profiles.
- [x] Import preview shows profile count, names, conflicts, and whether profiles match the current Mac/display setup.
- [x] Same-name conflicts preserve both profiles by default using a generated suffix.
- [x] Import offers conflict strategies: keep both, replace same-name/existing, or skip conflict.
- [x] Import-as-new generates new local UUIDs.
- [x] Replace-existing keeps the local target UUID.
- [x] Imported profiles whose display IDs are not present are marked as not matching and do not participate in automatic apply until rebound.
- [x] Future unsupported schema versions are rejected with a clear message.

## Blocked by

- `06-profiles-window-management.md`
