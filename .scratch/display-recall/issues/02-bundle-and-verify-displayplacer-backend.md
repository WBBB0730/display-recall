Status: ready-for-agent

# Bundle And Verify Displayplacer Backend

## Parent

`.scratch/display-recall/PRD.md`

## What to build

Make Display Recall use a bundled fixed-version `displayplacer` backend by default. The release/build flow should fetch official architecture-specific backend assets, verify checksums, include the correct backend resources, and allow the app to run `displayplacer list` for capability verification. Advanced backend selection can be represented in data/settings but does not need a polished UI in this slice.

## Acceptance criteria

- [x] The app has a backend runner that can execute the bundled `displayplacer`.
- [x] The backend runner can run `list` and capture stdout, stderr, exit code, backend path, and backend architecture.
- [x] Apple Silicon and Intel backend selection is handled automatically or through a Universal backend.
- [x] Backend version and backend source are available to the app for display/logging.
- [x] The build/release preparation path verifies backend SHA256 checksums before bundling.
- [x] The app has a fallback concept for system/custom backend paths without making Homebrew the primary path.
- [x] Backend verification failure produces structured error data usable by setup and Activity Log.

## Blocked by

- `01-bootstrap-native-menu-bar-app.md`
