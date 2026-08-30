# Déploiement sur la VM

Stack : PostgreSQL + backend Django + frontend (nginx) + fake-emitter.
Tout est servi en **HTTP sur le port 8080** de la VM.

```
navigateur ──http──> :8080  frontend (nginx)
                              ├─ /       fichiers statiques (SPA)
                              └─ /api/   proxy ─> backend:8000 (réseau interne)
backend ─> db:5432 (réseau interne)
fake-emitter ─> backend:8000 (réseau interne, données de démo)
```

Le backend n'est **pas** exposé publiquement : le navigateur ne parle qu'au
port 8080, nginx relaie `/api`. Donc pas de CORS, un seul port à ouvrir.

## Prérequis VM

- Docker + plugin Compose v2 (`docker compose version`)
- Port `8080/tcp` ouvert dans le firewall / security group
- Images GHCR publiques (sinon `docker login ghcr.io` avec un PAT `read:packages`)

## Première mise en route

```bash
git clone <url> infra-orchestrator && cd infra-orchestrator
git checkout deploy/vm-8080

cp .env.example .env
nano .env        # mot de passe DB + SECRET_KEY + ALLOWED_HOSTS

docker compose pull
docker compose up -d
docker compose ps
```

Ouvrir `http://<IP_ou_domaine_VM>:8080`.

Ne pas créer de `docker-compose.override.yml` sur la VM (il sert au build local
et forcerait une reconstruction des images).

## Mise à jour (nouvelle release)

```bash
git pull
# bumper les tags dans .env : WEBAPP_FRONTEND_IMAGE / WEBAPP_BACKEND_IMAGE / DB_IMAGE
docker compose pull
docker compose up -d
```

## Opérations courantes

```bash
docker compose logs -f backend            # logs
docker compose down                       # stop (garde le volume db-data)
docker compose up -d --scale fake-emitter=0   # sans données de démo
psql via tunnel : ssh -L 5432:127.0.0.1:5432 user@vm   puis psql -h localhost -U bracelet bracelet_connecte
```

## Reset base de données

```bash
docker compose down
docker volume rm infra-orchestrator_db-data
docker compose up -d
```
