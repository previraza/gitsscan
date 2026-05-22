# Security Strategy

## Defaults
- Safe mode enabled by default.
- Confirmation prompt before `--push`.
- `--dry-run` available for all write operations.

## Hard protections
- No `git reset --hard` operation in CLI surface.
- No destructive bulk command shortcuts.
- Pull limited to `--ff-only`.

## Policy recommendations
- Require clean working tree before auto-pull in CI usage.
- Use deploy keys/tokens with least privilege.
- Log every write action in future `--audit-log` output.

## Future
- `--require-dry-run` policy flag for team environments.
- signed release checksum verification in install script.
