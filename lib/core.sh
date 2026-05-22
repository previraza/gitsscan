#!/usr/bin/env bash

VERSION="3.0.0"
PROJECT_NAME="GitSScan"

TARGET_DIR="."
MODE="all"
FILES_LIST="none"
FILES_LIMIT=10
SUMMARY_ONLY=false
NO_COLOR=false
SHOW_BRANCH=false
SHOW_AHEAD=false
SHOW_LAST_COMMIT=false
SHOW_DISK=false
OUTPUT_FORMAT="text"
SCAN_MODE="mixed"
WORKERS=1
DO_FETCH=false
DO_PULL=false
DO_COMMIT=false
DO_PUSH=false
DRY_RUN=false
SAFE_MODE=true
COMMIT_MSG="chore: auto backup changes"
CONFIG_FILE="${HOME}/.gitssrc"

CLEAN_COUNT=0
DIRTY_COUNT=0
NOGIT_COUNT=0
PENDING_FILES_TOTAL=0
TOTAL_DISPLAYED=0
ACTION_ERRORS=0

declare -a SCAN_RESULTS=()
declare -A SEEN_GIT_ROOTS=()
declare -A SEEN_NO_GIT_DIRS=()

auto_detect_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    REALPATH_CMD="realpath"
  elif command -v grealpath >/dev/null 2>&1; then
    REALPATH_CMD="grealpath"
  else
    REALPATH_CMD=""
  fi
}

auto_detect_realpath

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

error() {
  printf 'Error: %s\n' "$*" >&2
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  error "$*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

validate_runtime() {
  local required missing cmd
  required=(bash git find du wc tr sed head awk dirname basename)
  missing=()
  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    die "Missing required commands: ${missing[*]}"
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '    DRY-RUN: %s\n' "$*"
  else
    "$@"
  fi
}

relative_path() {
  local path="$1"
  if [[ -n "$REALPATH_CMD" ]]; then
    "$REALPATH_CMD" --relative-to="$TARGET_DIR" "$path" 2>/dev/null || printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

confirm_action() {
  local message="$1"
  if [[ "$SAFE_MODE" == true && "$DRY_RUN" == false ]]; then
    if [[ ! -t 0 ]]; then
      warn "Non-interactive mode detected: action skipped in safe mode ($message)"
      return 1
    fi
    printf '%s [y/N]: ' "$message"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
  else
    return 0
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}
