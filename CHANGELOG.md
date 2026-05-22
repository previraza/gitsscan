# Changelog

All notable changes to this project are documented in this file.

## [3.0.1] - 2026-05-22

### Added
- Automated GitHub Releases workflow (tag-driven) with `.tar.gz`, checksums and `.deb` packaging.
- Distribution docs (GitHub releases, Homebrew tap flow, Debian `.deb` via `nfpm`).
- Local formatter script `scripts/fmt.sh` aligned with CI (`shfmt -i 2`).

### Changed
- CI now ignores release tags and runs on `main` only; updated to `actions/checkout@v5`.

### Fixed
- Ignore build artifacts in `dist/`.
- ShellCheck warnings in modular globals and tests; hardened scanner guard for disappearing target dirs.

## [3.0.2] - 2026-05-22

### Fixed
- `install.sh` now installs `lib/` under the prefix (`/usr/local/lib/gitss/lib`) and `bin/gitss` can locate it at runtime.

## [3.0.0] - 2026-05-22

### Added
- Professional repository layout (`bin/`, `lib/`, `docs/`, `tests/`, `scripts/`, `examples/`).
- Modular Bash architecture (CLI parser, scanner, git operations, output formatter).
- New `--json` output mode for automation pipelines.
- Safe mode confirmations for `--push`.
- Config loading via `~/.gitssrc` or `--config=...`.
- Installation and uninstallation scripts.
- Shell completions starter for bash/zsh.
- CI workflow for linting, formatting, and smoke tests.

### Changed
- Main executable moved to `bin/gitss`.
- Internal logic refactored for Linux/macOS/WSL compatibility.

### Security
- Push confirmation enforced in safe mode unless `--unsafe`.
- `--dry-run` support preserved and recommended for write operations.

## [2.0.0] - 2026-05-22
- Legacy single-file script baseline.
