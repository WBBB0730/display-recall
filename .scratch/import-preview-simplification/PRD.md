Status: ready-for-agent

# 极简导入预览

## Problem Statement

Display Recall 的 Profile 导入预览窗口现在承担了过多职责：它同时展示导入数量、名称、冲突、匹配当前显示器组合、需要重新绑定状态和逐条配置列表。用户在导入前真正需要确认的是“这次会导入多少配置”和“冲突时怎么处理”，而不是审计每个配置的技术状态。当前窗口增加了心智负担，也与 Profile 页按显示器组合自然组织配置的方向不一致。

## Solution

导入预览窗口改为极简确认面板。无冲突时只显示将导入的配置数量，并提供取消和导入。存在 UUID 冲突时，只显示冲突数量，并提供冲突处理策略：保留两者、替换现有、跳过冲突。配置名称只是用户标签，可以重复，不用于判断冲突，也不会因为保留两者而自动添加后缀。窗口不展示配置列表、匹配当前组合、需要重新绑定、fingerprint、display summary 或其他技术细节。导入成功后不显示成功提示，只刷新 Profile 列表；失败时显示最轻量的原生错误弹窗。

## User Stories

1. As a Display Recall user, I want the import preview to show only the number of configurations being imported, so that I can confirm the action quickly.
2. As a Display Recall user, I want conflict handling to appear only when conflicts exist, so that simple imports stay simple.
3. As a Display Recall user, I want duplicate UUID conflicts summarized by count, so that I understand when an imported configuration is the same historical object as an existing one.
4. As a Display Recall user, I want conflict options labeled 保留两者 / 替换现有 / 跳过冲突, so that the choice is direct and understandable.
5. As a Display Recall user, I want the import preview to hide profile names, display setup matching, and rebind status, so that import does not feel like a technical audit.
6. As a Display Recall user, I want imported configurations to appear in the Profile page after import, so that the main profile surface remains the place for management.
7. As a Display Recall user, I want successful imports to avoid extra completion messages, so that the flow stays quiet.
8. As a Display Recall user, I want import failures to show a small native alert, so that I can see that the import failed without reading diagnostic details.
9. As a Display Recall user, I want import to avoid automatic jumping or special positioning after completion, so that my current Profile page context is preserved.
10. As a Display Recall user, I want configurations with the same name but different UUIDs to import without conflict, so that repeated labels remain allowed.
11. As a Display Recall user, I want 保留两者 to keep the imported name unchanged, so that importing does not invent confusing suffixes.
12. As a Display Recall user, I want non-conflicting imports to preserve their UUIDs, so that later imports can detect whether an item is already present.

## Implementation Decisions

- The import preview remains a confirmation step before mutating the profile store.
- The preview UI only exposes total profile count and, when nonzero, conflict count plus conflict strategy.
- Conflict strategy choices remain backed by the existing import conflict strategy model.
- Import conflicts are determined by profile UUID only.
- Profile names are not unique identifiers and are allowed to repeat.
- 保留两者 keeps both the existing profile and the imported profile; the imported copy receives a new UUID only when the imported UUID conflicts with an existing profile, and its name remains unchanged.
- 替换现有 replaces the local profile with the matching UUID and preserves that UUID.
- 跳过冲突 skips imported profiles whose UUIDs already exist locally.
- Non-conflicting imported profiles preserve their imported UUID.
- Matching current setup and needs-rebind information remain part of import/export domain behavior where needed, but are no longer presented in the import preview window.
- Profile list refresh follows the existing profile-change synchronization path after import.
- Successful imports do not set a visible status message.
- Import failures are shown with the lightest native alert: one short title, one short message, and a single acknowledgement button.

## Testing Decisions

- Tests should verify observable import preview presentation behavior through a small testable presentation model or public helper, not SwiftUI implementation details.
- Existing Profile import/export tests are prior art for conflict counts, conflict strategies, schema rejection, UUID preservation, and matching status domain behavior.
- Domain import/export tests continue to cover that matching status exists and imported nonmatching profiles remain safe; the UI simplification should not remove those domain protections.
- Add focused tests for the presentation contract: no-conflict imports hide conflict controls; conflict imports show only count-level conflict handling; successful import does not produce a visible success message if a testable surface exists.
- Add focused tests for UUID-based conflict behavior: same-name/different-UUID imports do not conflict, same-UUID imports do conflict, 保留两者 does not rename, 替换现有 replaces by UUID, and 跳过冲突 skips by UUID.

## Out of Scope

- Changing the backup JSON format.
- Removing matching status from the import/export domain model.
- Adding per-profile selection during import.
- Adding post-import navigation, highlighting, or automatic expansion beyond existing Profile page rules.
- Adding diagnostic details to import failure UI.

## Further Notes

This PRD supersedes earlier UI expectations that import preview should list profile names, matching status, and needs-rebind status. Those details remain valid for domain safety and tests, but they should not be displayed in the import confirmation window.
