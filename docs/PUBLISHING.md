# Publishing Strategy

## GitHub flow
1. `main` protected branch
2. Conventional commits
3. PR checks required (shellcheck + tests)
4. Release process:
   - bump version in `lib/core.sh`
   - update `CHANGELOG.md`
   - tag `vX.Y.Z`
   - GitHub Release notes with binaries/scripts

## Distribution channels
- Curl installer: `curl -fsSL https://.../install.sh | bash`
- Homebrew tap:
  - Formula pulling tagged tarballs
  - CI test `brew install your/tap/gitss`
- apt package:
  - Build `.deb` via `fpm` or `nfpm`
  - Publish in APT repo (Cloudsmith/aptly)

## Shell completions
- Ship bash/zsh completion files in `completions/`
- Optional `gitss completion <shell>` in v3.2

## Versioning
- SemVer
- `v3.0.0` as first public OSS stable
