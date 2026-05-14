Status: ready-for-agent

# Import Export Log Settings About Polish

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Polish the lower-priority main-window sections and workflows after the new shell and Profiles redesign are in place. Import/export should become app-designed sheet flows instead of raw panel/alert chaining. Activity Log, Settings, and About should be organized into clear low-friction pages inside the single window shell.

## Acceptance criteria

- [ ] Export from Profiles uses a sheet flow for Current, Selected, or All before showing the save panel.
- [ ] Export sheet shows the number of profiles that will be exported.
- [ ] Import uses file selection followed by an app-designed preview sheet.
- [ ] Import preview shows profile count, names, conflicts, matching current setup, and needs-rebind state.
- [ ] Import preview lets the user choose Keep Both, Replace Existing, or Skip Conflicts, with Keep Both as default.
- [ ] Activity Log is a sidebar page with reverse-chronological entries, useful filters, selected-entry details, Copy Entry, and Copy Diagnostic Export.
- [ ] Settings is a sidebar page with clear sections for General, Automation, Backend, Shortcuts, Updates, and Diagnostics.
- [ ] Settings does not become a long miscellaneous form; advanced backend controls are visually de-emphasized.
- [ ] About is a sidebar page with version/build, independent companion notice, update entry point, and third-party acknowledgements/licenses.
- [ ] Menu bar and Profiles surfaces only link to diagnostics/logs when useful; they do not embed logs directly.
- [ ] Existing tests continue to pass, and new tests cover import/export preview behavior where practical.

## Blocked by

- `15-single-window-shell-and-menu-routing.md`
- `17-localization-hot-switch.md`
- `18-profiles-redesign-and-delete.md`
