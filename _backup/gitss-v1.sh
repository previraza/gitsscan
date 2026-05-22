#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="2.2.0"

TARGET_DIR="."
MODE="all"
FILES_LIST="none"   # none|all|limit
FILES_LIMIT=10
SUMMARY_ONLY=false
NO_COLOR=false

SHOW_BRANCH=false
SHOW_AHEAD=false
SHOW_LAST_COMMIT=false
SHOW_DISK=false

DO_INIT=false
DO_FETCH=false
DO_PULL=false
DO_COMMIT=false
DO_PUSH=false
DRY_RUN=false
COMMIT_MSG="chore: auto backup changes"

OWNER=""            # GitHub owner (user/org). Auto via gh si vide.
ORIGIN_PROTO="ssh"  # ssh|https

BOLD=$'\033[1m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
BG_GREEN=$'\033[1;97;42m'; BG_YELLOW=$'\033[1;30;103m'; BG_RED=$'\033[1;97;41m'

disable_colors(){ BOLD=""; CYAN=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""; BG_GREEN=""; BG_YELLOW=""; BG_RED=""; }
log(){ printf '%b\n' "$*"; }
die(){ log "${RED}Erreur:${RESET} $*"; exit 1; }
trap 'ec=$?; log "${RED}Erreur:${RESET} exit=$ec, ligne=${BASH_LINENO[0]}: ${DIM}${BASH_COMMAND}${RESET}"; exit $ec' ERR

# Global counters for the current repo (always defined, even if a function bails early)
PENDING_COUNT=0
AHEAD_COUNT=0
BEHIND_COUNT=0
HAS_ORIGIN=false
HAS_UPSTREAM=false

# Per-repo action error flags (do not represent git status, only what happened during this run)
ACTION_PUSH_FAILED=false
ACTION_PUSH_AUTH_FAILED=false
LAST_CMD_OUTPUT=""
LAST_CMD_EC=0

reset_action_flags() {
  ACTION_PUSH_FAILED=false
  ACTION_PUSH_AUTH_FAILED=false
}

help() {
cat << EOF
GitSScan v$VERSION

USAGE:
  gitss [dossier] [options]

FILTERS:
  --dirty              Affiche seulement les projets avec PENDING
  --clean              Affiche seulement les projets OK (pas pending, pas ahead/behind)
  --no-git             Affiche seulement les projets sans Git

FILES:
  -fl, --files-list    Affiche tous les fichiers modifiés
  --files-list=N       Affiche N fichiers modifiés
  --files-list=all     Affiche tous les fichiers modifiés

INFO:
  --branch             Affiche la branche actuelle
  --ahead              Affiche ahead/behind (si upstream)
  --last-commit        Affiche le dernier commit
  --disk               Affiche la taille du projet
  --summary            Affiche seulement le résumé
  --no-color           Désactive les couleurs

ACTIONS:
  --init               Initialise les projets sans Git
  --fetch              git fetch --all --prune
  --pull               git pull --ff-only
  --commit             git add -A + commit (si PENDING)
  --commit="message"   Commit avec message personnalisé
  --push               git push (si upstream et AHEAD>0)
  --dry-run            Affiche les actions sans les exécuter

REMOTE (GitHub via gh):
  --owner=NAME         Owner GitHub (user/org). Défaut: utilisateur gh connecté
  --origin=ssh|https   URL origin à utiliser. Défaut: ssh
EOF
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    local rendered=""
    for arg in "$@"; do rendered+=" $(printf '%q' "$arg")"; done
    log "    ${DIM}DRY-RUN:${RESET}${rendered}"
    return 0
  fi
  "$@"
}

# Run a command but never abort the whole scan if it fails.
# Prints a short, indented error and returns 0.
run_cmd_allow_fail() {
  if [ "$DRY_RUN" = true ]; then
    run_cmd "$@"
    return 0
  fi

  local out ec old_err_trap

  # Disable errexit + ERR trap for this command, otherwise failures inside
  # command substitutions can still trigger the global trap.
  old_err_trap="$(trap -p ERR || true)"
  trap - ERR

  set +e
  out="$("$@" 2>&1)"
  ec=$?
  set -e

  # Restore ERR trap
  if [ -n "$old_err_trap" ]; then
    eval "$old_err_trap"
  fi

  if [ $ec -ne 0 ]; then
    log "    ${RED}action failed:${RESET} $(printf '%q ' "$@") (exit=$ec)"
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | sed 's/^/    /'
    fi
  fi

  LAST_CMD_OUTPUT="$out"
  LAST_CMD_EC="$ec"
  return 0
}

