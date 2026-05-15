Status: ready-for-agent

# Display Recall PRD

## Problem Statement

Mac users who rely on multiple displays often need to restore the same display layout repeatedly: home desk, office desk, meeting mode, clamshell mode, or laptop-only mode. `displayplacer` can save and apply these layouts from the command line, but the command-line workflow is too easy to forget, too technical for many users, and too awkward for frequent switching.

Users need a native macOS menu bar app that remembers display layouts, switches them quickly, and safely reapplies the right layout when displays are connected, disconnected, or available after login. The app must reduce confusion rather than introduce more setup steps, especially around installing or locating `displayplacer`.

## Solution

Build `Display Recall`, a native Swift/SwiftUI macOS menu bar companion for `displayplacer`.

Display Recall stores display layouts as profiles. Each profile treats the original `displayplacer` command as authoritative data, with parsed display summaries used only for validation, diagnostics, and UI. The app does not claim to prove that the current layout is exactly equal to any saved profile. The app ships with a bundled `displayplacer` backend by default, while still allowing advanced users to choose a Homebrew/system/custom backend path.

The main product surface is a menu bar app with a Profiles window and Settings window. Users can save the current layout, apply profiles from the menu bar as one-shot commands, define automatic defaults per display setup, pause automation, import/export profiles, and inspect a lightweight Activity Log. When displays change or the app launches at login, Display Recall waits for the display setup to stabilize, shows a 5-second popover that lets the user stop the pending automatic apply, then applies the matching default profile if one exists.

High-risk operations require confirmation and use a 15-second keep/restore safety flow. The app is distributed outside the Mac App Store through signed and notarized GitHub Releases, supports Sparkle updates, and ships with English and Simplified Chinese localization.

## User Stories

