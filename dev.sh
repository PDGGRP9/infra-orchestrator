#!/usr/bin/env bash
# Teste la stack en local.
#   - services SANS --flag : image :latest RE-TIRÉE de GHCR (pull avant up)
#   - services AVEC --flag : checkout de la branche + build depuis le repo voisin
#
#   ./dev.sh --frontend feature/redesign
#   ./dev.sh --frontend feature/redesign --backend main --db feature/x
#   ./dev.sh --frontend feature/redesign --no-pull -- -d     # hors-ligne / pas de pull
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

FILES=(-f docker-compose.yml -f compose.local.yml)
LOCAL=()
PULL=1
ALL_SVCS=(db backend frontend)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frontend) co webapp-frontend "$2"; FILES+=(-f compose.local.frontend.yml); LOCAL+=(frontend); shift 2;;
    --backend)  co webapp-backend  "$2"; FILES+=(-f compose.local.backend.yml);  LOCAL+=(backend);  shift 2;;
    --db)       co infra-db        "$2"; FILES+=(-f compose.local.db.yml);       LOCAL+=(db);       shift 2;;
    --no-pull)  PULL=0; shift;;
    --) shift; break;;
    -h|--help) sed -n '2,10p' "$0"; exit 0;;
    *) break;;
  esac
done

is_local() { [[ " ${LOCAL[*]:-} " == *" $1 "* ]]; }

# services registry = ceux sans --flag
REGISTRY=()
for s in "${ALL_SVCS[@]}"; do is_local "$s" || REGISTRY+=("$s"); done

echo "-- plan --"
for s in "${ALL_SVCS[@]}"; do
  if is_local "$s"; then
    d=$([ "$s" = db ] && echo infra-db || echo "webapp-$s")
    printf "   %-9s build local  (%s @ %s)\n" "$s" "$d" "$(git -C "$ROOT/$d" branch --show-current)"
  else
    printf "   %-9s GHCR :latest%s\n" "$s" "$([ $PULL = 1 ] && echo ' (pull)')"
  fi
done
echo

if [[ $PULL = 1 && ${#REGISTRY[@]} -gt 0 ]]; then
  docker compose "${FILES[@]}" pull "${REGISTRY[@]}" \
    || echo "!! pull échoué (registre privé ? -> docker login ghcr.io) — images locales utilisées"
fi

exec docker compose "${FILES[@]}" up --build --remove-orphans "$@"
