Status: ready-for-agent

# Configuration Shortcuts

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Add first-class Configuration Shortcut support. Each configuration row should expose shortcut status in the lower-right area and a Set/Edit action. The user can capture a key combination, save it, clear it, or resolve an in-app conflict by modifying the capture or replacing the existing binding.

Triggering a shortcut applies the target configuration exactly like a manual Apply Configuration action, including existing high-risk handling. Shortcut management stays out of Settings.

## Acceptance criteria

- [ ] Each configuration row shows `Shortcut: Not Set` / `快捷键：未设置` when no shortcut is bound.
- [ ] Each configuration row shows the bound shortcut when one exists.
- [ ] Each configuration row shows `Set` / `设置` when empty and `Edit` / `修改` when bound.
- [ ] Clicking Set/Edit opens a lightweight shortcut capture panel for that configuration.
- [ ] The capture panel records shortcuts by pressing a key combination, not by manually typing a string.
- [ ] The capture panel supports Save, Clear, and Cancel.
- [ ] Shortcut bindings are stored with settings and remain associated with the configuration UUID.
- [ ] In-app shortcut conflicts are detected by shortcut identity.
- [ ] When a conflict exists, the user can Modify the captured shortcut or Replace the existing binding.
- [ ] Replacing removes the shortcut from the previous configuration and binds it to the current configuration.
- [ ] Display Recall does not warn about common system shortcuts.
- [ ] Registered shortcuts work while Display Recall is running and do not require the main window to be open.
- [ ] Triggering a shortcut uses the same manual apply behavior as clicking Apply Configuration, including high-risk handling.
- [ ] Successful shortcut applies do not force the main window open or show extra success notifications.
- [ ] Shortcut registration failure shows a simple failure message and records Activity Log details.
- [ ] Shortcut registration failure does not create persistent status UI and does not automatically retry.
- [ ] Settings does not expose shortcut management.
- [ ] Tests cover shortcut capture validation, conflict replace behavior, clearing bindings, and shortcut-triggered manual apply semantics.

## Blocked by

None - can start immediately.
