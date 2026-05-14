Status: ready-for-agent

# Display List Parsing And Fingerprints

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Parse enough `displayplacer list` output and profile command data to build display summaries, display setup fingerprints, and best-effort current profile recognition. The parser must preserve raw command authority and remain tolerant of unknown or changing output.

## Acceptance criteria

- [ ] Current display setup fingerprint prioritizes persistent display IDs.
- [ ] Built-in display presence and enabled display count are included in matching.
- [ ] Serial/contextual IDs and display names are captured as auxiliary metadata when available.
- [ ] Display summaries can show display count, recognizable names/types, short IDs, resolution/scaling/refresh data when available, origin, rotation, primary display, and mirroring.
- [ ] Mirrored ID groups are recognized without requiring a mirroring editor.
- [ ] `enabled:false` and `enabled:true` profile commands are recognized as high-risk-relevant signals.
- [ ] Best-effort active profile recognition compares key parameters without treating uncertainty as failure.
- [ ] Parser tests cover common profile command forms and malformed/unknown data.

## Blocked by

- `04-profile-storage-schema-and-migrations.md`
