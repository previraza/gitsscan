#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="1.0.0"

TARGET_DIR="."
OUT_DIR="./env-exports"
DO_ZIP=false
ZIP_NAME="env-exports.zip"
NO_GIT=false
DRY_RUN=false
INCLUDE_EXAMPLE=false
INCLUDE_ALL_UNTRACKED=false

log(){ printf '%b\n' "$*"; }
die(){ log "Erreur: $*"; exit 1; }
trap 'ec=$?; log "Erreur: exit=$ec ligne=${BASH_LINENO[0]}: ${BASH_COMMAND}"; exit $ec' ERR

help() {
cat << EOF
collect-envs v$VERSION

USAGE:
  collect-envs [dossier] [options]

OPTIONS:
  --out=DIR            Dossier de sortie (défaut: $OUT_DIR)
  --zip                Crée une archive zip à la fin
  --zip-name=NAME      Nom du zip (défaut: $ZIP_NAME)
  --no-git              Inclut aussi les projets non-git (défaut: off)
  --include-example    Copie aussi .env.example / .env.sample (défaut: off)
  --all-untracked      Copie tous les fichiers non-trackés (dangereux)
  --dry-run            Affiche ce qui serait copié
  -h, --help           Aide
  -v, --version        Version

EXAMPLES:
  collect-envs /var/www --out=/tmp/envs --zip
  collect-envs /var/www --include-example --zip-name=envs.zip
EOF
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    local rendered=""
    for arg in "$@"; do rendered+=" $(printf '%q' "$arg")"; done
    log "DRY-RUN:${rendered}"
    return 0
  fi
  "$@"
}

relative_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath --relative-to="$TARGET_DIR" "$p" 2>/dev/null || printf '%s\n' "$p"
  else
    printf '%s\n' "$p"
  fi
}

is_project_marker() {
  case "$(basename "$1")" in
    package.json|composer.json|artisan|vite.config.js|vite.config.ts|next.config.js|next.config.ts|index.php) return 0 ;;
    *) return 1 ;;
  esac
}

