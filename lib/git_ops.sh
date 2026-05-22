#!/usr/bin/env bash

run_repo_actions() {
  local repo="$1"
  local status="$2"

  if [[ "$DO_FETCH" == true ]] && ! run_cmd git -C "$repo" fetch --all --prune; then
    warn "fetch failed for $repo"
    ((ACTION_ERRORS+=1))
    return
  fi
  if [[ "$DO_PULL" == true ]] && ! run_cmd git -C "$repo" pull --ff-only; then
    warn "pull failed for $repo"
    ((ACTION_ERRORS+=1))
    return
  fi

  if [[ "$DO_COMMIT" == true && "$status" == "DIRTY" ]]; then
    if ! run_cmd git -C "$repo" add -A; then
      warn "git add failed for $repo"
      ((ACTION_ERRORS+=1))
      return
    fi
    if ! run_cmd git -C "$repo" commit -m "$COMMIT_MSG"; then
      warn "commit failed for $repo"
      ((ACTION_ERRORS+=1))
      return
    fi
  fi

  if [[ "$DO_PUSH" == true ]]; then
    if confirm_action "Push changes for $repo?"; then
      if ! run_cmd git -C "$repo" push; then
        warn "push failed for $repo"
        ((ACTION_ERRORS+=1))
      fi
    else
      printf '    Skip push for %s\n' "$repo"
    fi
  fi
}

repo_branch() {
  git -C "$1" branch --show-current 2>/dev/null || printf '?\n'
}

repo_ahead_behind() {
  local repo="$1"
  local upstream ahead behind
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
  if [[ -n "$upstream" ]]; then
    ahead="$(git -C "$repo" rev-list --count "$upstream"..HEAD 2>/dev/null || printf '0')"
    behind="$(git -C "$repo" rev-list --count HEAD.."$upstream" 2>/dev/null || printf '0')"
    printf '↑%s ↓%s\n' "$ahead" "$behind"
  else
    printf 'no-upstream\n'
  fi
}

repo_last_commit() {
  git -C "$1" log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || true
}

repo_disk() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}
