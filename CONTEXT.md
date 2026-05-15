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

**Automatic Apply**:
The global automation preference that turns startup/display-change automation on or off and controls the countdown duration.
_Avoid_: Default profile selection, active profile detection

**Configuration Shortcut**:
An optional global keyboard shortcut bound to one configuration. Triggering it applies that configuration as a manual apply action.
_Avoid_: Automatic apply shortcut, display setup shortcut

**Settings**:
The small set of app-wide preferences that change Display Recall behavior.
_Avoid_: Diagnostics, About, Logs, backend status, shortcut management

## Relationships

- A **Display Setup Group** belongs to exactly one **Display Setup**.
- A **Display Setup Group** contains zero or more **Configurations**.
- A **Configuration** belongs to exactly one **Display Setup Group** through its display setup.
- A **Display Setup Group** can have zero or one **Automatic Apply Configuration**.
- **Settings** contains only app-wide preferences such as launch at login, Dock icon visibility, language, and automatic apply countdown duration.
- **Automatic Apply** is a global Settings switch plus countdown duration; **Automatic Apply Configuration** selects which configuration runs for a display setup.
- A **Configuration Shortcut** belongs to exactly one **Configuration**.
- Triggering a **Configuration Shortcut** is equivalent to manually applying its configuration.
- A **Configuration Shortcut** is shown on its configuration row as shortcut status plus a Set/Edit action.
- A **Configuration Shortcut** is captured by pressing the desired key combination, not by typing a shortcut string manually.
- A **Configuration Shortcut** must be unique inside Display Recall; if a captured shortcut is already bound to another configuration, the user can modify the captured shortcut or replace the existing binding.
- Triggering a **Configuration Shortcut** uses the same manual apply risk handling as clicking Apply Configuration.
- If a **Configuration Shortcut** cannot be registered, Display Recall shows a simple failure message and records the failure; it does not show persistent shortcut status or automatically retry.
- Successful **Configuration Shortcut** applies should stay lightweight: record the apply event and avoid forcing the main window open or showing extra success notifications.
- An automatic apply countdown of `0` seconds means apply immediately and do not show the pending prevention panel.
- **Settings** does not contain shortcut management, update checks, backend diagnostics, Activity Log entry points, or About information.
- Deleting a **Display Setup Group** deletes every **Configuration** in that group.
- Only stored **Display Setup Groups** appear in the Profile page; the app does not create temporary groups just to represent the current display setup.
- Deleting the current **Display Setup Group** removes its stored group and configurations; a new group is created only when the user saves the current layout again.

## Example Dialogue

> **Dev:** "If the current Display Setup has no stored Display Setup Group, should the Profile page show a temporary empty group?"
> **Domain expert:** "No. The page should show stored groups only; saving the current layout is what creates the group."

## Flagged Ambiguities

- "Profile" is still used in code and older documents, but user-facing copy should prefer **Configuration**.
- "Display setup group delete" means deleting the group and all configurations inside it, not only removing a visual grouping.
