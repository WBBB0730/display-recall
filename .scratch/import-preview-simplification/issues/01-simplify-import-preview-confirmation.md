Status: completed

# 简化导入预览确认窗口

## What to build

Replace the current import preview window with a minimal confirmation flow. Users should see only the number of configurations that will be imported. If same-name conflicts exist, users should also see the number of conflicts and choose one of the existing conflict strategies: 保留两者, 替换现有, or 跳过冲突. The window should not list profile names or display matching/rebind status. Successful imports should quietly refresh the Profile list; failed imports should show a small native error alert.

## Acceptance criteria

- [x] When importing a backup with no conflicts, the preview shows only the total configuration count plus Cancel and Import actions.
- [x] When importing a backup with conflicts, the preview shows the total configuration count, the conflict count, and the three conflict strategy choices: 保留两者 / 替换现有 / 跳过冲突.
- [x] The import preview does not show per-profile rows, profile names, matching current setup, needs-rebind status, fingerprint, display summary, or explanatory subtitle text.
- [x] Successful import refreshes the Profile list without showing a success status message.
- [x] Failed import shows a light native alert and does not show diagnostic details in the preview.
- [x] Existing import/export domain behavior and conflict strategies continue to pass tests.

## Blocked by

None - can start immediately.
