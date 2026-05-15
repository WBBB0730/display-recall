Status: ready-for-agent

# Profile Groups Simplification PRD

## Problem Statement

Display Recall 的 Profile 模块已经能完成保存、应用、自动默认、导入导出、删除、重命名、notes、raw command 编辑和状态展示，但这些能力被同时铺在一个 sidebar + detail 管理界面里。用户打开主窗口时，会被迫理解太多对象属性和维护动作，心智负担明显超过一个菜单栏显示器布局工具应有的复杂度。

用户真正想做的是：在当前显示器组合下，保存一个配置，选择一个配置自动应用，必要时手动应用、重命名或删除配置。Profile 模块应该围绕这个日常路径重新组织，而不是像数据库表单一样暴露 profile 的所有字段。

## Solution

将 Profile 模块重构为以“显示器组合”为一等实体的单页分组列表。

用户看到的主模型变为：

- 一个显示器组合代表一套显示器连接环境。
- 一个显示器组合下面可以有多个配置。
- 每个配置都可以手动“应用配置”。
- 每个显示器组合最多只有一个配置打开“自动应用配置”开关。
- 打开一个配置的自动应用开关，会自动关闭同组其他配置的自动应用开关。

Profile 主界面不再展示右侧详情编辑器，不再常驻展示 fingerprint、display summary、notes、raw command、高风险标记或“默认配置”概念。低频动作放进更多菜单。显示器组合支持重命名，并且即使组内 profile 被删空也保留实体；非当前且空的显示器组合默认隐藏，等用户切换到该显示器组合时再显示。

## User Stories

1. As a Display Recall user, I want profiles grouped by display setup, so that I can understand which configurations belong to my current monitor environment.
2. As a Display Recall user, I want the current display setup group expanded by default, so that the most relevant profiles are immediately visible.
3. As a Display Recall user, I want non-current display setup groups collapsed by default, so that historical configurations do not distract me.
4. As a Display Recall user, I want non-current empty display setup groups hidden, so that the list does not show irrelevant empty containers.
5. As a Display Recall user, I want an empty current display setup group to remain visible, so that I can save a configuration for the setup I am currently using.
6. As a Display Recall user, I want display setup groups to have friendly names, so that I do not have to read display hardware summaries or fingerprints.
7. As a Display Recall user, I want default display setup group names to be generated automatically, so that I can start without naming every group.
8. As a Display Recall user, I want to rename a display setup group, so that names can match my own language such as office desk, home desk, or meeting room.
9. As a Display Recall user, I want renamed display setup groups to keep their names even if all profiles inside are deleted, so that my naming work is not lost.
10. As a Display Recall user, I want existing profiles to be automatically grouped by their display setup fingerprint, so that old data continues to work after the redesign.
11. As a Display Recall user, I want saving the current layout to create the current display setup group if needed, so that I do not have to create groups manually.
12. As a Display Recall user, I want each profile row to show only the profile name and primary actions, so that the list stays simple.
13. As a Display Recall user, I want each profile row to have an Apply Configuration action, so that restoring a layout is direct.
14. As a Display Recall user, I want profile apply to stay available even for non-current display setup groups, so that I can intentionally apply an older or different layout.
15. As a Display Recall user, I want non-current or otherwise risky applies to confirm before running, so that powerful actions remain safe without cluttering the list.
16. As a Display Recall user, I want an Automatic Apply Configuration switch on each profile, so that I can choose which profile should run automatically for that display setup.
17. As a Display Recall user, I want turning on automatic apply for one profile to turn it off for other profiles in the same display setup group, so that there is no ambiguity.
18. As a Display Recall user, I want turning off automatic apply for a profile to leave the group with no automatic profile, so that automation can be disabled for that display setup.
19. As a Display Recall user, I do not want to see "default profile" wording, so that I only think in terms of automatic apply.
20. As a Display Recall user, I want a primary Save Current Layout action, so that creating a new configuration remains obvious.
21. As a Display Recall user, I want the empty state to only offer Save Current Layout as the main action, so that first use is clear.
22. As a Display Recall user, I want the profile row More menu to contain Export, Rename, and Delete, so that secondary actions are available without visual noise.
23. As a Display Recall user, I want the list More menu to contain Import Configurations and Export Configurations, so that backup and restore remain discoverable but not dominant.
24. As a Display Recall user, I want list export and row export to use the same backup format, so that exported data behaves predictably.
25. As a Display Recall user, I want profile rename to use a small focused dialog, so that editing a name does not require a detail page.
26. As a Display Recall user, I want display setup group rename to use the same small focused dialog pattern, so that naming behavior is consistent.
27. As a Display Recall user, I want delete confirmation to be short and native, so that destructive actions are safe but not heavy.
28. As a Display Recall user, I want deleting an automatic profile to also remove its automatic apply rule, so that automation does not point at deleted data.
29. As a Display Recall user, I want deleting the last profile in a group to keep the display setup group entity, so that the group name can return when that display setup is current.
30. As a Display Recall user, I do not want profile search in the simplified UI, so that the page remains focused on grouping rather than database browsing.
31. As a Display Recall user, I do not want notes editing in the main Profile UI, so that profiles feel like executable configurations rather than records.
32. As a Display Recall user, I do not want raw displayplacer command editing in the main Profile UI, so that advanced implementation details stay out of the daily path.
33. As a Display Recall user, I want import/export data to preserve existing profile fields, notes, commands, and display metadata, so that hidden UI does not destroy data.
34. As a Display Recall user, I want old imported or edited-command profiles to retain their safety behavior, so that simplifying the UI does not make applying risky profiles unsafe.
35. As a Display Recall user, I want fold state to reset predictably when opening the window, so that the current setup is always easy to find.
36. As a Display Recall user, I do not want fold state persisted, so that the app avoids surprising stale navigation state.
37. As a Display Recall user, I want generated profile names and generated display setup group names to use the current app language, so that new objects fit my language.
38. As a Display Recall user, I want existing profile names and group names not to change when switching language, so that my edited labels remain stable.
39. As a maintainer, I want display setup grouping extracted into a testable module, so that UI simplification is driven by stable behavior.
40. As a maintainer, I want profile storage migration tested, so that existing users' profiles are grouped without data loss.
41. As a maintainer, I want automatic apply switch behavior tested independently of SwiftUI, so that the single-choice rule stays correct.
42. As a maintainer, I want display setup group visibility rules tested independently of SwiftUI, so that current, non-current, empty, and non-empty groups render predictably.
43. As a maintainer, I want profile deletion behavior to continue using existing cleanup rules, so that automatic rules, shortcut bindings, and logs remain consistent.

