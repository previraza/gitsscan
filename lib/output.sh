#!/usr/bin/env bash

BOLD="\033[1m"; CYAN="\033[36m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; DIM="\033[2m"; RESET="\033[0m"
BG_GREEN="\033[1;97;42m"; BG_YELLOW="\033[1;30;103m"; BG_RED="\033[1;97;41m"

disable_colors() {
  BOLD=""; CYAN=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
  BG_GREEN=""; BG_YELLOW=""; BG_RED=""
}

print_files() {
  local repo="$1"
  local total="$2"
  case "$FILES_LIST" in
    none)
      [[ "$total" -gt 0 ]] && printf '    Use -fl or --files-list=5 to inspect changed files.\n'
      ;;
    all)
      git -C "$repo" status --short | sed 's/^/    /'
      ;;
    limit)
      git -C "$repo" status --short | head -n "$FILES_LIMIT" | sed 's/^/    /'
      if [[ "$total" -gt "$FILES_LIMIT" ]]; then
        printf '    ... +%s more files. Use -fl for all.\n' "$((total - FILES_LIMIT))"
      fi
      ;;
  esac
}

print_extra_info() {
  local repo="$1"
  [[ "$SHOW_BRANCH" == true ]] && printf '    branch: %s\n' "$(repo_branch "$repo")"
  [[ "$SHOW_AHEAD" == true ]] && printf '    remote: %s\n' "$(repo_ahead_behind "$repo")"
  if [[ "$SHOW_LAST_COMMIT" == true ]]; then
    local last
    last="$(repo_last_commit "$repo")"
    [[ -n "$last" ]] && printf '    last: %s\n' "$last"
  fi
  [[ "$SHOW_DISK" == true ]] && printf '    size: %s\n' "$(repo_disk "$repo")"
}

print_json() {
  local first=true
  local version_esc target_esc
  version_esc="$(json_escape "$VERSION")"
  target_esc="$(json_escape "$TARGET_DIR")"
  printf '{\n'
  printf '  "version": "%s",\n' "$version_esc"
  printf '  "target": "%s",\n' "$target_esc"
  printf '  "summary": {"displayed": %s, "clean": %s, "dirty": %s, "pending_files": %s, "no_git": %s},\n' \
    "$TOTAL_DISPLAYED" "$CLEAN_COUNT" "$DIRTY_COUNT" "$PENDING_FILES_TOTAL" "$NOGIT_COUNT"
  printf '  "projects": [\n'

  local entry repo status mod_count rel repo_esc rel_esc status_esc
  for entry in "${SCAN_RESULTS[@]}"; do
    repo="${entry%%|*}"
    status="${entry#*|}"; status="${status%%|*}"
    mod_count="${entry##*|}"
    rel="$(relative_path "$repo")"
    repo_esc="$(json_escape "$repo")"
    rel_esc="$(json_escape "$rel")"
    status_esc="$(json_escape "$status")"

    if [[ "$first" == false ]]; then
      printf ',\n'
    fi
    first=false
    printf '    {"path": "%s", "relative_path": "%s", "status": "%s", "pending": %s}' "$repo_esc" "$rel_esc" "$status_esc" "$mod_count"
  done

  printf '\n  ]\n'
  printf '}\n'
}

print_text() {
  if [[ "$SUMMARY_ONLY" == false ]]; then
    printf '\n%sScan web projects%s in %s%s%s\n\n' "$BOLD$CYAN" "$RESET" "$DIM" "$TARGET_DIR" "$RESET"
  fi

  local entry repo status mod_count proj rel
  for entry in "${SCAN_RESULTS[@]}"; do
    repo="${entry%%|*}"
    status="${entry#*|}"; status="${status%%|*}"
    mod_count="${entry##*|}"

    run_repo_actions "$repo" "$status"
    [[ "$SUMMARY_ONLY" == true ]] && continue

    proj="$(basename "$repo")"
    rel="$(relative_path "$repo")"
    [[ "$rel" == "." ]] && rel="./"

    case "$status" in
      CLEAN)
        printf '%b✓%b %b%s%b %b(%s)%b %b CLEAN / OK %b\n' "$GREEN" "$RESET" "$BOLD" "$proj" "$RESET" "$DIM" "$rel" "$RESET" "$BG_GREEN" "$RESET"
        print_extra_info "$repo"
        ;;
      DIRTY)
        printf '%b●%b %b%s%b %b(%s)%b %b %s PENDING %b\n' "$YELLOW" "$RESET" "$BOLD" "$proj" "$RESET" "$DIM" "$rel" "$RESET" "$BG_YELLOW" "$mod_count" "$RESET"
        print_extra_info "$repo"
        print_files "$repo" "$mod_count"
        ;;
      NO_GIT)
        printf '%b✗%b %b%s%b %b(%s)%b %b NO GIT %b\n' "$RED" "$RESET" "$BOLD" "$proj" "$RESET" "$DIM" "$rel" "$RESET" "$BG_RED" "$RESET"
        [[ "$SHOW_DISK" == true ]] && printf '    size: %s\n' "$(repo_disk "$repo")"
        ;;
    esac
  done

  printf '\n%s\n' '----------------------------------------------'
  printf 'Summary:\n'
  printf '  Displayed: %s\n' "$TOTAL_DISPLAYED"
  printf '  Clean: %s\n' "$CLEAN_COUNT"
  printf '  Dirty: %s\n' "$DIRTY_COUNT"
  printf '  Pending files: %s\n' "$PENDING_FILES_TOTAL"
  printf '  No Git: %s\n' "$NOGIT_COUNT"
  printf '  Action errors: %s\n' "$ACTION_ERRORS"
  printf '%s\n\n' '----------------------------------------------'
}

main() {
  validate_runtime
  load_config
  parse_cli "$@"
  [[ "$NO_COLOR" == true ]] && disable_colors
  collect_projects

  case "$OUTPUT_FORMAT" in
    json) print_json ;;
    text) print_text ;;
    *) die "Unsupported format: $OUTPUT_FORMAT" ;;
  esac
}