relative_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath --relative-to="$TARGET_DIR" "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

print_git_account() {
  local name email gh_user=""
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"
  if command -v gh >/dev/null 2>&1; then
    gh_user="$(gh api user --jq '.login' 2>/dev/null || true)"
  fi
  log "${BOLD}${CYAN}Compte Git connecté${RESET}"
  log "  ${CYAN}user.name:${RESET}  ${name:-non configuré}"
  log "  ${CYAN}user.email:${RESET} ${email:-non configuré}"
  [ -n "$gh_user" ] && log "  ${CYAN}GitHub CLI:${RESET} @$gh_user" || log "  ${DIM}GitHub CLI: non connecté/absent${RESET}"
  log ""
}

print_files() {
  local repo="$1" total="${2:-0}"
  [[ "$total" =~ ^[0-9]+$ ]] || total=0
  case "$FILES_LIST" in
    none)
      if [ "$total" -gt 0 ]; then
        log "    ${DIM}Utilise -fl ou --files-list=5 pour voir les fichiers.${RESET}"
      fi
      ;;
    all) git -C "$repo" status --short | sed 's/^/    /' ;;
    limit)
      git -C "$repo" status --short | head -n "$FILES_LIMIT" | sed 's/^/    /'
      [ "$total" -gt "$FILES_LIMIT" ] && log "    ${DIM}... +$((total - FILES_LIMIT)) autres fichiers. Utilise -fl pour tout afficher.${RESET}"
      ;;
  esac
}

print_extra_info() {
  local repo="$1" branch upstream ahead behind last size
  if [ "$SHOW_BRANCH" = true ]; then
    branch="$(git -C "$repo" branch --show-current 2>/dev/null || printf '?')"
    log "    ${CYAN}branch:${RESET} $branch"
  fi
  if [ "$SHOW_AHEAD" = true ]; then
    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      ahead="$(git -C "$repo" rev-list --count "$upstream"..HEAD 2>/dev/null || printf '0')"
      behind="$(git -C "$repo" rev-list --count HEAD.."$upstream" 2>/dev/null || printf '0')"
      log "    ${CYAN}remote:${RESET} ↑$ahead ↓$behind"
    else
      log "    ${DIM}remote: aucun upstream${RESET}"
    fi
  fi
  if [ "$SHOW_LAST_COMMIT" = true ]; then
    last="$(git -C "$repo" log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || true)"
    [ -n "$last" ] && log "    ${CYAN}last:${RESET} $last"
  fi
  if [ "$SHOW_DISK" = true ]; then
    size="$(du -sh "$repo" 2>/dev/null | awk '{print $1}')"
    log "    ${CYAN}size:${RESET} $size"
  fi
}

ensure_owner() {
  [ -n "$OWNER" ] && return 0
  command -v gh >/dev/null 2>&1 || return 1
  OWNER="$(gh api user --jq '.login' 2>/dev/null || true)"
  [ -n "$OWNER" ]
}

try_link_origin_by_name() {
  local repo_dir="$1"
  local repo_name owner url

  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$repo_dir" remote get-url origin >/dev/null 2>&1 && return 0

  command -v gh >/dev/null 2>&1 || { log "    ${DIM}skip origin: gh absent${RESET}"; return 0; }
  ensure_owner || { log "    ${DIM}skip origin: gh non connecté${RESET}"; return 0; }

  repo_name="$(basename "$repo_dir")"
  owner="$OWNER"

  if [ "$ORIGIN_PROTO" = "https" ]; then
    url="$(gh repo view "$owner/$repo_name" --json httpsUrl --jq '.httpsUrl' 2>/dev/null || true)"
  else
    url="$(gh repo view "$owner/$repo_name" --json sshUrl --jq '.sshUrl' 2>/dev/null || true)"
  fi

  if [ -z "$url" ]; then
    log "    ${DIM}origin: aucun repo GitHub trouvé pour ${owner}/${repo_name}${RESET}"
    return 0
  fi

  log "    ${CYAN}origin:${RESET} git remote add origin $url"
  run_cmd git -C "$repo_dir" remote add origin "$url"
}

