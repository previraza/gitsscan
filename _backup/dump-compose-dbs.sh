#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="0.1.0"

TARGET_DIR="."
OUT_DIR="./db-dumps"
DO_ZIP=false
ZIP_NAME="db-dumps.zip"
DRY_RUN=false

log(){ printf '%b\n' "$*"; }
die(){ log "Erreur: $*"; exit 1; }
trap 'ec=$?; log "Erreur: exit=$ec ligne=${BASH_LINENO[0]}: ${BASH_COMMAND}"; exit $ec' ERR

help() {
cat << EOF
dump-compose-dbs v$VERSION

Scanne des docker-compose.yml/.yaml et dump les bases des services DB détectés
(postgres, mysql/mariadb, mongo) depuis les conteneurs en cours d'exécution.

USAGE:
  dump-compose-dbs [dossier] [options]

OPTIONS:
  --out=DIR        Dossier de sortie (défaut: $OUT_DIR)
  --zip            Crée une archive zip à la fin
  --zip-name=NAME  Nom du zip (défaut: $ZIP_NAME)
  --dry-run        Affiche les actions sans exécuter
  -h, --help       Aide
  -v, --version    Version

NOTES:
  - Nécessite: docker + "docker compose"
  - Dump uniquement si le service DB est "running"
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

zip_output() {
  local out="$1" zip_name="$2"
  if command -v zip >/dev/null 2>&1; then
    # Write the archive outside the folder being archived to avoid "file changed as we read it".
    local tmp_zip
    tmp_zip="$(mktemp -u "${out%/}/.tmp-${zip_name}.XXXXXX")"
    (cd "$out" && run_cmd zip -r "$tmp_zip" .)
    run_cmd mv -f "$tmp_zip" "$out/$zip_name"
    log "OK: archive créée: $out/$zip_name"
    return 0
  fi
  if command -v tar >/dev/null 2>&1; then
    local tar_name="${zip_name%.zip}.tar.gz"
    # Exclude the archive itself if it ends up inside the folder.
    run_cmd tar -czf "$out/$tar_name" -C "$out" --exclude "./$tar_name" .
    log "OK: zip absent, archive créée: $out/$tar_name"
    return 0
  fi
  die "Ni zip ni tar disponibles pour archiver"
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Commande manquante: $1"; }

compose_cmd() { docker compose -f "$1" "${@:2}"; }

service_image() {
  # Extract image for a service using `docker compose config`
  local file="$1" service="$2"
  compose_cmd "$file" config 2>/dev/null | awk -v svc="$service" '
    $1=="services:" {in_services=1; next}
    in_services && $1==svc":" {in_svc=1; next}
    in_svc && $1=="image:" {print $2; exit}
    in_svc && /^[^ ]/ {exit}
  '
}

detect_db_kind() {
  local image="$1"
  image="${image,,}"
  case "$image" in
    *postgres*) printf 'postgres\n' ;;
    *mariadb*) printf 'mysql\n' ;;
    *mysql*) printf 'mysql\n' ;;
    *mongo*) printf 'mongo\n' ;;
    *) printf '\n' ;;
  esac
}

container_id_for_service() {
  local file="$1" service="$2"
  compose_cmd "$file" ps -q "$service" 2>/dev/null | head -n 1
}

container_running() {
  local cid="$1"
  [ -n "$cid" ] || return 1
  docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null | grep -q '^true$'
}

dump_postgres() {
  local cid="$1" dest="$2"
  # Prefer pg_dumpall (includes roles/dbs). If it fails, fall back to pg_dump of $POSTGRES_DB.
  run_cmd bash -lc "docker exec -i \"$cid\" sh -lc 'pg_dumpall -U \"\${POSTGRES_USER:-postgres}\"' > \"${dest}\"" || true
  if [ "$DRY_RUN" != true ] && [ ! -s "$dest" ]; then
    run_cmd bash -lc "docker exec -i \"$cid\" sh -lc 'pg_dump -U \"\${POSTGRES_USER:-postgres}\" \"\${POSTGRES_DB:-postgres}\"' > \"${dest}\""
  fi
}

dump_mysql() {
  local cid="$1" dest="$2"
  # Dump all databases. Uses MYSQL_* env vars if present.
  run_cmd bash -lc "docker exec -i \"$cid\" sh -lc 'mysqldump -u\"\${MYSQL_USER:-root}\" -p\"\${MYSQL_PASSWORD:-\$MYSQL_ROOT_PASSWORD}\" --all-databases --single-transaction' > \"${dest}\""
}

dump_mongo() {
  local cid="$1" outdir="$2"
  run_cmd mkdir -p "$outdir"
  run_cmd docker exec -i "$cid" sh -lc 'mongodump --archive --gzip' > "$outdir/dump.archive.gz"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) help; exit 0 ;;
    -v|--version) printf 'dump-compose-dbs v%s\n' "$VERSION"; exit 0 ;;
    --out=*) OUT_DIR="${1#*=}"; shift ;;
    --zip) DO_ZIP=true; shift ;;
    --zip-name=*) ZIP_NAME="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -*) die "Option inconnue: $1" ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

[ -d "$TARGET_DIR" ] || die "Le dossier '$TARGET_DIR' n'existe pas"

require_cmd docker
docker compose version >/dev/null 2>&1 || die "docker compose indisponible (plugin compose manquant ?)"

run_cmd mkdir -p "$OUT_DIR"

ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || date)"

mapfile -t compose_files < <(
  find "$TARGET_DIR" \
    -type d \( -name node_modules -o -name .git -o -name vendor -o -name .next -o -name dist -o -name build -o -name coverage -o -name .turbo \) -prune -o \
    -type f \( -name docker-compose.yml -o -name docker-compose.yaml -o -name compose.yml -o -name compose.yaml \) -print 2>/dev/null
)
if [ "${#compose_files[@]}" -eq 0 ]; then
  die "Aucun docker-compose trouvé dans $TARGET_DIR"
fi

log "Found: ${#compose_files[@]} compose file(s)"

for file in "${compose_files[@]}"; do
  proj_dir="$(cd "$(dirname "$file")" && pwd)"
  rel="${file#"$TARGET_DIR"/}"
  safe_rel="${rel//\//__}"
  log ""
  log "== $rel =="

  mapfile -t services < <(compose_cmd "$file" config --services 2>/dev/null || true)
  [ "${#services[@]}" -gt 0 ] || { log "  skip: services introuvables"; continue; }

  for svc in "${services[@]}"; do
    img="$(service_image "$file" "$svc" || true)"
    kind="$(detect_db_kind "${img:-}")"
    [ -n "$kind" ] || continue

    cid="$(container_id_for_service "$file" "$svc" || true)"
    if ! container_running "$cid"; then
      log "  - $svc ($kind): skip (container non running)"
      continue
    fi

    out_base="$OUT_DIR/$safe_rel/$svc/$ts"
    run_cmd mkdir -p "$out_base"

    case "$kind" in
      postgres)
        log "  - $svc (postgres): dump -> $out_base/${svc}.sql"
        dump_postgres "$cid" "$out_base/${svc}.sql"
        ;;
      mysql)
        log "  - $svc (mysql): dump -> $out_base/${svc}.sql"
        dump_mysql "$cid" "$out_base/${svc}.sql"
        ;;
      mongo)
        log "  - $svc (mongo): dump -> $out_base/"
        dump_mongo "$cid" "$out_base"
        ;;
    esac
  done
done

log ""
log "OK: dumps dans $OUT_DIR"
if [ "$DO_ZIP" = true ]; then
  zip_output "$OUT_DIR" "$ZIP_NAME"
fi
