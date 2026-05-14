Status: ready-for-agent

# Risk Confirmation Restore And Failure Handling

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Add risk classification, confirmation, restore point, keep/restore countdown, and failure handling around profile application. The goal is to make dangerous display changes recoverable without making normal matching switches noisy.

## Acceptance criteria

- [ ] Profile applies create a latest restore point before executing.
- [ ] Edited commands, imported first applies, non-matching setups, missing display IDs, display-disabling commands, and uncertain mirrored parsing are treated as high risk.
- [ ] High-risk applies show a confirmation before execution.
- [ ] High-risk applies show a 15-second keep/restore prompt after execution.
- [ ] Timeout from the keep/restore prompt restores the previous layout.
- [ ] Normal matching applies do not show the keep/restore prompt.
- [ ] Failed applies show failure feedback with manual restore, copy log, and edit profile actions.
- [ ] Failed automatic applies stop the current event flow instead of retrying in a loop.
- [ ] Restore operation updates the latest restore point so one undo of restore is possible.

## Blocked by

- `08-automatic-apply-on-display-change-and-login.md`
