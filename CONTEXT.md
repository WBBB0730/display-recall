# Display Recall

Display Recall is a menu bar utility for saving and reapplying macOS display layouts. Its domain language keeps display environments, saved configurations, and automatic application rules distinct.

## Language

**Display Setup**:
A physical monitor connection environment identified by the enabled displays attached to the Mac.
_Avoid_: Layout, screen arrangement

**Display Setup Group**:
A user-named container for configurations that belong to one display setup.
_Avoid_: Folder, set, monitor group

**Configuration**:
A saved `displayplacer` command that can reapply one display layout for a display setup.
_Avoid_: Profile in user-facing copy

**Automatic Apply Configuration**:
The one configuration in a display setup group that may run automatically after startup or display changes.
_Avoid_: Default profile, active profile

## Relationships

- A **Display Setup Group** belongs to exactly one **Display Setup**.
- A **Display Setup Group** contains zero or more **Configurations**.
- A **Configuration** belongs to exactly one **Display Setup Group** through its display setup.
- A **Display Setup Group** can have zero or one **Automatic Apply Configuration**.
- Deleting a **Display Setup Group** deletes every **Configuration** in that group.
- Only stored **Display Setup Groups** appear in the Profile page; the app does not create temporary groups just to represent the current display setup.
- Deleting the current **Display Setup Group** removes its stored group and configurations; a new group is created only when the user saves the current layout again.

## Example Dialogue

> **Dev:** "If the current Display Setup has no stored Display Setup Group, should the Profile page show a temporary empty group?"
> **Domain expert:** "No. The page should show stored groups only; saving the current layout is what creates the group."

## Flagged Ambiguities

- "Profile" is still used in code and older documents, but user-facing copy should prefer **Configuration**.
- "Display setup group delete" means deleting the group and all configurations inside it, not only removing a visual grouping.
