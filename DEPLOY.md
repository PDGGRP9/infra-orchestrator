# Déploiement sur la VM (HTTPS)

Stack : PostgreSQL + backend Django + frontend (nginx) + Caddy.
Tout est servi en **HTTPS sur le port 443** de la VM. Caddy obtient et renouvelle
seul un certificat Let's Encrypt et redirige `80` -> `443`.

```
navigateur ──https──> :443  Caddy (terminaison TLS, Let's Encrypt)
                 :80  ──> redirection 308 vers https
                              │
                              └─> frontend:80 (nginx, réseau interne)
                                    ├─ /       fichiers statiques (SPA)
                                    └─ /api/   proxy ─> backend:8000 (réseau interne)
backend ─> db:5432 (réseau interne)
```

Le backend et le frontend ne sont **pas** exposés publiquement : seul Caddy
publie des ports (`80`, `443`). Single-origin, donc pas de CORS navigateur.

## Prérequis VM

- Docker + plugin Compose v2 (`docker compose version`)
- Un **nom de domaine public** dont l'enregistrement DNS `A` (et `AAAA` si IPv6)
  pointe vers l'IP publique de la VM. Vérifier : `dig +short <domaine>`
- Ports `80/tcp` et `443/tcp` (+ `443/udp` pour HTTP/3) ouverts dans le
  firewall / security group. Le port `80` est requis pour le challenge ACME.
- Images GHCR publiques (sinon `docker login ghcr.io` avec un PAT `read:packages`)

## Firewall (exemple `ufw`)

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw delete allow 8080/tcp   # si l'ancien port HTTP était ouvert
sudo ufw enable
sudo ufw status
```

Sur un cloud (AWS/GCP/Azure/OpenStack), ouvrir 80 + 443 dans le security group
et retirer 8080.

## Première mise en route

```bash
git clone <url> infra-orchestrator && cd infra-orchestrator

cp .env.example .env
nano .env    # SITE_DOMAIN, ACME_EMAIL, POSTGRES_PASSWORD, DJANGO_SECRET_KEY,
             # ALLOWED_HOSTS, CORS_ALLOWED_ORIGINS

docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f caddy    # suivre l'obtention du certificat
```

Le premier certificat prend quelques secondes. Ouvrir `https://<SITE_DOMAIN>`.

### Tester d'abord avec le CA de staging

Pour éviter d'épuiser le quota Let's Encrypt en cas d'erreur DNS/firewall,
décommenter la ligne `acme_ca ...staging...` dans `caddy/Caddyfile`, lancer,
vérifier que tout marche, puis la recommenter et :

```bash
docker compose exec caddy rm -rf /data/caddy    # purge le cert de staging
docker compose restart caddy
```

## Mise à jour (nouvelle release)

```bash
git pull
# bumper les tags dans .env : WEBAPP_FRONTEND_IMAGE / WEBAPP_BACKEND_IMAGE / DB_IMAGE
docker compose pull
docker compose up -d
```

## Activer HSTS (après validation du HTTPS)

Une fois le certificat en place et le site stable :

```bash
# .env
SECURE_HSTS_SECONDS=31536000
```

puis `docker compose up -d backend`. (Optionnel : décommenter la ligne
`header Strict-Transport-Security` du Caddyfile.)

## Opérations courantes

```bash
docker compose logs -f backend            # logs applicatifs
docker compose logs -f caddy              # TLS / ACME
docker compose down                       # stop (garde les volumes)
# psql via tunnel :
ssh -L 5432:127.0.0.1:5432 user@vm    # puis: psql -h localhost -U bracelet bracelet_connecte
```

Les certificats sont persistés dans le volume `caddy-data` : ils survivent à
`docker compose down` et ne sont pas réémis à chaque redémarrage.

## Reset base de données

```bash
docker compose down
docker volume rm infra-orchestrator_db-data
docker compose up -d
```