## Implementation Decisions

- The main Profile UI becomes a single-page grouped list rather than a sidebar + detail editor.
- A new display setup group entity is introduced as a first-class stored concept.
- A display setup group represents one `DisplaySetupFingerprint` and provides a user-editable name.
- Display setup group v1 fields are limited to `id`, `fingerprint`, `name`, `createdAt`, and `updatedAt`.
- Display setup groups do not have icons, colors, notes, custom ordering, a details page, manual merge, manual split, or delete UI in this PRD.
- Existing profiles are grouped by `displaySetupFingerprint` during load or migration.
- Saving the current layout lazily creates a display setup group when the current fingerprint has no group.
- Profile data continues to store `displaySetupFingerprint`; the group entity organizes profiles but does not replace the profile's fingerprint.
- Existing `automaticDefaultRules` remain the underlying storage for automatic apply rules.
- UI copy stops saying "default profile" or "Set/Clear Default" in the Profile module.
- UI copy uses "Automatic Apply Configuration" semantics for the per-profile switch.
- Turning on a profile's automatic apply switch sets the rule for that profile's display setup fingerprint.
- Turning on one profile's automatic apply switch clears or replaces any same-fingerprint rule for sibling profiles.
- Turning off the active profile's automatic apply switch clears the rule for that display setup fingerprint.
- Display setup group naming uses a separate sequence from profile naming.
- Generated Simplified Chinese names use the pattern `显示器组合 1`, `显示器组合 2`, etc.
- Generated English names use the pattern `Display Set 1`, `Display Set 2`, etc.
- Generated names start at 1 and choose the first non-conflicting name.
- Existing group names and profile names are not mutated by language changes.
- The current display setup group is expanded by default.
- Non-current non-empty display setup groups are visible and collapsed by default.
- Non-current empty display setup groups are hidden.
- Current empty display setup group is visible and shows an empty state.
- Fold state is local UI state only and is not persisted.
- Profile rows show a simple profile name plus actions; hardware summaries and fingerprints are not shown in the default row.
- Profile row primary actions are Automatic Apply Configuration, Apply Configuration, and More.
- Profile row More menu contains Export Configuration, Rename, and Delete.
- List-level More menu contains Import Configurations and Export Configurations.
- List export exports all profiles using the existing backup format.
- Row export exports a single profile using the same backup format.
- Multi-select export is not exposed in the simplified Profile UI.
- Rename actions use a small focused modal with one text field and Cancel/Save actions.
- Delete actions use native confirmation with concise copy.
- Delete keeps existing cleanup semantics for automatic apply rules, shortcut bindings, and activity log entries.
- Deleting the last profile in a group does not delete the display setup group entity.
- Profile search is removed from the simplified Profile UI.
- Notes editing is removed from the main Profile UI, but notes data remains stored and import/exported.
- Raw `displayplacer` command editing is removed from the main Profile UI, but command data remains authoritative and import/exported.
- Rebind to Current Displays is not exposed in the simplified Profile UI for this PRD.
- Non-current group profile applies remain allowed, but use risk confirmation before running.
- Imported profile, edited command, non-matching setup, and other existing high-risk behavior remain enforced before apply.
- This PRD supersedes the earlier Profile window direction that used sidebar + detail as the primary management surface.

