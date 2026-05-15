Status: ready-for-agent

# Core Apply Feedback And E2E

## Parent

`.scratch/display-recall/PRD.md`

## Why this exists

Manual core-flow verification on 2026-05-14 showed that the real bundled backend can apply the user's real saved profile command successfully, but the app interaction is still not trustworthy enough. The user-reported symptom was "click Apply has no reaction"; after fixing command argument parsing, the backend path works, but the UI still needs explicit, visible feedback and a reliable way to verify the click path.

## Evidence

- Real packaged backend: `dist/Display Recall.app/Contents/Resources/DisplayRecall_DisplayRecallCore.bundle/Backends/displayplacer-apple-v140`
- Real profile: `配置 5`
- Real profile command from `~/Library/Application Support/Display Recall/profiles.json`
- `displayplacer list` succeeded with exit code `0`.
- Applying the real profile command after parsing quoted display arguments succeeded with exit code `0`.
- Older `activity-log.json` entries show pre-fix apply failures with exit code `11`, but the app UI did not make that failure obvious enough.
- Computer Use could not read a key window for the menu-bar-only app; this made the actual click path hard to automate and is itself a testability/interaction gap.

## What to build

Make Apply feel and behave like a core, inspectable operation rather than a silent background action.

Apply is intentionally a one-shot command. Success and failure feedback should be immediate and inspectable, but it should not become a persistent "current profile" checkmark or exact-layout recognition claim.

## Acceptance criteria

- [ ] Clicking Apply from the main window shows an immediate in-progress state on that profile.
- [ ] Apply success shows a visible success state with timestamp or short status text.
- [ ] Apply failure shows a visible error state with exit code and stderr, and links to the exact Activity Log entry.
- [ ] Menu-bar Apply gives visible success/failure feedback, not only an invisible activity-log write.
- [ ] Menu-bar Apply feedback does not persist as a profile checkmark or imply exact current-layout equality.
- [ ] Activity Log records the parsed argument count and backend path for each manual apply.
- [ ] There is a real e2e/dev verification command or script that applies the current saved profile using the packaged app backend and reports exit code, stdout, and stderr.
- [ ] The app can expose/open the main window reliably for verification even when running as a menu-bar app.
