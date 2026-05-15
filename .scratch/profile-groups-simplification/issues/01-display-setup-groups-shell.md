Status: ready-for-agent

# Display Setup Groups Shell

## Parent

`.scratch/profile-groups-simplification/PRD.md`

## What to build

Introduce display setup groups as stored, user-visible entities and replace the current Profile sidebar/detail surface with a simplified single-page grouped list. Existing profiles should be migrated or projected into groups by display setup fingerprint. The default Profile page should focus on groups and profile rows, not profile record details.

This slice should be demoable by opening the Profile module and seeing profiles grouped under friendly display setup group names. It should remove the search-first database feel and hide technical display summaries, fingerprints, notes, raw commands, and the detail editor from the main surface.

## Acceptance criteria

- [x] A display setup group entity exists with only `id`, `fingerprint`, `name`, `createdAt`, and `updatedAt` semantics.
- [x] Existing profiles with the same display setup fingerprint are grouped under the same display setup group.
- [x] Existing profiles with different display setup fingerprints are grouped under different display setup groups.
- [x] Existing automatic apply rules still reference the same profile IDs after group creation or migration.
- [x] Display setup groups use generated friendly names when no user-provided name exists.
- [x] Generated display setup group names use an independent sequence from generated profile names.
- [x] Generated display setup group names start at 1 and use the first non-conflicting name.
- [x] Generated names localize to English and Simplified Chinese.
- [x] Existing profile names and group names do not change when language changes.
- [x] The Profile module main surface is a single-page grouped list, not a sidebar plus detail editor.
- [x] Profile search is removed from the simplified UI.
- [x] The right-side profile detail editor is removed from the main Profile UI.
- [x] Profile rows do not show hardware summaries such as `27 inch external screen + Built-in Retina Display`.
- [x] Profile rows do not show display setup fingerprints.
- [x] Profile rows do not show notes.
- [x] Profile rows do not show raw `displayplacer` commands.
- [x] Profile rows do not show constant high-risk, imported, edited-command, or exact-current-layout indicators.
- [x] The current display setup group is expanded by default.
- [x] Non-current non-empty display setup groups are visible and collapsed by default.
- [x] Non-current empty display setup groups are hidden.
- [x] Current empty display setup group is visible.
- [x] Expanded/collapsed state is local UI state only and is not persisted.
- [x] Tests cover migration/grouping for same-fingerprint and different-fingerprint profiles.
- [x] Tests cover generated display setup group names in English and Simplified Chinese.
- [x] Tests cover current/non-current and empty/non-empty visibility rules.

## Blocked by

None - can start immediately
