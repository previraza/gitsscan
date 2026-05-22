#!/usr/bin/env bash
set -u

VERSION="2.0.0"

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
DO_FETCH=false
DO_PULL=false
DO_COMMIT=false
DO_PUSH=false
DRY_RUN=false
COMMIT_MSG="chore: auto backup changes"

BOLD="\033[1m"; CYAN="\033[36m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; DIM="\033[2m"; RESET="\033[0m"
BG_GREEN="\033[1;97;42m"; BG_YELLOW="\033[1;30;103m"; BG_RED="\033[1;97;41m"

disable_colors() {
  BOLD=""; CYAN=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
  BG_GREEN=""; BG_YELLOW=""; BG_RED=""
}

help() {
cat << EOF
GitSScan v$VERSION

USAGE:
  gitss [dossier] [options]

BASIC:
  gitss /var/www
  gitss /var/www --dirty
  gitss /var/www -fl
  gitss /var/www --files-list=5
  gitss /var/www --files-list=all

FILTERS:
  --dirty              Affiche seulement les projets modifiés
  --clean              Affiche seulement les projets propres
  --no-git             Affiche seulement les projets sans Git

FILES:
  -fl, --files-list    Affiche tous les fichiers modifiés
  --files-list=N       Affiche N fichiers modifiés
  --files-list=all     Affiche tous les fichiers modifiés

INFO:
  --branch             Affiche la branche actuelle
  --ahead              Affiche commits ahead/behind
  --last-commit        Affiche le dernier commit
  --disk               Affiche la taille du projet
  --summary            Affiche seulement le résumé
  --no-color           Désactive les couleurs

ACTIONS:
  --fetch              Lance git fetch
  --pull               Lance git pull --ff-only
  --commit             Commit les pending avec message par défaut
  --commit="message"   Commit avec message personnalisé
  --push               Lance git push
  --dry-run            Affiche les actions sans les exécuter

UTILS:
  -h, --help           Aide
  -v, --version        Version
EOF
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "    ${DIM}DRY-RUN:${RESET} $*"
  else
    eval "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) help; exit 0 ;;
    -v|--version) echo "GitSScan v$VERSION"; exit 0 ;;

    --dirty|--clean|--no-git) MODE="$1"; shift ;;
    -fl|--files-list) FILES_LIST="all"; shift ;;
    --files-list=*)
      VALUE="${1#*=}"
      if [ "$VALUE" = "all" ]; then FILES_LIST="all"
      elif [[ "$VALUE" =~ ^[0-9]+$ ]]; then FILES_LIST="limit"; FILES_LIMIT="$VALUE"
      else echo -e "${RED}Erreur:${RESET} --files-list accepte un nombre ou all"; exit 1; fi
      shift ;;

    --branch) SHOW_BRANCH=true; shift ;;
    --ahead) SHOW_AHEAD=true; shift ;;
    --last-commit) SHOW_LAST_COMMIT=true; shift ;;
    --disk) SHOW_DISK=true; shift ;;
    --summary) SUMMARY_ONLY=true; shift ;;
    --no-color) NO_COLOR=true; shift ;;

    --fetch) DO_FETCH=true; shift ;;
    --pull) DO_PULL=true; shift ;;
    --commit) DO_COMMIT=true; shift ;;
    --commit=*) DO_COMMIT=true; COMMIT_MSG="${1#*=}"; shift ;;
    --push) DO_PUSH=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;

    -*) echo -e "${RED}Option inconnue:${RESET} $1"; echo "Utilise gitss --help"; exit 1 ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

[ "$NO_COLOR" = true ] && disable_colors

if [ ! -d "$TARGET_DIR" ]; then
  echo -e "${RED}Erreur:${RESET} Le dossier '$TARGET_DIR' n'existe pas."
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT INT TERM

[ "$SUMMARY_ONLY" = false ] && echo -e "\n${BOLD}${CYAN}Scan des projets web${RESET} dans ${DIM}$TARGET_DIR${RESET}\n"

find "$TARGET_DIR" \
  -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
  -type f \( -name package.json -o -name composer.json -o -name artisan -o -name vite.config.js -o -name vite.config.ts -o -name next.config.js -o -name next.config.ts -o -name index.php \) \
  -print > "$TMP_FILE"

CLEAN_COUNT=0
DIRTY_COUNT=0
NOGIT_COUNT=0
PENDING_FILES_TOTAL=0
TOTAL_DISPLAYED=0
SEEN_GIT_ROOTS=""
SEEN_NO_GIT_DIRS=""

is_seen() {
  echo "$1" | grep -Fxq "$2"
}

relative_path() {
  realpath --relative-to="$TARGET_DIR" "$1" 2>/dev/null || echo "$1"
}

print_files() {
  local repo="$1"
  local total="$2"

  case "$FILES_LIST" in
    none)
      [ "$total" -gt 0 ] && echo -e "    ${DIM}Utilise -fl ou --files-list=5 pour voir les fichiers.${RESET}"
      ;;
    all)
      git -C "$repo" status --short | sed 's/^/    /'
      ;;
    limit)
      git -C "$repo" status --short | head -n "$FILES_LIMIT" | sed 's/^/    /'
      if [ "$total" -gt "$FILES_LIMIT" ]; then
        echo -e "    ${DIM}... +$((total - FILES_LIMIT)) autres fichiers. Utilise -fl pour tout afficher.${RESET}"
      fi
      ;;
  esac
}