### Modules To Build Or Modify

- Profile storage and migration: add display setup groups to the profile store document and migrate existing profile documents by fingerprint.
- Display setup group manager: create, rename, look up, and maintain group entities; provide first-available generated names.
- Profile grouping projection: produce current, non-current, empty, visible, hidden, expanded, and collapsed groups from store data and current fingerprint.
- Automatic apply rule adapter: expose the existing `automaticDefaultRules` as per-profile automatic apply switches without changing the underlying rule meaning.
- Profile list UI: replace the current split detail UI with a grouped list surface and menus.
- Profile actions: preserve save current layout, apply, import, export, rename, delete, and activity logging through the new UI.
- Localization catalog: add user-visible strings for display setup groups, automatic apply configuration, grouped empty states, menu items, and rename dialogs.

## Testing Decisions

- Tests should focus on external behavior and stable state transformations, not SwiftUI layout internals.
- Existing profile storage tests are the prior art for schema versioning, migration, and persistence.
- Existing profile management tests are the prior art for save, rename, automatic rule, and delete cleanup behavior.
- Existing import/export tests are the prior art for preserving backup format and profile data.
- Add migration tests that existing profiles with the same fingerprint create one display setup group and profiles with different fingerprints create separate groups.
- Add migration tests that existing automatic rules continue to point to the same profile IDs after groups are created.
- Add generated-name tests for display setup groups in English and Simplified Chinese.
- Add generated-name tests that group names use a separate sequence from profile names.
- Add lazy-create tests for saving current layout when no group exists for the current fingerprint.
- Add grouping projection tests for current non-empty, current empty, non-current non-empty, and non-current empty groups.
- Add grouping projection tests that current group is expanded by default and non-current groups are collapsed by default.
- Add automatic apply switch tests that enabling one profile disables siblings in the same fingerprint group.
- Add automatic apply switch tests that disabling the active switch clears the matching rule.
- Add automatic apply switch tests that profiles in different groups do not affect each other.
- Add delete tests that deleting the last profile does not delete the group entity.
- Add delete tests that deleting an automatic profile clears the automatic rule and preserves existing shortcut cleanup behavior.
- Add import/export tests that exports still include all profile data required by the existing backup format.
- UI smoke coverage, where practical, should verify that the simplified Profile page exposes Save Current Layout, group rows, profile rows, automatic apply switch, apply, row More menu, and list More menu.

## Out of Scope

- Reworking the Settings page.
- Reworking the Activity Log page.
- Reworking the menu bar menu.
- Reworking first-run setup beyond interactions required by display setup group creation.
- Display setup group delete UI.
- Display setup group sort order.
- Display setup group icons, colors, notes, or details page.
- Manual display setup group merge or split.
- Multi-select export entry in the simplified UI.
- Search in the Profile module.
- Notes editing in the main Profile UI.
- Raw `displayplacer` command editing in the main Profile UI.
- A new advanced profile editor.
- Visual drag-and-drop display layout.
- Exact current profile detection.
- Persisting expanded/collapsed group state.
- Changing the underlying meaning of `automaticDefaultRules`.
- Changing the backup format for single-profile versus all-profile export beyond adding any required display setup group data through schema migration.

## Further Notes

- This PRD intentionally narrows the next implementation to Profile module simplification.
- The user explicitly asked to "注意收敛问题"; implementation should avoid opportunistic redesign of unrelated surfaces.
- The app should continue to feel like a quiet macOS utility: fast to scan, light on explanatory copy, and focused on the primary action.
- Hidden advanced data must not be destroyed. Removing notes and raw command editing from the main UI means hiding those controls, not deleting stored fields.
- This PRD may require follow-up implementation issues before coding, but it is ready as the source PRD for that breakdown.
