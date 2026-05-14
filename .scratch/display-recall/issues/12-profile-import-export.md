Status: ready-for-agent

# Profile Import Export

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement backup and sharing flows for all profiles, selected profiles, and settings. Imports should preview profile count, conflicts, schema compatibility, and matching status before the user confirms merge/replace/skip behavior.

## Acceptance criteria

- [ ] Users can export all profiles and settings as a standard backup.
- [ ] Users can export a selected single profile.
- [ ] Users can export selected multiple profiles.
- [ ] Standard backups include schema version metadata and exclude logs and restore points.
- [ ] Users can import one or more profiles.
- [ ] Import preview shows profile count, names, conflicts, and whether profiles match the current Mac/display setup.
- [ ] Same-name conflicts preserve both profiles by default using a generated suffix.
- [ ] Import offers conflict strategies: keep both, replace same-name/existing, or skip conflict.
- [ ] Import-as-new generates new local UUIDs.
- [ ] Replace-existing keeps the local target UUID.
- [ ] Imported profiles whose display IDs are not present are marked as not matching and do not participate in automatic apply until rebound.
- [ ] Future unsupported schema versions are rejected with a clear message.

## Blocked by

- `06-profiles-window-management.md`
