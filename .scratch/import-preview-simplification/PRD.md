Status: ready-for-agent

# 极简导入预览

## Problem Statement

Display Recall 的 Profile 导入预览窗口现在承担了过多职责：它同时展示导入数量、名称、冲突、匹配当前显示器组合、需要重新绑定状态和逐条配置列表。用户在导入前真正需要确认的是“这次会导入多少配置”和“冲突时怎么处理”，而不是审计每个配置的技术状态。当前窗口增加了心智负担，也与 Profile 页按显示器组合自然组织配置的方向不一致。

## Solution

导入预览窗口改为极简确认面板。无冲突时只显示将导入的配置数量，并提供取消和导入。存在同名冲突时，只显示冲突数量，并提供冲突处理策略：保留两者、替换现有、跳过冲突。窗口不展示配置列表、匹配当前组合、需要重新绑定、fingerprint、display summary 或其他技术细节。导入成功后不显示成功提示，只刷新 Profile 列表；失败时显示最轻量的原生错误弹窗。

## User Stories

1. As a Display Recall user, I want the import preview to show only the number of configurations being imported, so that I can confirm the action quickly.
2. As a Display Recall user, I want conflict handling to appear only when conflicts exist, so that simple imports stay simple.
3. As a Display Recall user, I want same-name conflicts summarized by count, so that I understand the risk without reading a long list.
4. As a Display Recall user, I want conflict options labeled 保留两者 / 替换现有 / 跳过冲突, so that the choice is direct and understandable.
5. As a Display Recall user, I want the import preview to hide profile names, display setup matching, and rebind status, so that import does not feel like a technical audit.
6. As a Display Recall user, I want imported configurations to appear in the Profile page after import, so that the main profile surface remains the place for management.
7. As a Display Recall user, I want successful imports to avoid extra completion messages, so that the flow stays quiet.
8. As a Display Recall user, I want import failures to show a small native alert, so that I can see that the import failed without reading diagnostic details.
9. As a Display Recall user, I want import to avoid automatic jumping or special positioning after completion, so that my current Profile page context is preserved.

## Implementation Decisions

- The import preview remains a confirmation step before mutating the profile store.
- The preview UI only exposes total profile count and, when nonzero, conflict count plus conflict strategy.
- Conflict strategy choices remain backed by the existing import conflict strategy model.
- Matching current setup and needs-rebind information remain part of import/export domain behavior where needed, but are no longer presented in the import preview window.
- Profile list refresh follows the existing profile-change synchronization path after import.
- Successful imports do not set a visible status message.
- Import failures are shown with the lightest native alert: one short title, one short message, and a single acknowledgement button.

## Testing Decisions

- Tests should verify observable import preview presentation behavior through a small testable presentation model or public helper, not SwiftUI implementation details.
- Existing Profile import/export tests are prior art for conflict counts, conflict strategies, schema rejection, and matching status domain behavior.
- Domain import/export tests continue to cover that matching status exists and imported nonmatching profiles remain safe; the UI simplification should not remove those domain protections.
- Add focused tests for the presentation contract: no-conflict imports hide conflict controls; conflict imports show only count-level conflict handling; successful import does not produce a visible success message if a testable surface exists.

## Out of Scope

- Changing the backup JSON format.
- Changing import conflict semantics.
- Removing matching status from the import/export domain model.
- Adding per-profile selection during import.
- Adding post-import navigation, highlighting, or automatic expansion beyond existing Profile page rules.
- Adding diagnostic details to import failure UI.

## Further Notes

This PRD supersedes earlier UI expectations that import preview should list profile names, matching status, and needs-rebind status. Those details remain valid for domain safety and tests, but they should not be displayed in the import confirmation window.
