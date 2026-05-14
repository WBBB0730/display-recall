Status: ready-for-agent

# Automatic Apply On Display Change And Login

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement automatic profile matching and apply behavior for display setup changes and login startup. The flow should use system display change events, a startup stability wait, a 5-second stoppable popover, and final display state reread before applying.

## Acceptance criteria

- [x] The app listens for display setup change events.
- [x] Display changes schedule a 5-second pending automatic apply flow when automation is enabled.
- [x] A popover shows the profile that will be applied and lets the user stop this apply.
- [x] The user can immediately apply from the pending popover.
- [x] The user can pause automation from the pending popover.
- [x] At countdown end, the app rereads current display state before matching/applying.
- [x] If no unique default profile matches, the app does not guess or apply.
- [x] If multiple profiles match but no default exists, the app prompts for user choice rather than applying.
- [x] Login startup waits for display stability before attempting match.
- [x] Manual profile apply cancels any pending automatic apply.
- [x] Paused automation prevents display-change and login automatic applies while preserving manual apply.

## Blocked by

- `07-menu-bar-profile-switching.md`
