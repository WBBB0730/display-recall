Status: ready-for-agent

# Remove Ephemeral Display Setup Groups

## Context

The grouped Profile page currently creates an ephemeral current display setup group when the current display fingerprint has no stored group. This made the current setup visible before saving, but it creates a false object: it looks like a display setup group while lacking the full behavior of a stored group.

The product language has tightened: the Profile page should show stored display setup groups only. Saving the current layout remains the one action that lazily creates a real group for the current fingerprint.

## Scope

Remove ephemeral current display setup groups from the grouping projection and Profile page.

## Acceptance Criteria

- [x] The grouping projection returns only stored display setup groups.
- [x] If the current fingerprint has no stored group, the projection does not synthesize a current empty group.
- [x] Non-current empty stored groups remain hidden.
- [x] Stored current empty groups remain visible.
- [x] Deleting the current stored group removes it from the list until Save Current Layout creates a new stored group.
- [x] When no stored groups are visible, the Profile page keeps the simple empty state and the Save Current Layout primary action.
- [x] Save Current Layout still lazily creates a stored display setup group when needed.
- [x] Existing tests continue to pass.

## Out Of Scope

- Changing Save Current Layout naming behavior.
- Adding explanatory empty-state copy.
- Changing display setup group sorting.
