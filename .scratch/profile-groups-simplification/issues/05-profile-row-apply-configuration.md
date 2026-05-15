Status: ready-for-agent

# Profile Row Apply Configuration

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Move profile application into the simplified profile row. Every profile row should expose Apply Configuration as the direct primary action. Applying profiles from non-current display setup groups or profiles with existing high-risk conditions should remain allowed, but must confirm risk before running.

## Acceptance criteria

- [x] Each profile row exposes an Apply Configuration action.
- [x] Profiles in the current display setup group can be applied from the row.
- [x] Profiles in non-current display setup groups can also be applied from the row.
- [x] Non-current display setup group applies require confirmation before running.
- [x] Existing high-risk conditions still require confirmation before running.
- [x] Imported-needs-first-apply and edited-command profiles retain their safety behavior.
- [x] The UI does not show constant risk badges in the profile row.
- [x] Risk is explained at execution time rather than as persistent row clutter.
- [x] Successful and failed apply attempts continue to write Activity Log entries.
- [x] Apply feedback remains visible to the user without reopening a detail editor.
- [x] Applying a profile manually does not change its automatic apply switch unless the user explicitly changes the switch.
- [x] User-facing strings are localized in English and Simplified Chinese.
- [x] Tests cover current-group apply behavior.
- [x] Tests cover non-current-group confirmation behavior where the logic is testable.
- [x] Tests cover preserving existing high-risk confirmation behavior.
- [x] Tests cover that manual apply does not mutate automatic apply rules.

## Blocked by

- `.scratch/profile-groups-simplification/issues/01-display-setup-groups-shell.md`
- `.scratch/profile-groups-simplification/issues/03-profile-automatic-apply-switch.md`