collect_env_files_in_dir() {
  local dir="$1"
  local f

  # Root-level envs (common)
  for f in "$dir"/.env "$dir"/.env.* "$dir"/*.env; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      .env.example|.env.sample) [ "$INCLUDE_EXAMPLE" = true ] || continue ;;
    esac
    printf '%s\n' "$f"
  done
}

is_sensitive_filename() {
  # Return 0 when the (repo-relative) path looks like an env/secret file.
  # We target files that are typically NOT committed for security.
  # We intentionally do NOT match SSH private keys by default.
  local rel="$1"

  case "$rel" in
    .env|.env.*|*.env) return 0 ;;
    */.env|*/.env.*|*/*.env) return 0 ;;
    .npmrc|.pypirc|.netrc) return 0 ;;
    .aws/credentials|.aws/config) return 0 ;;
    .kube/config) return 0 ;;
    .docker/config.json) return 0 ;;
    docker-compose.override.yml) return 0 ;;
    *.pem|*.p12|*.pfx) return 0 ;;
    secrets.*|*.secret|*.secrets) return 0 ;;
  esac

  return 1
}

list_sensitive_untracked_git() {
  local root="$1"
  # Print repo-relative paths (one per line)
  if [ "$INCLUDE_ALL_UNTRACKED" = true ]; then
    git -C "$root" ls-files -o --exclude-standard
    return 0
  fi

  git -C "$root" ls-files -o --exclude-standard | while IFS= read -r rel; do
    is_sensitive_filename "$rel" && printf '%s\n' "$rel"
  done
}

list_sensitive_files_nogit() {
  local root="$1"
  # Walk the project root and match sensitive patterns.
  # Excludes heavy folders similar to gitss.
  find "$root" \
    -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
    -type f -print | while IFS= read -r path; do
      rel="${path#"$root"/}"
      is_sensitive_filename "$rel" && printf '%s\n' "$rel"
    done
}

zip_output() {
  local out="$1" zip_name="$2"

  if command -v zip >/dev/null 2>&1; then
    (cd "$out" && run_cmd zip -r "$zip_name" .)
    log "OK: archive créée: $out/$zip_name"
    return 0
  fi

  if command -v tar >/dev/null 2>&1; then
    (cd "$out" && run_cmd tar -czf "${zip_name%.zip}.tar.gz" .)
    log "OK: zip absent, archive créée: $out/${zip_name%.zip}.tar.gz"
    return 0
  fi

  die "Ni zip ni tar disponibles pour archiver"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) help; exit 0 ;;
    -v|--version) printf 'collect-envs v%s\n' "$VERSION"; exit 0 ;;
    --out=*) OUT_DIR="${1#*=}"; shift ;;
    --zip) DO_ZIP=true; shift ;;
    --zip-name=*) ZIP_NAME="${1#*=}"; shift ;;
    --no-git) NO_GIT=true; shift ;;
    --include-example) INCLUDE_EXAMPLE=true; shift ;;
    --all-untracked) INCLUDE_ALL_UNTRACKED=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -*) die "Option inconnue: $1" ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

[ -d "$TARGET_DIR" ] || die "Le dossier '$TARGET_DIR' n'existe pas"

run_cmd mkdir -p "$OUT_DIR"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT INT TERM

find "$TARGET_DIR" \
  -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
  -type f \( -name package.json -o -name composer.json -o -name artisan -o -name vite.config.js -o -name vite.config.ts -o -name next.config.js -o -name next.config.ts -o -name index.php \) \
  -print > "$TMP_FILE"

declare -A SEEN_ROOTS=()
COPIED_COUNT=0
PROJECTS_COUNT=0

MANIFEST="$OUT_DIR/manifest.txt"
if [ "$DRY_RUN" = true ]; then
  : > /dev/null
else
  : > "$MANIFEST"
fi

while IFS= read -r marker; do
  is_project_marker "$marker" || continue

  project_dir="$(dirname "$marker")"
  git_root="$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null || true)"

  root="$project_dir"
  root_kind="NO_GIT"
  if [ -n "$git_root" ]; then
    root="$git_root"
    root_kind="GIT"
  else
    [ "$NO_GIT" = true ] || continue
  fi

  [ -n "${SEEN_ROOTS["$root"]+x}" ] && continue
  SEEN_ROOTS["$root"]=1
  PROJECTS_COUNT=$((PROJECTS_COUNT + 1))

  rel="$(relative_path "$root")"
  [ "$rel" = "." ] && rel="./"

  out_project="$OUT_DIR/$rel"
  run_cmd mkdir -p "$out_project"

  # 1) Always include obvious root-level env files
  mapfile -t direct_envs < <(collect_env_files_in_dir "$root")

  # 2) Prefer git-untracked listing when git repo
  if [ "$root_kind" = "GIT" ]; then
    mapfile -t relpaths < <(list_sensitive_untracked_git "$root")
  else
    mapfile -t relpaths < <(list_sensitive_files_nogit "$root")
  fi

  # Merge + de-dup
  declare -A seen_files=()
  files_to_copy=()
  for f in "${direct_envs[@]}"; do
    [ -f "$f" ] || continue
    r="${f#"$root"/}"
    [ -n "${seen_files["$r"]+x}" ] && continue
    seen_files["$r"]=1
    files_to_copy+=("$r")
  done
  for r in "${relpaths[@]}"; do
    [ -n "$r" ] || continue
    [ -n "${seen_files["$r"]+x}" ] && continue
    seen_files["$r"]=1
    files_to_copy+=("$r")
  done

  if [ "${#files_to_copy[@]}" -eq 0 ]; then
    continue
  fi

  log "• $rel ($root_kind): ${#files_to_copy[@]} fichier(s) sensibles"

  for r in "${files_to_copy[@]}"; do
    src="$root/$r"
    [ -f "$src" ] || continue
    dest="$out_project/$r"
    run_cmd mkdir -p "$(dirname "$dest")"
    run_cmd cp -f -- "$src" "$dest"
    COPIED_COUNT=$((COPIED_COUNT + 1))
    if [ "$DRY_RUN" != true ]; then
      printf '%s\t%s\n' "$src" "$dest" >> "$MANIFEST"
    fi
  done
done < "$TMP_FILE"

log ""
log "Résumé:"
log "  Projets scannés:  $PROJECTS_COUNT"
log "  Fichiers copiés:  $COPIED_COUNT"
log "  Sortie:           $OUT_DIR"
if [ "$DRY_RUN" != true ]; then
  log "  Manifest:         $MANIFEST"
fi

if [ "$DO_ZIP" = true ]; then
  zip_output "$OUT_DIR" "$ZIP_NAME"
fi
