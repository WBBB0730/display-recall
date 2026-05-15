Status: ready-for-agent

# Profile Action Surface Simplification PRD

## Problem Statement

Display Recall 的 Profile 列表已经被简化成按显示器组合分组的主界面，但操作入口仍然有一部分藏在更多菜单里。顶部的列表级操作、显示器组合级操作、配置级操作都使用相似的三点菜单，会让用户在不同层级之间反复猜测“这里面有什么”。

用户现在的直觉是：列表上方的导入、导出属于全局列表动作，应该常驻显示为文本按钮；显示器组合和单个配置的低频动作才应该贴近对象本身，并且只在需要时出现。现有更多菜单虽然收窄了视觉噪音，但仍然让操作层级显得不够直接，也让字体、箭头、对齐等系统菜单细节不断分散注意力。

## Solution

将 Profile 主界面的操作入口拆成两层：

- 列表级操作常驻在列表上方，用文本按钮呈现。
- 显示器组合和配置行的对象级操作在 hover 或焦点状态下显示为图标按钮。

顶部常驻按钮保留“保存当前布局”作为主按钮，并把“导入”“导出”从顶部更多菜单中拆出来。显示器组合行只显示重命名组合这类对象级动作。配置行显示重命名、导出、删除等对象级图标按钮。配置的核心动作“应用配置”和“自动应用配置”继续常驻，因为它们是日常主路径。

这样用户无需打开菜单就能看到全局能力，也能在鼠标经过某个组合或配置时直接看到该对象可做的动作。

## User Stories

1. As a Display Recall user, I want Save Current Layout to remain a prominent button, so that creating a new configuration is always obvious.
2. As a Display Recall user, I want Import to be visible as a top-level text button, so that I do not need to search inside a More menu.
3. As a Display Recall user, I want Export to be visible as a top-level text button, so that backing up configurations is discoverable.
4. As a Display Recall user, I want list-level actions grouped together above the profile list, so that I understand they apply to all configurations.
5. As a Display Recall user, I want display setup group actions to appear near the group name, so that I understand they affect that group.
6. As a Display Recall user, I want profile actions to appear near the profile row, so that I understand they affect that one configuration.
7. As a Display Recall user, I want secondary row actions hidden until hover, so that the list stays calm while scanning.
8. As a Display Recall user, I want secondary row actions visible when a row is focused or selected, so that keyboard and accessibility use does not depend only on hover.
9. As a Display Recall user, I want Rename Display Setup to be a small icon action, so that renaming is available without dominating the group row.
10. As a Display Recall user, I want Rename Configuration to be a small icon action, so that profile naming is quick and direct.
11. As a Display Recall user, I want Export Configuration to be a small icon action on the row, so that exporting one profile is clearly different from exporting all.
12. As a Display Recall user, I want to enter a multi-select mode, so that I can export several configurations without exporting everything.
13. As a Display Recall user, I want selected configurations to be exported through the same backup format, so that selected export behaves like other exports.
14. As a Display Recall user, I want multi-select controls hidden outside selection mode, so that the normal profile list stays simple.
15. As a Display Recall user, I want exported files to use a plain `.json` filename, so that the file type is obvious and conventional.
16. As a Display Recall user, I want the native save dialog to use system/AppKit localization, so that Display Recall does not mix app-controlled copy with system-controlled panel labels.
17. As a Display Recall user, I want Delete Configuration to be a small destructive icon action on the row, so that deleting is available but visually secondary.
18. As a Display Recall user, I want Delete Configuration to keep its native confirmation, so that accidental deletion remains guarded.
19. As a Display Recall user, I want icon buttons to have consistent size and alignment, so that the list feels designed rather than assembled.
20. As a Display Recall user, I want icon buttons to use familiar symbols, so that I do not have to read explanatory text for common actions.
21. As a Display Recall user, I want icon buttons to expose tooltips, so that unclear icons can be understood on hover.
22. As a Display Recall user, I want the Apply Configuration button to stay text-based and prominent, so that the main action remains unmistakable.
23. As a Display Recall user, I want Automatic Apply Configuration to remain visible, so that automation state can be understood without opening anything.
24. As a Display Recall user, I want Import and Export text button labels to be localized, so that the top action bar matches the app language.
25. As a Display Recall user, I want icon tooltips and confirmation copy localized, so that secondary actions still feel native.
26. As a Display Recall user, I want hover actions not to shift row height or card width, so that the list does not jump while I move the pointer.
27. As a Display Recall user, I want long profile names to continue truncating cleanly, so that action buttons remain aligned.
28. As a Display Recall user, I want display setup group names to continue using display-layer localization for default names, so that this change does not regress naming.
29. As a Display Recall user, I want Import and Export to keep the existing backup behavior, so that moving the buttons does not change data semantics.
30. As a Display Recall user, I want single-profile Export to keep the same backup format as all-profile Export, so that exports remain predictable.
31. As a Display Recall user, I want Delete to keep cleaning up automatic apply rules and shortcuts, so that splitting actions out of the menu does not break existing guarantees.
32. As a Display Recall user, I want the page to remain visually quiet, so that utility workflows stay fast.
33. As a maintainer, I want row action visibility modeled in a small UI component, so that hover/focus behavior is not duplicated across group and profile rows.
34. As a maintainer, I want action definitions separated from visual placement, so that the same rename/export/delete behavior can be tested and reused.
35. As a maintainer, I want this refactor to avoid storage changes, so that the UI iteration remains low risk.
36. As a maintainer, I want tests to cover action semantics rather than hover implementation details, so that tests remain stable through visual refinements.
37. As a maintainer, I want the implementation to avoid introducing a new advanced editor or menu architecture, so that the change stays focused.

