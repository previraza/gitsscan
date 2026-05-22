# Architecture Vision

## Core modules
- Scanner Engine: filesystem traversal, detector rules, deduplication by git root.
- Status Engine: git status/ahead/behind/last commit/disk metadata.
- Action Engine: fetch/pull/commit/push with safe policy.
- Output Engine: text/json/html render adapters.

## Plugin system proposal
- Directory: `plugins.d/*.sh`
- Contract functions:
  - `plugin_name`
  - `plugin_scan <repo_path>`
  - `plugin_enrich_json <repo_path>`
- Hook points:
  - `pre_scan`, `post_scan`, `pre_action`, `post_action`, `pre_render`

## Providers and adapters
- Providers: external data fetchers (Git, Docker, Nginx, Systemd, Kubernetes)
- Adapters: normalize provider output into GitSScan schema
- Scanner rules: declarative matchers in `rules/*.rule`:
  - marker files
  - glob patterns
  - optional shell probe command

## Driver strategy
- Git driver (native today)
- Docker driver: container status and compose project mapping
- Nginx driver: parse enabled sites, map root/domain to repository
- Monitoring driver: output Prometheus textfile and webhook events

## Config strategy (`~/.gitssrc`)
- `GITSS_DEFAULT_TARGET`
- `GITSS_EXCLUDES`
- `GITSS_SAFE_MODE=true`
- `GITSS_OUTPUT=text|json|html`
- `GITSS_PARALLELISM=4`

## Data model (JSON)
- summary: totals
- projects[]:
  - path
  - status
  - pending
  - git metadata
  - provider metadata (docker/nginx)