print_extra_info() {
  local repo="$1"

  if [ "$SHOW_BRANCH" = true ]; then
    branch="$(git -C "$repo" branch --show-current 2>/dev/null || echo "?")"
    echo -e "    ${CYAN}branch:${RESET} $branch"
  fi

  if [ "$SHOW_AHEAD" = true ]; then
    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      ahead="$(git -C "$repo" rev-list --count "$upstream"..HEAD 2>/dev/null || echo 0)"
      behind="$(git -C "$repo" rev-list --count HEAD.."$upstream" 2>/dev/null || echo 0)"
      echo -e "    ${CYAN}remote:${RESET} ↑$ahead ↓$behind"
    else
      echo -e "    ${DIM}remote: aucun upstream${RESET}"
    fi
  fi

  if [ "$SHOW_LAST_COMMIT" = true ]; then
    last="$(git -C "$repo" log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || true)"
    [ -n "$last" ] && echo -e "    ${CYAN}last:${RESET} $last"
  fi

  if [ "$SHOW_DISK" = true ]; then
    size="$(du -sh "$repo" 2>/dev/null | awk '{print $1}')"
    echo -e "    ${CYAN}size:${RESET} $size"
  fi
}

do_actions() {
  local repo="$1"
  local status="$2"

  [ "$DO_FETCH" = true ] && run_cmd "git -C '$repo' fetch --all --prune"

  if [ "$DO_PULL" = true ]; then
    run_cmd "git -C '$repo' pull --ff-only"
  fi

  if [ "$DO_COMMIT" = true ] && [ "$status" = "DIRTY" ]; then
    run_cmd "git -C '$repo' add -A"
    run_cmd "git -C '$repo' commit -m \"$(printf "%q" "$COMMIT_MSG")\""
  fi

  [ "$DO_PUSH" = true ] && run_cmd "git -C '$repo' push"
}

while read -r file; do
  PROJECT_DIR="$(dirname "$file")"
  GIT_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

  if [ -n "$GIT_ROOT" ]; then
    is_seen "$SEEN_GIT_ROOTS" "$GIT_ROOT" && continue
    SEEN_GIT_ROOTS="${SEEN_GIT_ROOTS}${GIT_ROOT}
"

    DISPLAY_DIR="$GIT_ROOT"
    STATUS_OUTPUT="$(git -C "$GIT_ROOT" status --porcelain)"

    if [ -n "$STATUS_OUTPUT" ]; then
      STATUS="DIRTY"
      MOD_COUNT="$(printf "%s\n" "$STATUS_OUTPUT" | wc -l | tr -d ' ')"
      ((DIRTY_COUNT++))
      ((PENDING_FILES_TOTAL+=MOD_COUNT))
    else
      STATUS="CLEAN"
      MOD_COUNT=0
      ((CLEAN_COUNT++))
    fi
  else
    is_seen "$SEEN_NO_GIT_DIRS" "$PROJECT_DIR" && continue
    SEEN_NO_GIT_DIRS="${SEEN_NO_GIT_DIRS}${PROJECT_DIR}
"

    DISPLAY_DIR="$PROJECT_DIR"
    STATUS="NO_GIT"
    MOD_COUNT=0
    ((NOGIT_COUNT++))
  fi

  case "$MODE" in
    --dirty) [ "$STATUS" != "DIRTY" ] && continue ;;
    --clean) [ "$STATUS" != "CLEAN" ] && continue ;;
    --no-git) [ "$STATUS" != "NO_GIT" ] && continue ;;
  esac

  ((TOTAL_DISPLAYED++))

  do_actions "$DISPLAY_DIR" "$STATUS"

  [ "$SUMMARY_ONLY" = true ] && continue

  PROJ_NAME="$(basename "$DISPLAY_DIR")"
  RELATIVE_PATH="$(relative_path "$DISPLAY_DIR")"
  [ "$RELATIVE_PATH" = "." ] && RELATIVE_PATH="./"

  case "$STATUS" in
    CLEAN)
      echo -e "${GREEN}✓${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} ${BG_GREEN} CLEAN / OK ${RESET}"
      print_extra_info "$DISPLAY_DIR"
      ;;
    DIRTY)
      echo -e "${YELLOW}●${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} ${BG_YELLOW} $MOD_COUNT PENDING ${RESET}"
      print_extra_info "$DISPLAY_DIR"
      print_files "$DISPLAY_DIR" "$MOD_COUNT"
      ;;
    NO_GIT)
      echo -e "${RED}✗${RESET} ${BOLD}$PROJ_NAME${RESET} ${DIM}($RELATIVE_PATH)${RESET} ${BG_RED} NO GIT ${RESET}"
      [ "$SHOW_DISK" = true ] && echo -e "    ${CYAN}size:${RESET} $(du -sh "$DISPLAY_DIR" 2>/dev/null | awk '{print $1}')"
      ;;
  esac

done < "$TMP_FILE"

echo -e "\n${DIM}──────────────────────────────────────────────────${RESET}"
echo -e "${BOLD}Résumé :${RESET}"
echo -e "  Total affiché :         $TOTAL_DISPLAYED"
echo -e "  ${GREEN}● Projets propres :${RESET}   $CLEAN_COUNT"
echo -e "  ${YELLOW}● Projets pending :${RESET}   $DIRTY_COUNT"
echo -e "  ${YELLOW}● Fichiers pending :${RESET}  $PENDING_FILES_TOTAL"
echo -e "  ${RED}● Projets sans Git :${RESET}  $NOGIT_COUNT"
echo -e "${DIM}──────────────────────────────────────────────────${RESET}\n"