init_git_repo() {
  local repo="$1"
  [ -d "$repo/.git" ] && return 0

  log "    ${CYAN}init:${RESET} git init"
  run_cmd git -C "$repo" init
  # Ne renomme pas la branche si elle existe déjà (respecte init.defaultBranch / master / main).
  # (On garde la branche créée par `git init` telle quelle.)

  if [ ! -f "$repo/.gitignore" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "    ${DIM}DRY-RUN:${RESET} écriture .gitignore"
    else
      cat > "$repo/.gitignore" << 'EOF'
node_modules
.next
dist
build
coverage
.turbo
vendor
.env
.env.local
*.log
core
EOF
    fi
  fi

  # Si origin absent: on tente de le lier à GitHub (même nom que dossier)
  try_link_origin_by_name "$repo"

  run_cmd git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet 2>/dev/null; then
    run_cmd git -C "$repo" commit -m "chore: initial commit"
  fi
}

get_repo_flags() {
  # Output: flags string + set globals: PENDING_COUNT AHEAD_COUNT BEHIND_COUNT HAS_ORIGIN HAS_UPSTREAM
  local repo="$1" status_output upstream
  PENDING_COUNT=0; AHEAD_COUNT=0; BEHIND_COUNT=0; HAS_ORIGIN=false; HAS_UPSTREAM=false

  status_output="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
  if [ -n "$status_output" ]; then
    PENDING_COUNT="$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')"
  fi

  if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    HAS_ORIGIN=true
  fi

  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  if [ -n "$upstream" ]; then
    HAS_UPSTREAM=true
    AHEAD_COUNT="$(git -C "$repo" rev-list --count "$upstream"..HEAD 2>/dev/null || printf '0')"
    BEHIND_COUNT="$(git -C "$repo" rev-list --count HEAD.."$upstream" 2>/dev/null || printf '0')"
  fi

  # Hardening: ensure arithmetic-safe values
  PENDING_COUNT="${PENDING_COUNT:-0}"
  AHEAD_COUNT="${AHEAD_COUNT:-0}"
  BEHIND_COUNT="${BEHIND_COUNT:-0}"
}

format_flags() {
  local flags=()
  if [ "$PENDING_COUNT" -gt 0 ]; then flags+=("${BG_YELLOW} PENDING:$PENDING_COUNT ${RESET}"); fi
  if [ "$HAS_ORIGIN" != true ]; then flags+=("${BG_RED} NO_ORIGIN ${RESET}"); fi
  if [ "$HAS_UPSTREAM" != true ] && [ "$HAS_ORIGIN" = true ]; then flags+=("${BG_RED} NO_UPSTREAM ${RESET}"); fi
  if [ "$AHEAD_COUNT" -gt 0 ] && [ "$BEHIND_COUNT" -gt 0 ]; then flags+=("${BG_RED} DIVERGED ↑$AHEAD_COUNT ↓$BEHIND_COUNT ${RESET}")
  elif [ "$AHEAD_COUNT" -gt 0 ]; then flags+=("${BG_YELLOW} AHEAD:$AHEAD_COUNT ${RESET}")
  elif [ "$BEHIND_COUNT" -gt 0 ]; then flags+=("${BG_YELLOW} BEHIND:$BEHIND_COUNT ${RESET}")
  fi
  if [ "$ACTION_PUSH_AUTH_FAILED" = true ]; then flags+=("${BG_RED} PUSH_AUTH_FAILED ${RESET}"); fi
  if [ "$ACTION_PUSH_FAILED" = true ] && [ "$ACTION_PUSH_AUTH_FAILED" != true ]; then flags+=("${BG_RED} PUSH_FAILED ${RESET}"); fi

  if [ "${#flags[@]}" -eq 0 ]; then
    flags+=("${BG_GREEN} OK ${RESET}")
  fi

  printf '%s' "${flags[*]}"
}

do_actions() {
  local repo="$1"

  [ "$DO_FETCH" = true ] && run_cmd_allow_fail git -C "$repo" fetch --all --prune
  [ "$DO_PULL" = true ] && run_cmd_allow_fail git -C "$repo" pull --ff-only

  if [ "$DO_COMMIT" = true ] && [ "$PENDING_COUNT" -gt 0 ]; then
    run_cmd_allow_fail git -C "$repo" add -A
    run_cmd_allow_fail git -C "$repo" commit -m "$COMMIT_MSG"
    # refresh flags after commit
    get_repo_flags "$repo"
  fi

  if [ "$DO_PUSH" = true ]; then
    if [ "$HAS_ORIGIN" != true ]; then
      log "    ${DIM}skip push: aucun remote origin${RESET}"
      return 0
    fi
    if [ "$HAS_UPSTREAM" != true ]; then
      # Premier push: set upstream automatiquement
      local branch
      branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
      [ -z "$branch" ] && branch="main"
      log "    ${CYAN}push:${RESET} git push -u origin $branch"
      run_cmd_allow_fail git -C "$repo" push -u origin "$branch"
      if [ "${LAST_CMD_EC:-0}" -ne 0 ]; then
        ACTION_PUSH_FAILED=true
        printf '%s\n' "${LAST_CMD_OUTPUT:-}" | grep -qi 'Permission denied (publickey)' && ACTION_PUSH_AUTH_FAILED=true
        return 0
      fi
      get_repo_flags "$repo"
      return 0
    fi
    if [ "$AHEAD_COUNT" -eq 0 ]; then
      log "    ${DIM}skip push: aucun commit local à pousser${RESET}"
      return 0
    fi
    run_cmd_allow_fail git -C "$repo" push
    if [ "${LAST_CMD_EC:-0}" -ne 0 ]; then
      ACTION_PUSH_FAILED=true
      printf '%s\n' "${LAST_CMD_OUTPUT:-}" | grep -qi 'Permission denied (publickey)' && ACTION_PUSH_AUTH_FAILED=true
      return 0
    fi
  fi
}

# Args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) help; exit 0 ;;
    -v|--version) printf 'GitSScan v%s\n' "$VERSION"; exit 0 ;;

    --dirty|--clean|--no-git) MODE="$1"; shift ;;
    -fl|--files-list) FILES_LIST="all"; shift ;;
    --files-list=*)
      VALUE="${1#*=}"
      if [ "$VALUE" = "all" ]; then FILES_LIST="all"
      elif [[ "$VALUE" =~ ^[0-9]+$ ]]; then FILES_LIST="limit"; FILES_LIMIT="$VALUE"
      else die "--files-list accepte un nombre ou all"; fi
      shift
      ;;

    --branch) SHOW_BRANCH=true; shift ;;
    --ahead) SHOW_AHEAD=true; shift ;;
    --last-commit) SHOW_LAST_COMMIT=true; shift ;;
    --disk) SHOW_DISK=true; shift ;;
    --summary) SUMMARY_ONLY=true; shift ;;
    --no-color) NO_COLOR=true; shift ;;

    --init) DO_INIT=true; shift ;;
    --fetch) DO_FETCH=true; shift ;;
    --pull) DO_PULL=true; shift ;;
    --commit) DO_COMMIT=true; shift ;;
    --commit=*) DO_COMMIT=true; COMMIT_MSG="${1#*=}"; shift ;;
    --push) DO_PUSH=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;

    --owner=*) OWNER="${1#*=}"; shift ;;
    --origin=*)
      ORIGIN_PROTO="${1#*=}"
      [ "$ORIGIN_PROTO" = "ssh" ] || [ "$ORIGIN_PROTO" = "https" ] || die "--origin=ssh|https"
      shift
      ;;
    -*) die "Option inconnue: $1 (utilise --help)" ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

