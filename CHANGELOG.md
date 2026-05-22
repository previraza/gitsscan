# Changelog

All notable changes to this project are documented in this file.

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
