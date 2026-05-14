Status: ready-for-agent

# First Run Setup And First Profile

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement the first-run setup flow that verifies the bundled backend, reads the current display layout, and guides the user to save the first profile. The first profile should be auto-named, editable before completion, and default to automatic use for the current display setup unless the user opts out.

## Acceptance criteria

- [x] First launch opens setup instead of dropping the user into an empty app.
- [x] Setup verifies the backend by running `displayplacer list`.
- [x] Setup shows clear success/failure states and a retry path.
- [x] Setup can capture the current display layout as a profile using the authoritative raw `displayplacer` command.
- [x] The first profile gets an automatically generated name from the current display setup.
- [x] The generated name can be edited during setup.
- [x] A default-on option marks the first profile as the automatic default for the current display setup.
- [x] Completing setup transitions the app into normal menu bar behavior.

## Blocked by

- `02-bundle-and-verify-displayplacer-backend.md`
