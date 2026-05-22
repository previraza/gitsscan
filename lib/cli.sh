#!/usr/bin/env bash
# shellcheck disable=SC2034

print_help() {
  cat <<EOF2
$PROJECT_NAME v$VERSION

USAGE:
  gitss [directory] [options]

FILTERS:
  --dirty              Show only dirty projects
  --clean              Show only clean projects
  --no-git             Show only projects without Git

FILES:
  -fl, --files-list          Show changed files
  --files-list=N             Show first N changed files
  --files-list=all           Show all changed files

INFO:
  --scan-mode=MODE     Scan mode: mixed|web|git (default: mixed)
  --workers=N          Parallel workers for scan analysis (default: 1)
  --branch             Show current branch
  --ahead              Show ahead/behind status
  --last-commit        Show last commit
  --disk               Show project disk usage
  --summary            Print summary only
  --json               Output JSON (machine readable)
  --no-color           Disable ANSI colors

ACTIONS:
  --fetch              Run git fetch --all --prune
  --pull               Run git pull --ff-only
  --commit             Commit dirty repos with default message
  --commit="message"   Commit with custom message
  --push               Run git push (requires confirmation in safe mode)
                       Can be combined with --commit="message"
  --dry-run            Print actions without executing
  --unsafe             Disable safe confirmations

CONFIG:
  --config=PATH        Load custom config file (default: ~/.gitssrc)

UTILS:
  -h, --help           Show help
  -v, --version        Show version
EOF2
}

parse_cli() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_help; exit 0 ;;
      -v|--version) printf '%s v%s\n' "$PROJECT_NAME" "$VERSION"; exit 0 ;;
      --dirty|--clean|--no-git) MODE="$1"; shift ;;
      -fl|--files-list) FILES_LIST="all"; shift ;;
      --files-list=*)
        local value="${1#*=}"
        if [[ "$value" == "all" ]]; then
          FILES_LIST="all"
        elif [[ "$value" =~ ^[0-9]+$ ]]; then
          FILES_LIST="limit"
          FILES_LIMIT="$value"
        else
          die "--files-list expects a number or 'all'"
        fi
        shift ;;
      --branch) SHOW_BRANCH=true; shift ;;
      --scan-mode=*)
        SCAN_MODE="${1#*=}"
        if [[ "$SCAN_MODE" != "mixed" && "$SCAN_MODE" != "web" && "$SCAN_MODE" != "git" ]]; then
          die "--scan-mode expects 'mixed', 'web' or 'git'"
        fi
        shift ;;
      --scan-mode)
        shift
        [[ $# -gt 0 ]] || die "--scan-mode requires a value: mixed|web|git"
        SCAN_MODE="$1"
        if [[ "$SCAN_MODE" != "mixed" && "$SCAN_MODE" != "web" && "$SCAN_MODE" != "git" ]]; then
          die "--scan-mode expects 'mixed', 'web' or 'git'"
        fi
        shift ;;
      --workers=*)
        WORKERS="${1#*=}"
        [[ "$WORKERS" =~ ^[0-9]+$ ]] || die "--workers expects a positive integer"
        [[ "$WORKERS" -ge 1 ]] || die "--workers expects a value >= 1"
        shift ;;
      --ahead) SHOW_AHEAD=true; shift ;;
      --last-commit) SHOW_LAST_COMMIT=true; shift ;;
      --disk) SHOW_DISK=true; shift ;;
      --summary) SUMMARY_ONLY=true; shift ;;
      --json) OUTPUT_FORMAT="json"; SUMMARY_ONLY=true; shift ;;
      --no-color) NO_COLOR=true; shift ;;
      --fetch) DO_FETCH=true; shift ;;
      --pull) DO_PULL=true; shift ;;
      --commit) DO_COMMIT=true; shift ;;
      --commit=*) DO_COMMIT=true; COMMIT_MSG="${1#*=}"; shift ;;
      --push) DO_PUSH=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      --unsafe) SAFE_MODE=false; shift ;;
      --config=*) CONFIG_FILE="${1#*=}"; shift ;;
      -*) die "Unknown option: $1" ;;
      *) TARGET_DIR="$1"; shift ;;
    esac
  done

  [[ -d "$TARGET_DIR" ]] || die "Directory does not exist: $TARGET_DIR"
}