[ "$NO_COLOR" = true ] && disable_colors
[ -d "$TARGET_DIR" ] || die "Le dossier '$TARGET_DIR' n'existe pas."

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT INT TERM

if [ "$SUMMARY_ONLY" = false ]; then
  print_git_account
  log "${BOLD}${CYAN}Scan des projets web${RESET} dans ${DIM}$TARGET_DIR${RESET}\n"
fi

find "$TARGET_DIR" \
  -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
  -type f \( -name package.json -o -name composer.json -o -name artisan -o -name vite.config.js -o -name vite.config.ts -o -name next.config.js -o -name next.config.ts -o -name index.php \) \
  -print > "$TMP_FILE"

TOTAL_DISPLAYED=0
PENDING_FILES_TOTAL=0
OK_REPOS=0
PENDING_REPOS=0
NOGIT_REPOS=0
NO_ORIGIN_REPOS=0
NO_UPSTREAM_REPOS=0
AHEAD_REPOS=0
BEHIND_REPOS=0
DIVERGED_REPOS=0
PUSH_FAILED_REPOS=0
PUSH_AUTH_FAILED_REPOS=0
declare -A SEEN_GIT_ROOTS=()
declare -A SEEN_NO_GIT_DIRS=()

while IFS= read -r file; do
  PROJECT_DIR="$(dirname "$file")"
  GIT_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

  if [ -n "$GIT_ROOT" ]; then
    [ -n "${SEEN_GIT_ROOTS["$GIT_ROOT"]+x}" ] && continue
    SEEN_GIT_ROOTS["$GIT_ROOT"]=1
    DISPLAY_DIR="$GIT_ROOT"
    STATUS="GIT"
  else
    [ -n "${SEEN_NO_GIT_DIRS["$PROJECT_DIR"]+x}" ] && continue
    SEEN_NO_GIT_DIRS["$PROJECT_DIR"]=1
    DISPLAY_DIR="$PROJECT_DIR"
    STATUS="NO_GIT"

    if [ "$DO_INIT" = true ]; then
      init_git_repo "$DISPLAY_DIR"
      GIT_ROOT="$(git -C "$DISPLAY_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
      if [ -n "$GIT_ROOT" ]; then
        DISPLAY_DIR="$GIT_ROOT"
        STATUS="GIT"
      fi
    fi
  fi

  # Filters
  if [ "$STATUS" = "NO_GIT" ]; then
    case "$MODE" in
      --dirty|--clean) continue ;;
      --no-git|all) : ;;
    esac
  fi

  # From here, we want the displayed status + summary to reflect the *final* state
  # after any requested actions (commit/push). So we compute flags, run actions,
  # then recompute flags and display.

  PROJ_NAME="$(basename "$DISPLAY_DIR")"
  RELATIVE_PATH="$(relative_path "$DISPLAY_DIR")"
  [ "$RELATIVE_PATH" = "." ] && RELATIVE_PATH="./"

  if [ "$STATUS" = "NO_GIT" ]; then
    case "$MODE" in
      --dirty|--clean) continue ;;
      --no-git|all) : ;;
    esac
    TOTAL_DISPLAYED=$((TOTAL_DISPLAYED + 1))
    [ "$SUMMARY_ONLY" = true ] && continue
    NOGIT_REPOS=$((NOGIT_REPOS + 1))
    log "${RED}✗${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} ${BG_RED} NO_GIT ${RESET}"
    [ "$SHOW_DISK" = true ] && log "    ${CYAN}size:${RESET} $(du -sh "$DISPLAY_DIR" 2>/dev/null | awk '{print $1}')"
    continue
  fi

  # Reset per-repo action flags (avoid bleed from previous repo)
  reset_action_flags

  # If --init is active, try to attach origin only when missing.
  if [ "$DO_INIT" = true ]; then
    try_link_origin_by_name "$DISPLAY_DIR"
  fi

  # Pre-action flags (used for filtering + pending files total)
  get_repo_flags "$DISPLAY_DIR"
  PENDING_FILES_TOTAL=$((PENDING_FILES_TOTAL + ${PENDING_COUNT:-0}))

  case "$MODE" in
    --dirty) [ "$PENDING_COUNT" -eq 0 ] && continue ;;
    --clean)
      if [ "$PENDING_COUNT" -ne 0 ] || [ "$AHEAD_COUNT" -ne 0 ] || [ "$BEHIND_COUNT" -ne 0 ]; then
        continue
      fi
      ;;
    --no-git) continue ;;
  esac

  TOTAL_DISPLAYED=$((TOTAL_DISPLAYED + 1))
  [ "$SUMMARY_ONLY" = true ] && continue

  # Show details BEFORE actions only when user asked for it (files list).
  # Otherwise, we prefer the final status line.
  if [ "$FILES_LIST" != "none" ]; then
    print_files "$DISPLAY_DIR" "$PENDING_COUNT"
  fi

  do_actions "$DISPLAY_DIR"

  # Recompute to display final state (commit/push may have changed things).
  get_repo_flags "$DISPLAY_DIR"
  flags="$(format_flags)"

  if [ "$PENDING_COUNT" -gt 0 ] || [ "$AHEAD_COUNT" -gt 0 ] || [ "$BEHIND_COUNT" -gt 0 ] || [ "$HAS_ORIGIN" != true ]; then
    log "${YELLOW}●${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} $flags"
  else
    log "${GREEN}✓${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} $flags"
  fi

  print_extra_info "$DISPLAY_DIR"
  # If files list was not printed earlier, print it now based on final pending count.
  if [ "$FILES_LIST" = "none" ]; then
    print_files "$DISPLAY_DIR" "$PENDING_COUNT"
  fi

  # Counters (post-actions so PUSH_* flags are reflected)
  if [ "$PENDING_COUNT" -gt 0 ]; then PENDING_REPOS=$((PENDING_REPOS + 1)); fi
  if [ "$HAS_ORIGIN" != true ]; then NO_ORIGIN_REPOS=$((NO_ORIGIN_REPOS + 1)); fi
  if [ "$HAS_UPSTREAM" != true ] && [ "$HAS_ORIGIN" = true ]; then NO_UPSTREAM_REPOS=$((NO_UPSTREAM_REPOS + 1)); fi
  if [ "$AHEAD_COUNT" -gt 0 ] && [ "$BEHIND_COUNT" -gt 0 ]; then DIVERGED_REPOS=$((DIVERGED_REPOS + 1))
  elif [ "$AHEAD_COUNT" -gt 0 ]; then AHEAD_REPOS=$((AHEAD_REPOS + 1))
  elif [ "$BEHIND_COUNT" -gt 0 ]; then BEHIND_REPOS=$((BEHIND_REPOS + 1))
  fi
  if [ "$ACTION_PUSH_FAILED" = true ]; then PUSH_FAILED_REPOS=$((PUSH_FAILED_REPOS + 1)); fi
  if [ "$ACTION_PUSH_AUTH_FAILED" = true ]; then PUSH_AUTH_FAILED_REPOS=$((PUSH_AUTH_FAILED_REPOS + 1)); fi
  if [ "$PENDING_COUNT" -eq 0 ] && [ "$AHEAD_COUNT" -eq 0 ] && [ "$BEHIND_COUNT" -eq 0 ] && [ "$HAS_ORIGIN" = true ]; then
    OK_REPOS=$((OK_REPOS + 1))
  fi