## Implementation Decisions

- Remove the list-level More menu from the Profile page.
- Add top-level text buttons for Import and Export next to Save Current Layout.
- Keep Save Current Layout as the primary prominent action.
- Treat Import and Export as list-level actions that apply to the profile collection.
- Keep list-level Export mapped to all-profile export.
- Keep row-level Export mapped to single-profile export.
- Add a lightweight multi-select mode for selected-profile export.
- Keep multi-select controls hidden when selection mode is off.
- Keep selected-profile export mapped to the existing multiple-profile export selection.
- Use a plain `.json` default filename for backup exports.
- Do not override NSSavePanel title, confirmation button, message, or filename label; let the native save dialog follow system/AppKit localization while Display Recall only supplies the suggested `.json` filename and allowed content type.
- Package English and Simplified Chinese as main app bundle localizations, and allow mixed localizations so native AppKit panels can use system-provided localized labels.
- Do not show an inline Profile-window success status after a completed export; keep export history in Activity Log and reserve the inline status area for actionable failures.
- Preserve the existing backup document semantics and conflict preview behavior.
- Replace display setup group More menus with hover/focus icon actions.
- Replace profile row More menus with hover/focus icon actions.
- Use familiar symbols for profile row actions: rename, export, delete.
- Use a familiar rename symbol for display setup group rename.
- Add localized tooltips or accessibility labels for all icon-only actions.
- Keep Apply Configuration as a text button, not an icon-only action.
- Keep Automatic Apply Configuration visible as a switch, not hidden behind hover.
- Keep destructive delete confirmation unchanged in semantics, but allow the entry point to become an icon button.
- Preserve the existing rename sheet for both display setup groups and profiles.
- Preserve the existing save-current-layout sheet shared with the status bar menu.
- Do not change display setup group storage, profile storage, automatic apply rule storage, or backup schema.
- Do not add a new details panel.
- The hover/focus action surface should avoid layout shift by reserving a stable action area or by using opacity changes inside fixed dimensions.
- Keyboard focus or selected-row state should reveal the same actions as hover, so the UI is not mouse-only.
- The action surface should remain consistent with the macOS utility feel: compact, direct, and not explanatory-heavy.

### Modules To Build Or Modify

- Profile list action bar: expose Save Current Layout, Import, and Export as top-level controls.
- Profile selection mode: expose selected-profile export without making checkboxes permanent visual noise.
- Display setup group row view: provide a compact hover/focus action area for group rename.
- Profile row view: provide a compact hover/focus action area for rename, export, and delete.
- Shared icon action component: encapsulate icon sizing, hover/focus visibility, tooltip/accessibility label, and alignment.
- Profile action handlers: reuse existing save, import, export, rename, delete, apply, and automatic apply behavior without changing domain semantics.
- Localization catalog: ensure all new text buttons, tooltips, and accessibility labels have English and Simplified Chinese strings.

## Testing Decisions

- Good tests should verify user-visible behavior and stable state transformations, not SwiftUI hover implementation details.
- Existing profile management tests remain the prior art for rename, delete cleanup, apply, and automatic apply semantics.
- Existing profile import/export tests remain the prior art for all-profile export, single-profile export, import preview, conflict handling, and hidden field preservation.
- Existing localization tests remain the prior art for ensuring English and Simplified Chinese coverage.
- Add or update tests that list-level export still exports all profiles after moving the entry point.
- Add or update tests that row-level export still exports only one profile after moving the entry point.
- Add or update tests that multiple-profile export still exports exactly the selected profiles.
- Add or update tests that delete still removes automatic apply rules and shortcut bindings after moving the entry point.
- Add localization coverage for new top-level Import/Export labels and icon-only action labels.
- Prefer small model or helper tests if an action-surface component introduces a testable action model.
- UI layout details such as exact hover opacity, icon pixel size, or animation timing should be verified manually through the built app rather than brittle tests.

## Out of Scope

- Changing the underlying backup format.
- Changing profile storage or display setup group storage.
- Changing automatic apply rule semantics.
- Adding a profile details page.
- Reintroducing notes editing or raw command editing to the main Profile UI.
- Adding visual drag-and-drop display layout.
- Adding exact current-profile detection.
- Reworking the menu bar status item menu.
- Reworking Settings, Activity Log, first-run setup, or pending apply panels.
- Persisting hover, focus, or selected-row action visibility.
- Replacing the current save-current-layout dialog.
- Designing a full custom icon system beyond the needed row actions.

## Further Notes

- This PRD intentionally follows the user's latest direction: list-level actions should be visible text buttons; object-level actions should be hover/focus icon buttons.
- The goal is to reduce reliance on generic More menus, not to add another layer of interaction complexity.
- Implementation should be conservative because the current profile grouping, import/export, delete, rename, and automatic apply behavior has already been stabilized with tests.
- The next step after this PRD should be breaking it into issues before implementation.
