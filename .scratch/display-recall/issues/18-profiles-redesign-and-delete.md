Status: ready-for-agent

# Profiles Redesign And Delete

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Redesign the Profiles section around current usability and display matching state rather than a raw edit form. Add missing basic management features including search and profile deletion. Keep the visual style close to native macOS system utilities: quiet, structured, and status-driven.

## Acceptance criteria

- [ ] Profiles list supports search.
- [ ] Profile rows show useful compact status: display summary, current-setup match, automatic default, high-risk, and imported/needs-rebind indicators.
- [ ] Profile details prioritize current availability and safety: match status, risk status, automatic-default status, and primary Apply action.
- [ ] Secondary actions include Set/Clear Auto Default, Rebind to Current Displays, Export, and Delete.
- [ ] Notes and naming remain editable without making the whole page feel like a database form.
- [ ] Raw `displayplacer` command editing is hidden behind an Advanced disclosure by default.
- [ ] Delete Profile is placed in a Danger Zone and requires confirmation.
- [ ] Deleting a profile removes it from profiles, removes related automatic default rules, and removes or disables related shortcut bindings.
- [ ] Deleting a profile writes an Activity Log entry.
- [ ] After deletion, selection moves to a sensible neighboring profile or a polished empty state.
- [ ] No tags, groups, drag reorder, bulk edit, or visual display layout editor are introduced.
- [ ] Existing tests continue to pass, and new tests cover delete cleanup behavior.

## Blocked by

- `15-single-window-shell-and-menu-routing.md`
- `17-localization-hot-switch.md`
