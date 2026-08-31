#!/usr/bin/env bash
# Teste la stack complète en local en choisissant la branche de chaque repo.
#
# Usage :
#   ./dev.sh --frontend feature/redesign --db feature/renforced_pwd
#   ./dev.sh --frontend feature/redesign -- -d        # passe -d (détaché) à `compose up`
#   ./dev.sh                                          # rebuild ce qui est déjà checkout
#
# Chaque --xxx fait un `git checkout` dans le repo voisin correspondant.
# L'override (docker-compose.override.yml de cette branche) force le build
# de db/backend/frontend depuis ../infra-db, ../webapp-backend, ../webapp-frontend.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=".."

co() {  # co <dossier> <branche>
  [ -z "${2:-}" ] && return 0
  echo "> $1 -> $2"
  git -C "$ROOT/$1" fetch -q origin "$2"
  git -C "$ROOT/$1" checkout -q "$2"
  git -C "$ROOT/$1" pull -q --ff-only 2>/dev/null || true
}

DB="" BACK="" FRONT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)       DB="$2";    shift 2;;
    --backend)  BACK="$2";  shift 2;;
    --frontend) FRONT="$2"; shift 2;;
    --) shift; break;;
    -h|--help) sed -n '2,13p' "$0"; exit 0;;
    *) break;;
  esac
done

co infra-db "$DB"
co webapp-backend "$BACK"
co webapp-frontend "$FRONT"

echo "-- branches actives --"
for d in infra-db webapp-backend webapp-frontend infra-orchestrator; do
  if [ "$d" = infra-orchestrator ]; then b=$(git branch --show-current); else b=$(git -C "$ROOT/$d" branch --show-current); fi
  printf "   %-20s %s\n" "$d" "$b"
done
echo

exec docker compose up --build --remove-orphans "$@"