1. As a Mac user with multiple displays, I want to save my current display layout as a profile, so that I can restore it later.
2. As a Mac user, I want Display Recall to work without manually installing `displayplacer`, so that setup does not stop me before I understand the app.
3. As a Mac user, I want the app to verify its display backend during setup, so that I know it can safely read and apply layouts.
4. As a first-time user, I want setup to guide me into creating my first profile, so that I know what to do after installation.
5. As a first-time user, I want the first profile to default to automatic use for the current display setup, so that my current layout is remembered with one clear step.
6. As a menu bar user, I want to apply matching profiles from the menu bar, so that I can restore layouts without opening a full window.
7. As a menu bar user, I want non-matching profiles to be separated from matching profiles, so that quick switching stays focused.
8. As a user with several layouts for the same displays, I want one automatic default profile per display setup, so that automation does not guess incorrectly.
9. As a user, I want hand-applied profiles not to change automation defaults, so that temporary choices do not become permanent rules.
10. As a user, I want an obvious action to set a manually applied profile as the automatic default, so that I can intentionally update the rule.
11. As a user, I want the app to detect display connection changes, so that the right layout can be applied after docking or undocking.
12. As a user, I want automatic apply to wait 5 seconds and show a stop panel, so that I can prevent unwanted display changes.
13. As a user, I want login startup to wait for display setup stability before applying a profile, so that the app does not race external displays.
14. As a user, I want to pause automation for 1 hour, until tomorrow, or indefinitely, so that temporary display sessions do not keep triggering rules.
15. As a user, I want Display Recall to keep running after I close the Profiles window, so that menu bar switching and automation continue.
16. As a user, I want the Dock icon hidden after setup by default, so that the app behaves like a quiet menu bar utility.
17. As a user, I want to show the Dock icon from Settings, so that I can choose a more visible app behavior.
18. As a user, I want Automatic Dock icon behavior, so that the Dock icon appears while the main window is open and disappears when the app returns to menu-bar-only mode.
19. As a user, I want Always Show and Always Hide Dock icon settings, so that I can choose my preferred macOS workflow.
20. As a user, I do not want the Dock icon to flash during launch, so that Display Recall feels like a polished menu bar utility.
21. As a user, I want a Profiles window with a sidebar and detail view, so that I can manage profiles without a cluttered list.
22. As a user, I want Settings to contain global behavior, so that profile management and app configuration stay separate.
23. As a user, I want Settings to be a small single-group preference page, so that changing app behavior does not feel like navigating a diagnostics console.
24. As a user, I want Automatic Apply in Settings to combine the global on/off switch and countdown seconds, so that the preference reads as one concept.
25. As a user, I want a countdown value of 0 seconds to apply immediately without a pending panel, so that automation can be instant when I choose that behavior.
26. As a user, I do not want shortcut management, backend diagnostics, update checks, logs, diagnostics, or About information in Settings, so that Settings stays focused.
27. As a user, I want profile names to be suggested automatically from my display setup, so that saving a profile is quick.
28. As a user, I want Save Current Layout to ask for a profile name before creating the profile, so that I do not accumulate unclear auto-generated names.
29. As a user, I want display summaries to show enough detail to recognize a profile, so that I can tell which displays and layout it represents.
30. As an advanced user, I want to edit the raw `displayplacer` command, so that I can adjust parameters the app does not expose as controls.
31. As an advanced user, I want edited commands to be validated before saving, so that obvious broken profile data is caught early.
32. As a user, I want profiles to bind to the current display setup through stable display IDs, so that automatic matching survives normal use.
33. As a user, I want built-in display presence and enabled display count to be part of matching, so that open-lid and clamshell setups do not collide.
34. As a user, I want unreliable display ID matching to be marked clearly, so that I understand why a profile may be risky.
35. As a user, I want profile menu items to behave as one-shot apply commands rather than active-state indicators, so that I do not confuse a matching display setup with a verified current layout.
36. As a user, I want Display Recall to separate display setup matching from exact layout equality, so that automation can stay useful without making false certainty claims.
37. As a user, I want high-risk profile applies to ask for confirmation, so that I do not accidentally apply a dangerous layout.
38. As a user, I want high-risk applies to show a 15-second keep/restore prompt, so that I can recover if a layout makes my screen hard to use.
39. As a user, I want failed applies to offer manual restore, so that I can recover without the app attempting confusing automatic rollback.
40. As a user, I want the app to keep the most recent restore point, so that the last display change can be undone.
41. As a user, I want restoring a layout to support one undo, so that recovery itself is not a dead end.
42. As a user, I want an Activity Log, so that I can understand why the app changed or did not change my display layout.
43. As a user, I want Activity Log entries to include trigger, command, result, and errors, so that display problems can be diagnosed.
44. As a user, I want logs to be structured and rendered in my selected language, so that changing language does not make history inconsistent.
45. As a user, I want to copy diagnostic information, so that I can report issues with useful detail.
46. As a user, I want to export all profiles and settings, so that I can back up my configuration.
47. As a user, I want to export selected profiles, so that I can share or back up only specific layouts.
48. As a user, I want to import one or more profiles, so that I can restore or share layouts.
49. As a user, I want imports to preview conflicts and matching status, so that I do not accidentally overwrite useful profiles.
50. As a user, I want imported profiles from another Mac to be allowed but marked as not matching, so that I can inspect or rebind them safely.
51. As a user, I want same-name import conflicts to preserve both profiles by default, so that data is not lost.
52. As a user, I want to rebind a profile to the current display setup, so that imported or changed setups can be made useful again.
53. As a user, I want each configuration row to show whether a shortcut is set, so that I can scan keyboard access without opening Settings.
54. As a user, I want to set, modify, or clear a shortcut directly from a configuration row, so that shortcut management stays local to the configuration.
55. As a user, I want shortcut capture to happen by pressing a key combination, so that I do not need to type shortcut strings manually.
56. As a user, I want in-app shortcut conflicts to offer Modify or Replace, so that I can either pick another shortcut or move the existing binding.
57. As a user, I want shortcut applies to behave like manual applies, so that high-risk configurations still get the same protection.
58. As a user, I want shortcut registration failures to be handled lightly, so that the app does not add persistent warning clutter.
59. As a user, I want mirrored display profiles to save and apply correctly, so that projector and mirroring setups are supported.
60. As a user, I want display-disabling profiles to be treated as high risk, so that I do not accidentally lose visible output.
61. As a user, I want the primary display state to be preserved through the saved command, so that my menu bar and main screen return correctly.
62. As a user, I want refresh rate, color depth, scaling, and rotation to be preserved without complex editors, so that profiles stay powerful but simple.
63. As a user, I want the app to follow my system appearance, so that it looks native in light and dark mode.
64. As a user, I want English and Simplified Chinese UI, so that the app is comfortable in both languages.
65. As a user, I want language to follow the system by default, so that the app chooses the right language automatically.
66. As a user, I want to override the app language manually, so that I can choose English or Simplified Chinese regardless of system language.
67. As a user, I want profile auto-generated names to use the current UI language, so that new profiles fit the current locale.
68. As a user, I want existing profile names not to change when language changes, so that names I edited remain stable.
69. As a user, I want built-in updates, so that I can install new Display Recall releases with one click.
70. As a user, I want updates to be user-confirmed rather than silent, so that the app does not restart unexpectedly.
71. As a user, I want release builds signed and notarized, so that macOS security prompts do not undermine trust.
72. As a user, I want to see third-party acknowledgements, so that bundled dependencies are transparent.
73. As a contributor, I want the project to be open source under MIT, so that the code can be inspected and improved.
74. As a maintainer, I want profile data to use schema versions and migrations, so that future data changes are safe.
75. As a maintainer, I want app data stored per macOS user in Application Support, so that accounts remain isolated.
76. As a maintainer, I want bundled backend versions fixed and checksummed during release builds, so that bug reports are reproducible.
77. As a maintainer, I want Universal 2 app distribution and automatic backend architecture selection, so that Apple Silicon and Intel users receive one package.

