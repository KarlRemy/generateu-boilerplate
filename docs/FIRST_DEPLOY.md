# Premier deploiement - Guide pas a pas

Guide complet pour deployer le boilerplate Generateu sur le VPS pour la premiere fois.

## Pre-requis

- Acces SSH au VPS : `ssh ubuntu@91.134.132.141`
- Docker et Docker Compose installes sur le VPS
- DNS wildcard configure (voir `docs/DNS_SETUP.md`)
- Certificat SSL wildcard genere
- Reseau Docker `generateu_network` cree

## Etape 1 : Preparer le VPS

```bash
ssh ubuntu@91.134.132.141
```

### Installer Docker (si pas deja fait)

```bash
# Installer Docker
curl -fsSL https://get.docker.com | sh

# Ajouter l'utilisateur ubuntu au groupe docker
sudo usermod -aG docker ubuntu

# Se reconnecter pour appliquer le groupe
exit
ssh ubuntu@91.134.132.141

# Verifier l'installation
docker --version
docker compose version
```

### Creer le reseau Docker partage

```bash
# Ce reseau est partage entre tous les projets et le reverse proxy Caddy
docker network create generateu_network
```

### Installer PostgreSQL partage

```bash
# Creer le repertoire de donnees
sudo mkdir -p /opt/postgresql/data

# Lancer PostgreSQL 16 avec PostGIS
docker run -d \
  --name generateu_postgres \
  --network generateu_network \
  --restart always \
  -e POSTGRES_USER=generateu \
  -e POSTGRES_PASSWORD=<MOT_DE_PASSE_SECURISE> \
  -v /opt/postgresql/data:/var/lib/postgresql/data \
  -p 127.0.0.1:5432:5432 \
  postgis/postgis:16-3.4

# Verifier que PostgreSQL est en marche
docker logs generateu_postgres
```

### Installer Caddy comme reverse proxy

```bash
# Creer le repertoire de configuration
sudo mkdir -p /opt/caddy

# Lancer Caddy
docker run -d \
  --name generateu_caddy \
  --network generateu_network \
  --restart always \
  -p 80:80 \
  -p 443:443 \
  -v /opt/caddy/Caddyfile:/etc/caddy/Caddyfile \
  -v /opt/caddy/data:/data \
  -v /opt/caddy/config:/config \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  caddy:2
```

## Etape 2 : Deployer le boilerplate

### Cloner le repository

```bash
# Creer le repertoire des projets
sudo mkdir -p /home/ubuntu/projects
cd /home/ubuntu/projects

# Cloner le boilerplate
git clone git@github.com:karl-music/generateu-symfony.git
cd generateu-symfony
```

### Configurer les variables d'environnement

```bash
# Copier le fichier d'environnement
cp .env .env.prod.local

# Editer les variables de production
nano .env.prod.local
```

Variables importantes a configurer :

```env
APP_ENV=prod
APP_SECRET=<GENERER_UN_SECRET_UNIQUE>
DATABASE_URL="postgresql://generateu:<PASSWORD>@generateu_postgres:5432/<NOM_PROJET>?serverVersion=16&charset=utf8"
MAILER_DSN=smtp://smtp.example.com:587
MERCURE_URL=https://<NOM_PROJET>.karl-remy.fr/.well-known/mercure
MERCURE_PUBLIC_URL=https://<NOM_PROJET>.karl-remy.fr/.well-known/mercure
MERCURE_JWT_SECRET=<SECRET_MERCURE>
```

### Creer la base de donnees

```bash
# Se connecter au container PostgreSQL
docker exec -it generateu_postgres psql -U generateu

# Creer la base
CREATE DATABASE "<nom_projet>";
\q
```

### Build et demarrer le projet

