#!/usr/bin/env bash
# Teste la stack en local. Par défaut : images :latest de GHCR pour tous les services.
# Chaque --xxx BRANCHE : checkout cette branche dans le repo voisin ET build ce
# service-là depuis le code local (le reste reste sur l'image de la registry).
#
#   ./dev.sh --frontend feature/redesign
#   ./dev.sh --frontend feature/redesign --backend main --db feature/x
#   ./dev.sh --frontend feature/redesign --pull -- -d      # --pull : re-pull les :latest
#
set -euo pipefail
cd "$(dirname "$0")"
ROOT=".."

co() {  # co <dossier> <branche>
  echo "> $1 -> $2"
  git -C "$ROOT/$1" fetch -q origin "$2"
  git -C "$ROOT/$1" checkout -q "$2"
  git -C "$ROOT/$1" pull -q --ff-only 2>/dev/null || true
}

FILES=(-f docker-compose.yml)
LOCAL=()          # services buildés en local
PULL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frontend) co webapp-frontend "$2"; FILES+=(-f compose.local.frontend.yml); LOCAL+=(frontend); shift 2;;
    --backend)  co webapp-backend  "$2"; FILES+=(-f compose.local.backend.yml);  LOCAL+=(backend);  shift 2;;
    --db)       co infra-db        "$2"; FILES+=(-f compose.local.db.yml);       LOCAL+=(db);       shift 2;;
    --pull)     PULL="--pull always"; shift;;
    --) shift; break;;
    -h|--help) sed -n '2,10p' "$0"; exit 0;;
    *) break;;
  esac
done

echo "-- plan --"
for svc in db backend frontend; do
  if [[ " ${LOCAL[*]:-} " == *" $svc "* ]]; then
    d=$([ "$svc" = db ] && echo infra-db || echo "webapp-$svc")
    printf "   %-9s build local  (%s @ %s)\n" "$svc" "$d" "$(git -C "$ROOT/$d" branch --show-current)"
  else
    printf "   %-9s image GHCR :latest\n" "$svc"
  fi
done
echo

# --build ne rebuild que les services ayant une section build = ceux sélectionnés
# (+ les fake-emitter, triviaux et cachés).
exec docker compose "${FILES[@]}" up --build $PULL --remove-orphans "$@"
