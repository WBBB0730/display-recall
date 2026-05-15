Status: completed

# 使用 UUID 判断导入冲突

## Parent

.scratch/import-preview-simplification/PRD.md

## What to build

Change profile import conflict semantics so that conflicts are detected by profile UUID, not profile name. Names are user labels and may repeat. The import preview should only show conflict handling when imported profiles share UUIDs with existing local profiles. Keep Both should keep both profiles without renaming the imported copy; Replace Existing should replace the profile with the same UUID; Skip Conflict should skip only profiles whose UUIDs already exist locally. Non-conflicting imports should preserve their imported UUIDs so future imports can detect duplicate historical objects.

## Acceptance criteria

- [x] Same-name profiles with different UUIDs import without conflict.
- [x] Same-UUID profiles are reported as conflicts in the import preview summary.
- [x] Keep Both on a UUID conflict imports a second profile with a new UUID and the original imported name unchanged.
- [x] Replace Existing on a UUID conflict replaces the existing profile while preserving that UUID.
- [x] Skip Conflict skips only imported profiles whose UUIDs already exist locally.
- [x] Non-conflicting imported profiles preserve their UUIDs.
- [x] The import preview stays minimal and only shows conflict strategy when UUID conflicts exist.

## Blocked by

None - can start immediately.
