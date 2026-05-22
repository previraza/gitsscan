#!/usr/bin/env bash

build_find_cmd() {
  [[ -d "$TARGET_DIR" ]] || return 0

  if [[ "$SCAN_MODE" == "git" ]]; then
    find "$TARGET_DIR" \
      -type d \( -name node_modules -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
      -type d -name .git -print
  elif [[ "$SCAN_MODE" == "mixed" ]]; then
    find "$TARGET_DIR" \
      -type d \( -name node_modules -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
      \( -type d -name .git -o -type f \( -name package.json -o -name composer.json -o -name artisan -o -name vite.config.js -o -name vite.config.ts -o -name next.config.js -o -name next.config.ts -o -name index.php -o -name turbo.json -o -name pnpm-workspace.yaml \) \) \
      -print
  else
    find "$TARGET_DIR" \
      -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
      -type f \( -name package.json -o -name composer.json -o -name artisan -o -name vite.config.js -o -name vite.config.ts -o -name next.config.js -o -name next.config.ts -o -name index.php -o -name turbo.json -o -name pnpm-workspace.yaml \) \
      -print
  fi
}

collect_projects() {
  local work_file result_file active_jobs file project_dir
  work_file="$(mktemp)"
  result_file="$(mktemp)"
  active_jobs=0

  while IFS= read -r file; do
    project_dir="$(dirname "$file")"
    printf '%s\n' "$project_dir" >> "$work_file"
  done < <(build_find_cmd)

  if [[ "$WORKERS" -le 1 ]]; then
    while IFS= read -r project_dir; do
      analyze_project_dir "$project_dir" >> "$result_file"
    done < "$work_file"
  else
    while IFS= read -r project_dir; do
      (
        analyze_project_dir "$project_dir"
      ) >> "$result_file" &
      ((active_jobs+=1))
      if [[ "$active_jobs" -ge "$WORKERS" ]]; then
        wait -n
        ((active_jobs-=1))
      fi
    done < "$work_file"
    wait
  fi

  parse_results "$result_file"
  rm -f "$work_file" "$result_file"
}

analyze_project_dir() {
  local project_dir="$1"
  local git_root status_output mod_count
  git_root="$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null || true)"

  if [[ -n "$git_root" ]]; then
    status_output="$(git -C "$git_root" status --porcelain 2>/dev/null || true)"
    if [[ -n "$status_output" ]]; then
      mod_count="$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')"
      printf 'GIT|%s|DIRTY|%s\n' "$git_root" "$mod_count"
    else
      printf 'GIT|%s|CLEAN|0\n' "$git_root"
    fi
  elif [[ "$SCAN_MODE" != "git" ]]; then
    printf 'NOGIT|%s|NO_GIT|0\n' "$project_dir"
  fi
}

parse_results() {
  local result_file="$1"
  local line kind display_dir status mod_count
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    kind="${line%%|*}"
    display_dir="${line#*|}"; display_dir="${display_dir%%|*}"
    status="${line#*|}"; status="${status#*|}"; status="${status%%|*}"
    mod_count="${line##*|}"

    if [[ "$kind" == "GIT" ]]; then
      [[ -n "${SEEN_GIT_ROOTS[$display_dir]:-}" ]] && continue
      SEEN_GIT_ROOTS["$display_dir"]=1
      if [[ "$status" == "DIRTY" ]]; then
        ((DIRTY_COUNT+=1))
        ((PENDING_FILES_TOTAL+=mod_count))
      else
        ((CLEAN_COUNT+=1))
      fi
    else
      [[ -n "${SEEN_NO_GIT_DIRS[$display_dir]:-}" ]] && continue
      SEEN_NO_GIT_DIRS["$display_dir"]=1
      ((NOGIT_COUNT+=1))
    fi

    case "$MODE" in
      --dirty) [[ "$status" != "DIRTY" ]] && continue ;;
      --clean) [[ "$status" != "CLEAN" ]] && continue ;;
      --no-git) [[ "$status" != "NO_GIT" ]] && continue ;;
    esac

    SCAN_RESULTS+=("$display_dir|$status|$mod_count")
    ((TOTAL_DISPLAYED+=1))
  done < "$result_file"
}