## Implementation Decisions

- App name is `Display Recall`; repository/package naming should use `display-recall` and `DisplayRecall`.
- The product is an independent companion for `displayplacer`, not an official `displayplacer` app or replacement.
- The app is a native Swift/SwiftUI macOS app targeting macOS 13+.
- The app is a background menu bar utility by default, with `MenuBarExtra` using a popover/window style for richer controls.
- The app remains running after Profiles windows close; Quit is an explicit menu bar action.
- Display Recall launches as a UI element so the Dock icon does not flash during startup.
- Dock icon visibility has three modes: Automatic, Always Show, and Always Hide.
- Automatic is the default mode: the Dock icon is hidden while only the menu bar utility is running, shown while the main window is open, and hidden again after the main window closes.
- Always Show keeps the Dock icon visible after launch.
- Always Hide keeps the Dock icon hidden even while the main window is open.
- Main daily surface is the menu bar popover. Full management lives in a Profiles window. A small set of app-wide preferences lives in Settings.
- Settings is a single untitled preference group containing only Launch at Login, Dock Icon, Language, and Automatic Apply.
- Settings does not expose shortcut management, backend diagnostics, update checks, Activity Log entry points, diagnostic export, version information, or About information.
- The Settings Automatic Apply row combines the global enabled switch and countdown seconds input.
- Automatic Apply countdown accepts integer values from 0 through 30 seconds.
- Automatic Apply countdown of 0 seconds applies immediately and does not show the pending prevention panel.
- Profiles window uses sidebar + detail layout.
- Profile raw `displayplacer` command is authoritative. Parsed command data is advisory for validation, risk classification, diagnostics, and UI, and must not be required for applying a profile.
- Profile data includes stable UUID, name, optional notes, raw command, display setup fingerprint, display summary, schema version, backend version, creation/update timestamps, and app version metadata.
- Save Current Layout presents a compact naming confirmation before creating a profile. The suggested name is generated from the current language and existing names, but the user can edit it before saving. The confirmation keeps nonessential display details out of the primary path and includes an explicit Set Default option for the current display setup.
- Automatic default rules use `displaySetFingerprint -> profile UUID`.
- Display setup fingerprint prioritizes persistent display IDs, built-in display presence, and enabled display count.
- Serial/contextual IDs, display names, and short IDs are auxiliary data for display, diagnostics, or degraded matching.
- Resolution, coordinates, scaling, rotation, refresh rate, and color depth are not part of the primary automatic matching key.
- Display Recall does not expose current active profile detection. The menu does not use profile checkmarks or other long-lived active indicators to claim that the current layout exactly equals a saved profile.
- Display setup fingerprints are used to group profiles for the current display set and to resolve automatic defaults. They are not exact layout-equality proofs.
- Display change automation is event-triggered only when the current display setup fingerprint changes from the last known fingerprint, with a 5-second user-stoppable popover; rotation, resolution, position, or other same-fingerprint layout changes must not trigger automatic apply.
- The app rereads display state at the end of the countdown before applying.
- Login automation waits for a startup stability window before matching and showing the 5-second popover.
- Automatic Apply can be disabled globally in Settings; manual applies still work while automatic apply is disabled.
- Manual profile applies do not update automatic defaults unless the user explicitly chooses to set the profile as the default for the current display setup.
- High-risk conditions include edited commands, imported profiles on first apply, non-matching display setup, missing display IDs, display-disabling commands, and uncertain mirrored/unsupported parsing.
- High-risk applies show confirmation first and then a 15-second keep/restore prompt after apply. Timeout restores the previous layout.
- Normal matching applies do not show the 15-second keep/restore prompt.
- Failed applies do not auto-rollback; they show failure feedback with manual restore, copy log, and edit profile actions.
- Restore points are limited to the most recent layout, with one undo after restoring.
- Activity Log records structured events and renders them according to the current UI language.
- Activity Log includes display changes, profile matches, countdown cancellation, manual/automatic/hotkey applies, command, exit code, stdout/stderr, restore point reference, backend info, and install/verification events.
- Standard export includes profiles, settings, schema version, and selected/all profile support. It excludes logs and restore points.
- Diagnostic export is separate and may include structured logs, backend info, recent errors, and human-readable summary.
- Import supports one or more profiles, previews conflicts and matching status, allows merge/replace/skip, and marks unmatched profiles without enabling them for automation.
- Profile IDs are UUIDs. Import-as-new generates a new UUID. Replace-existing keeps the local target UUID.
- Same-name import conflicts preserve both profiles by default with a generated suffix.
- Configuration Shortcuts are optional per configuration and default to empty.
- Configuration rows show shortcut status plus a Set/Edit action in the lower-right row area.
- Shortcut capture records a key combination from keyboard input rather than typed shortcut strings.
- Shortcut management stays out of Settings.
- Shortcut bindings are unique inside Display Recall. If a captured shortcut is already bound elsewhere, the user can Modify the capture or Replace the existing binding.
- Display Recall does not warn about common system shortcut conflicts.
- Triggering a Configuration Shortcut is equivalent to manually applying that configuration and must use the same high-risk handling.
- Shortcut registration failures show a simple failure message and record Activity Log details; they do not create persistent status UI or automatic retry loops.
- Successful shortcut applies stay lightweight and do not force-open the main window or show extra success notifications.
- Mirrored display commands are preserved and applied through raw command support; UI may summarize mirroring but does not provide a mirroring editor.
- Display enable/disable commands are preserved and applied but treated as high-risk. No normal UI toggle is provided.
- Primary display is preserved through `origin:(0,0)` command semantics and may be shown in summaries.
- No friendly editors for refresh rate, color depth, mode picker, or full display parameter editing in MVP.
- Backend defaults to a bundled fixed-version `displayplacer` binary.
- System/Homebrew/custom backend paths are advanced fallback options.
- Backend updates only ship with Display Recall app updates; there is no separate backend updater.
- Release build fetches fixed official `displayplacer` release assets with SHA256 verification rather than vendoring source.
- App distribution is Universal 2, signed, notarized, and outside the Mac App Store via GitHub Releases.
- App updates use Sparkle stable channel only, with user-confirmed install and no silent forced updates.
- Third-party acknowledgements include bundled `displayplacer`, Sparkle, versions, project links, license text, and whether binaries were modified.
- Data storage is per-user in Application Support. No iCloud sync or multi-user shared configuration in MVP.
- UI supports English and Simplified Chinese, follows system language by default, and allows manual override: System, English, 简体中文.
- Activity Log event titles localize at render time; technical details such as commands, stderr, IDs, and paths remain unchanged.