done < "$TMP_FILE"

log "\n${DIM}──────────────────────────────────────────────────${RESET}"
log "${BOLD}Résumé :${RESET}"
log "  Total affiché :         $TOTAL_DISPLAYED"
log "  ${GREEN}● Projets OK :${RESET}        $OK_REPOS"
log "  ${YELLOW}● Projets pending :${RESET}   $PENDING_REPOS"
log "  ${YELLOW}● Fichiers pending :${RESET}  $PENDING_FILES_TOTAL"
log "  ${RED}● Projets sans Git :${RESET}  $NOGIT_REPOS"
log "  ${RED}● Sans origin :${RESET}       $NO_ORIGIN_REPOS"
log "  ${RED}● Sans upstream :${RESET}     $NO_UPSTREAM_REPOS"
log "  ${YELLOW}● Ahead :${RESET}             $AHEAD_REPOS"
log "  ${YELLOW}● Behind :${RESET}            $BEHIND_REPOS"
log "  ${RED}● Diverged :${RESET}          $DIVERGED_REPOS"
log "  ${RED}● Push failed :${RESET}       $PUSH_FAILED_REPOS"
log "  ${RED}● Push auth failed :${RESET}  $PUSH_AUTH_FAILED_REPOS"
log "${DIM}──────────────────────────────────────────────────${RESET}\n"
