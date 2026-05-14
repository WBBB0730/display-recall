Status: ready-for-agent

# Profiles Window Management

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Build the Profiles window as the primary management surface. It should use a sidebar + detail layout, support saving current layout, applying profiles, renaming, notes, display summaries, current matching/default status, high-level history status, and advanced raw command editing with validation.

## Acceptance criteria

- [ ] Profiles appear in a sidebar with enough status to identify matching and automatic default profiles.
- [ ] Selecting a profile shows details in a separate detail pane.
- [ ] Users can save the current layout as a new profile.
- [ ] Users can rename profiles and edit notes.
- [ ] Users can view current display summary and profile display summary.
- [ ] Users can apply a profile from the Profiles window.
- [ ] Users can mark or unmark a profile as the automatic default for the current display setup.
- [ ] Users can rebind a profile to the current display setup.
- [ ] Advanced raw command editing exists and validates obvious broken commands before save.
- [ ] Normal UI does not provide full display parameter editors.

## Blocked by

- `05-display-list-parsing-and-fingerprints.md`
