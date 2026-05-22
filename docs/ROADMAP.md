# Roadmap

## v3.x
- Stable modular CLI core
- JSON output for automation
- Safe mode for write operations
- CI + lint + smoke tests

## v3.1
- `--html-report` export
- Watch mode (`--watch 5s`)
- Interactive mode (`--interactive`) with bulk actions

## v3.2
- Docker provider (`docker compose ps` and container health mapping)
- Nginx provider (vhost discovery and domain->repo mapping)
- Local cache index (`~/.cache/gitss/index.json`)

## v4.0
- TUI dashboard (status board, filters, action panel)
- Plugin SDK (`plugins.d/` with hooks)
- Parallel scanning workers with bounded concurrency

## v4.x
- Monitoring integrations (Prometheus textfile, webhook, Slack)
- Package distribution (Homebrew tap, deb/rpm)
- Shell completion auto-install
