Status: ready-for-agent

# Profile Row Apply Configuration

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move profile application into the simplified profile row. Every profile row should expose Apply Configuration as the direct primary action. Applying profiles from non-current display setup groups or profiles with existing high-risk conditions should remain allowed, but must confirm risk before running.

## Acceptance criteria

- [ ] Each profile row exposes an Apply Configuration action.
- [ ] Profiles in the current display setup group can be applied from the row.
- [ ] Profiles in non-current display setup groups can also be applied from the row.
- [ ] Non-current display setup group applies require confirmation before running.
- [ ] Existing high-risk conditions still require confirmation before running.
- [ ] Imported-needs-first-apply and edited-command profiles retain their safety behavior.
- [ ] The UI does not show constant risk badges in the profile row.
- [ ] Risk is explained at execution time rather than as persistent row clutter.
- [ ] Successful and failed apply attempts continue to write Activity Log entries.
- [ ] Apply feedback remains visible to the user without reopening a detail editor.
- [ ] Applying a profile manually does not change its automatic apply switch unless the user explicitly changes the switch.
- [ ] User-facing strings are localized in English and Simplified Chinese.
- [ ] Tests cover current-group apply behavior.
- [ ] Tests cover non-current-group confirmation behavior where the logic is testable.
- [ ] Tests cover preserving existing high-risk confirmation behavior.
- [ ] Tests cover that manual apply does not mutate automatic apply rules.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
- `.scratch/profile-groups-simplification/issues/03-profile-automatic-apply-switch.md`
