# Third-Party Notices

Display Recall bundles or prepares integration with the following third-party components.

## displayplacer

- Project: displayplacer
- Author/project: Jake Hilborn, https://github.com/jakehilborn/displayplacer
- Version: 1.4.0
- License: MIT License
- Modification status: unmodified official release binaries
- Bundled files:
  - `Sources/DisplayRecallCore/Resources/Backends/displayplacer-apple-v140`
  - `Sources/DisplayRecallCore/Resources/Backends/displayplacer-intel-v140`

Display Recall uses `displayplacer` as its display backend. The bundled binaries are fixed release assets with SHA256 metadata recorded in source for reproducible diagnostics.

## Sparkle

- Project: Sparkle
- Project link: https://sparkle-project.org
- Version: Sparkle 2 release line
- License: MIT License
- Modification status: source dependency / release integration target

Display Recall release metadata and scripts are prepared for Sparkle appcasts and EdDSA-signed update packages. Sparkle is used for user-confirmed updates only; silent forced installation is outside this project's scope.

## License Text

Both Display Recall and the listed third-party projects use the MIT License. See `LICENSE` for the MIT license text used by Display Recall. Third-party copyright notices remain owned by their respective authors.
