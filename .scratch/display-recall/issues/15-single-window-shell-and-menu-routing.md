Status: ready-for-agent

# Single Window Shell And Menu Routing

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Replace the current split between a Profiles window and a broken system Settings scene with one native Display Recall main window. The main window should use a sidebar shell with app sections for Profiles, Activity Log, Settings, and About. Menu bar actions should open this main window and route to the right section instead of relying on the system Settings selector.

## Acceptance criteria

- [ ] The app has a single main window shell with sidebar destinations: Profiles, Activity Log, Settings, and About.
- [ ] Profiles is the default destination when opening the main window normally.
- [ ] The menu bar `Open Display Recall` action opens the main window and selects Profiles.
- [ ] The menu bar `Settings` action opens the main window and selects Settings.
- [ ] The app no longer depends on `showSettingsWindow:` or a separate SwiftUI `Settings` scene for core settings access.
- [ ] Existing profile, settings, log, update, and acknowledgement surfaces remain reachable through the new shell.
- [ ] The shell keeps a restrained native macOS utility feel and avoids dashboard-style cards or decorative visuals.
- [ ] Existing tests continue to pass, and new tests cover section routing state where practical.

## Blocked by

None - can start immediately
