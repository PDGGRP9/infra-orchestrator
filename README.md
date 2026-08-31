# Branche `local-dev` — tester la stack en local avant merge

Cette branche sert **uniquement au test d'intégration local**. Elle n'est jamais
mergée dans `main`.

Principe : `docker compose up` seul fait tourner toute la stack avec les images
`:latest` publiées sur GHCR. Le script `dev.sh` permet, service par service, de
**remplacer une image registry par un build du code local** (une branche de ton
choix dans le repo voisin) — pour tester une feature avant d'ouvrir la PR.

---

## Prérequis

### 1. Disposition des dossiers

Les repos doivent être clonés **côte à côte**, avec exactement ces noms :

```
un-dossier-parent/
├── infra-orchestrator/   ← ce repo (branche local-dev)
├── infra-db/
├── webapp-backend/       ← attention : le repo GitHub s'appelle "Webapp"
└── webapp-frontend/
```

```bash
git clone git@github.com:PDGGRP9/infra-orchestrator.git
git clone git@github.com:PDGGRP9/infra-db.git
git clone git@github.com:PDGGRP9/Webapp.git webapp-backend
git clone git@github.com:PDGGRP9/webapp-frontend.git

cd infra-orchestrator
git checkout local-dev
```

### 2. Docker + accès GHCR

Docker Desktop récent (Compose ≥ 2.22, pour `pull_policy: build`).

Si les packages `ghcr.io/pdggrp9/*` sont privés, se logger une fois :

```bash
echo <TOKEN_GITHUB> | docker login ghcr.io -u <ton-user-github> --password-stdin
```

(le token doit avoir le scope `read:packages`)

---

## Utilisation

Depuis `infra-orchestrator/` :

```bash
# tout en :latest depuis GHCR
docker compose up

# tester la branche feature/redesign du frontend, le reste en :latest
./dev.sh --frontend feature/redesign

# combiner plusieurs repos
./dev.sh --frontend feature/redesign --backend feature/x --db main

# options
./dev.sh --frontend feature/redesign --no-pull        # ne pas re-tirer les :latest (hors-ligne)
./dev.sh --frontend feature/redesign -- -d            # tout ce qui suit `--` va à `docker compose up`
```

Ce que fait `dev.sh` pour chaque `--<service> <branche>` :

1. `git checkout <branche>` dans le repo voisin correspondant ;
2. ajoute le fichier `compose.local.<service>.yml` qui remplace l'image par un
   `build:` depuis ce repo (taggé `pdg-local/<service>:dev`, sans écraser les
   tags GHCR) ;
3. les services **sans** `--flag` sont re-tirés de GHCR (`docker compose pull`)
   puis lancés tels quels.

| Commande | db | backend | frontend |
|---|---|---|---|
| `docker compose up` | GHCR `:latest` | GHCR `:latest` | GHCR `:latest` |
| `./dev.sh --frontend X` | GHCR `:latest` | GHCR `:latest` | build local `@X` |
| `./dev.sh --frontend X --db Y` | build local `@Y` | GHCR `:latest` | build local `@X` |

### Accès

| | URL |
|---|---|
| Frontend | http://localhost:3000 |
| Backend (direct) | http://localhost:8000 |
| Postgres | `localhost:5432` (`bracelet` / `bracelet` / db `bracelet_connecte`) |

Comptes de démo : voir `infra-db/initdb/002-seed.sql` de la version que tu fais
tourner (le mot de passe dépend de l'image/branche db).

### Depuis un téléphone physique

Mettre l'IP LAN de ta machine (pas `localhost`, pas `10.0.2.2`) dans le champ
« URL du back-end » de l'app :

```
http://<IP-LAN-de-ta-machine>:8000
```

`ipconfig getifaddr en0` (macOS) / `ip addr` (Linux) pour trouver l'IP.
Téléphone et machine sur le même réseau ; attention à l'isolation client sur les
Wi-Fi de campus (contournement : partage de connexion du téléphone).

---

## Fichiers de la branche

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` | stack de base, images `:latest` par défaut (variables `*_IMAGE` surchargeables) |
| `compose.local.yml` | **toujours** appliqué par `dev.sh` : healthcheck db + `backend` attend `db` healthy |
| `compose.local.{db,backend,frontend}.yml` | ajout d'un `build:` pour ce service, appliqué seulement via le `--flag` |
| `dev.sh` | orchestration : checkout des branches voisines + `-f` sélectifs + pull + `up --build` |

> ⚠️ Il n'y a **volontairement pas** de `docker-compose.override.yml` : ce nom est
> chargé automatiquement par Compose et s'appliquerait même à un `docker compose up`
> normal. Tout passe par des `-f` explicites dans `dev.sh`.

---

## Pièges connus

**Un `:latest` local « pollué ».** Si un jour un service a été buildé avec un
`build:` sans `image:` distinct, l'image locale a pu être taggée
`ghcr.io/pdggrp9/<x>:latest` et masque la vraie image registry. Pour repartir
propre :

```bash
docker rmi ghcr.io/pdggrp9/infra-db:latest \
           ghcr.io/pdggrp9/webapp-backend:latest \
           ghcr.io/pdggrp9/webapp-frontend:latest
docker compose down -v          # -v = repart d'une db vierge (re-seed)
./dev.sh --frontend <branche>
```

Vérifier l'origine d'une image : `docker image inspect <img> --format '{{.RepoDigests}}'`
→ `[]` = build local, une valeur `sha256:...` = tirée du registre.

**`.env`.** Compose charge automatiquement `infra-orchestrator/.env`. Ne pas y
mettre les valeurs de la VM (elles écraseraient `CORS_ALLOWED_ORIGINS`, etc. et
casseraient le login local). `.env` et `.env.*` sont dans `.gitignore`.

**Course db/backend.** Réglée par `compose.local.yml`. Si tu lances la stack
sans `dev.sh` (`docker compose up` seul), le backend peut redémarrer 1 fois au
premier boot le temps que Postgres s'initialise — sans gravité.

---

## Garder `local-dev` à jour

Quand `main` bouge (nouvelle version du `docker-compose.yml`, etc.) :

```bash
git checkout local-dev
git merge main
git push
```

Les fichiers `compose.local.*` et `dev.sh` n'existent que sur cette branche, il
n'y a donc pas de conflit sur eux.
