Status: ready-for-agent

# Activity Log And Diagnostic Export

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Implement a lightweight structured Activity Log and diagnostic export. Users should be able to understand why Display Recall changed a layout, why it did not, what command ran, and what backend/error information is relevant for support.

## Acceptance criteria

- [ ] Activity Log records structured event types rather than pre-rendered localized text.
- [ ] Events include timestamp, trigger, profile snapshot, backend info, command, stdout, stderr, exit code, and relevant metadata.
- [ ] Events cover display changes, matching decisions, pending countdowns, cancellations, manual applies, automatic applies, hotkey applies, restores, import/export, backend verification, and failures.
- [ ] Event titles and summaries render in the current UI language.
- [ ] Commands, paths, IDs, stdout, and stderr remain unlocalized.
- [ ] Logs are retained with a bounded policy such as recent count or recent days.
- [ ] Users can copy relevant diagnostic details from an error or log entry.
- [ ] Diagnostic export is separate from profile backup and can include logs, backend info, recent errors, and a readable summary.

## Blocked by

- `09-risk-confirmation-restore-and-failure-handling.md`