```bash
# Definir les variables pour docker-compose.prod.yml
export PROJECT_NAME=<nom_projet>
export APP_PORT=<port_unique>  # ex: 8081, 8082, ...

# Build l'image de production
docker compose -f docker-compose.prod.yml build

# Demarrer le container
docker compose -f docker-compose.prod.yml up -d

# Executer les migrations
docker exec ${PROJECT_NAME}_app php bin/console doctrine:migrations:migrate --no-interaction

# Charger les fixtures (compte admin)
docker exec ${PROJECT_NAME}_app php bin/console doctrine:fixtures:load --no-interaction

# Compiler Tailwind
docker exec ${PROJECT_NAME}_app php bin/console tailwind:build
```

### Verifier le deploiement

```bash
# Verifier que le container tourne
docker ps | grep ${PROJECT_NAME}

# Verifier les logs
docker logs ${PROJECT_NAME}_app

# Tester la sante
curl http://localhost:${APP_PORT}/health
```

## Etape 3 : Configurer le reverse proxy Caddy

Ajouter le bloc de configuration pour le nouveau projet dans `/opt/caddy/Caddyfile` :

```
<nom-projet>.karl-remy.fr {
    tls /etc/letsencrypt/live/karl-remy.fr/fullchain.pem /etc/letsencrypt/live/karl-remy.fr/privkey.pem

    reverse_proxy <nom_projet>_app:8080
}
```

Recharger la configuration Caddy :

```bash
docker exec generateu_caddy caddy reload --config /etc/caddy/Caddyfile
```

## Etape 4 : Verifier le resultat

```bash
# Tester l'acces HTTPS
curl -I https://<nom-projet>.karl-remy.fr

# Ouvrir dans un navigateur
# URL : https://<nom-projet>.karl-remy.fr
# Admin : https://<nom-projet>.karl-remy.fr/admin
# Login : admin@example.com / password
```

## Etape 5 : Automatiser avec le script deploy.sh

Pour les deploiements suivants, utiliser le script `infra/deploy.sh` qui automatise toutes ces etapes :

```bash
sudo bash /home/ubuntu/generateu-symfony/infra/deploy.sh <nom-du-projet>
```

Ou via Claude Code :

```
/create-project mon-nouveau-saas
```

## Mise a jour d'un projet existant

```bash
cd /home/ubuntu/projects/<nom-projet>
git pull origin main
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
docker exec ${PROJECT_NAME}_app php bin/console doctrine:migrations:migrate --no-interaction
docker exec ${PROJECT_NAME}_app php bin/console tailwind:build
docker exec ${PROJECT_NAME}_app php bin/console cache:clear
```

Ou via le script :

```bash
sudo bash /home/ubuntu/<nom-projet>/infra/redeploy.sh
```

## Suppression d'un projet

```bash
sudo bash /home/ubuntu/<nom-projet>/infra/destroy.sh
```

Ce script :
- Arrete et supprime les containers Docker
- Supprime la base de donnees PostgreSQL
- Retire la configuration Caddy
- Supprime les fichiers du projet

## Depannage

### Le container ne demarre pas

```bash
# Verifier les logs
docker logs ${PROJECT_NAME}_app --tail 50

# Verifier la configuration
docker compose -f docker-compose.prod.yml config

# Rebuild complet
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d
```

### Erreur de connexion a la base de donnees

```bash
# Verifier que PostgreSQL est accessible
docker exec -it generateu_postgres pg_isready

# Verifier que la base existe
docker exec -it generateu_postgres psql -U generateu -l

# Tester la connexion depuis le container app
docker exec ${PROJECT_NAME}_app php bin/console doctrine:database:create --if-not-exists
```

### Le sous-domaine ne fonctionne pas

```bash
# Verifier le DNS
dig <nom-projet>.karl-remy.fr +short

# Verifier la config Caddy
docker exec generateu_caddy caddy validate --config /etc/caddy/Caddyfile

# Verifier les logs Caddy
docker logs generateu_caddy --tail 50
```

### Erreur 502 Bad Gateway

```bash
# Verifier que le container app est sur le bon reseau
docker network inspect generateu_network

# Verifier que le port est correct
docker port ${PROJECT_NAME}_app
```