## Testing Decisions

- Tests should focus on externally observable behavior and stable contracts, not SwiftUI implementation details.
- Deep modules should be extracted for displayplacer command parsing, display setup fingerprinting, profile storage/migration, automatic matching, risk classification, restore point state, import/export, shortcut binding validation, shortcut capture/registration planning, and structured Activity Log rendering.
- Parser tests should cover persistent/contextual/serial IDs, mirrored ID groups, enabled/disabled commands, primary display origin, optional hz/color depth, malformed commands, and unknown fields.
- Matching tests should verify that display setup fingerprints ignore layout parameters but include enabled display set, built-in display presence, and display count.
- Automation tests should cover startup stability, display-change debounce/countdown, cancellation, manual override, paused state, no-match state, and multi-profile default resolution.
- Risk tests should cover imported profiles, edited commands, non-matching setups, missing IDs, disabled displays, mirrored parsing uncertainty, and normal matching applies.
- Restore tests should cover apply, failed apply, manual restore, and one undo after restore.
- Import/export tests should cover all profiles, selected profiles, conflict strategies, unmatched profiles, UUID handling, schema versions, and future-version rejection.
- Settings/storage tests should cover per-user data paths, language selection, automatic apply enabled/countdown settings, login item preference, and Dock icon visibility preference.
- Shortcut tests should cover capture validation, in-app conflict Modify/Replace behavior, clearing bindings, registration planning, and shortcut-triggered manual apply semantics.
- Automatic Apply tests should cover 0-second immediate application and nonzero countdown panel behavior.
- Dock icon tests should verify policy resolution for Automatic, Always Show, and Always Hide across main-window open and closed states, and packaged app metadata should verify UI-element launch behavior.
- Localization tests should verify English and Simplified Chinese coverage for user-visible strings and that saved profile names do not change when language changes.
- Release/build verification should check bundled backend architecture selection, backend checksum metadata, third-party notices, Sparkle metadata, signing, and notarization in release workflows.
- UI smoke tests should verify setup, first profile creation, menu bar apply, Profiles management, Settings, Activity Log, import/export, and high-risk keep/restore flows.

## Out of Scope

- Visual drag-and-drop display layout editor.
- Full display settings replacement.
- Friendly resolution, refresh rate, color depth, scaling, and mode pickers.
- Profile groups, tags, or complex organization.
- Shell hooks or arbitrary pre/post scripts.
- iCloud sync.
- Mac App Store distribution.
- Main-path Homebrew installation.
- Separate `displayplacer` backend updater.
- Full restore point history.
- Temporary profile concept.
- Manual editing of display ID rule expressions.
- Automatic moving of app windows or other functionality that would require Accessibility permissions outside shortcut needs.
- Silent forced updates.
- MacOS versions below 13.

## Further Notes

- Work name and user-facing product name are `Display Recall`.
- Core object name remains `profile`.
- The app should feel like a quiet macOS system utility rather than a developer tool, while still exposing raw commands and logs in advanced areas.
- Setup should not confuse or discourage users. Bundling `displayplacer` is the preferred way to avoid that.
- The project should be open source under MIT.
- The existing local directory name may remain for now, but formal repo/package naming should move toward `display-recall` / `DisplayRecall`.
