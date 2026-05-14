Status: ready-for-agent

# Profile Storage Schema And Migrations

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement persistent local storage for profiles, settings, automatic default rules, schema versions, and lightweight migrations. Data should be stored per macOS user in Application Support and be resilient enough for future schema evolution.

## Acceptance criteria

- [ ] Profiles persist across app restarts.
- [ ] Settings persist across app restarts.
- [ ] Automatic default rules persist as display setup fingerprint to profile UUID mappings.
- [ ] Stored data includes top-level schema version metadata.
- [ ] Stored profiles include UUID, schema version, raw command, display setup fingerprint, display summary, timestamps, backend version, and app version metadata.
- [ ] Unknown future schema versions are not blindly loaded or imported.
- [ ] Basic migration infrastructure exists for older schema versions.
- [ ] Storage is scoped to the current macOS user under Application Support.

## Blocked by

- `03-first-run-setup-and-first-profile.md`
