# Generateu

Boilerplate Symfony pour le deploiement rapide de projets SaaS sous **karl-remy.fr**.

Chaque nouveau projet est genere a partir de ce boilerplate et deploye automatiquement en tant que sous-domaine sur un VPS partage.

## Stack technique

| Composant        | Version / Detail                          |
|------------------|-------------------------------------------|
| PHP              | 8.4                                       |
| Symfony          | 7.2                                       |
| Serveur          | FrankenPHP (worker mode)                  |
| Base de donnees  | PostgreSQL 16 + PostGIS                   |
| CSS              | Tailwind CSS 4                            |
| API              | API Platform 4                            |
| Temps reel       | Mercure                                   |
| Frontend         | Asset Mapper + Stimulus + Turbo           |
| Icons            | UX Icons                                  |
| DataTables       | pentiminax/ux-datatables                  |

## Demarrage rapide

```bash
# Cloner le projet
git clone git@github.com:karl-music/generateu-symfony.git
cd generateu-symfony

# Installation complete (Docker build + BDD + fixtures + Tailwind)
make install
```

L'application est accessible sur :
- **Application** : http://localhost:8080
- **Mailpit** : http://localhost:8025
- **Compte admin** : admin@example.com / password

### Commandes utiles

```bash
make start            # Demarrer les containers
make stop             # Arreter les containers
make db-reset         # Reset complet de la BDD
make tailwind-watch   # Compiler Tailwind en mode watch
make test             # Lancer les tests
make lint             # Linter les fichiers
make help             # Afficher toutes les commandes
```

## Architecture

```
                    ┌─────────────────────┐
                    │   Caddy (reverse     │
                    │   proxy + SSL)       │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼──┐  ┌───────▼────┐  ┌──────▼─────┐
    │ projet-1   │  │ projet-2   │  │ projet-n   │
    │ FrankenPHP │  │ FrankenPHP │  │ FrankenPHP │
    └─────────┬──┘  └───────┬────┘  └──────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────────┐
                    │  PostgreSQL 16      │
                    │  (base par projet)  │
                    └─────────────────────┘
```

- **VPS** : 91.134.132.141 (OVH)
- **Reverse proxy** : Caddy avec certificat wildcard `*.karl-remy.fr`
- **Reseau Docker** : `generateu_network` partage entre tous les projets
- **BDD partagee** : Une instance PostgreSQL, une base par projet

## Authentification

Le boilerplate inclut un systeme d'authentification complet :

| Fonctionnalite         | Route              | Description                              |
|------------------------|--------------------|------------------------------------------|
| Inscription            | `/register`        | Formulaire email + mot de passe          |
| Verification           | `/verify`          | Code a 6 chiffres envoye par email       |
| Connexion              | `/login`           | Login avec verification du statut compte |
| Mot de passe oublie    | `/forgot-password` | Envoi d'un code de reinitialisation      |
| Reset mot de passe     | `/reset-password`  | Saisie du nouveau mot de passe           |

Le rate limiting protege les tentatives de connexion et l'envoi de codes.

## Panel d'administration

Accessible sur `/admin` avec le role `ROLE_ADMIN`.

Fonctionnalites :
- **Dashboard** : Vue d'ensemble du systeme
- **Server monitoring** : CPU, RAM, disque, uptime
- **Introspection BDD** : Tables, colonnes, tailles des bases
- **Gestion utilisateurs** : Liste et administration des comptes

## Deploiement

### Avec Claude Code

La maniere la plus simple de deployer un nouveau projet :

```
/create-project mon-saas
```

Cette commande :
1. Cree un nouveau repo a partir du boilerplate
2. Configure la base de donnees et le sous-domaine
3. Build et demarre les containers sur le VPS
4. Genere les entites et pages si un template YAML est fourni

### Template YAML

Definir la structure du projet dans `infra/project-template.yaml` :

```yaml
project:
  name: mon-saas
  description: "Description du projet"

entities:
  - name: Product
    fields:
      - { name: name, type: string, length: 255 }
      - { name: price, type: decimal, precision: 10, scale: 2 }
      - { name: description, type: text, nullable: true }
      - { name: isActive, type: boolean, default: true }
    timestamps: true
    api: true

  - name: Category
    fields:
      - { name: name, type: string, length: 100 }
      - { name: slug, type: string, length: 100, unique: true }

relations:
  - { from: Product, to: Category, type: ManyToOne }

pages:
  - name: home
    route: /
    template: landing
    description: "Page d'accueil avec hero section"

  - name: products
    route: /products
    template: list
    description: "Liste des produits avec filtres"

features:
  - auth         # Deja inclus dans le boilerplate
  - admin        # Deja inclus dans le boilerplate
  - api          # API Platform endpoints
  - search       # Barre de recherche
  - export_csv   # Export CSV
```

### Scripts manuels

```bash
# Premier deploiement
sudo bash infra/deploy.sh <nom-du-projet>

# Mise a jour
sudo bash infra/redeploy.sh

# Suppression
sudo bash infra/destroy.sh
```

## Structure du projet

```
src/
├── ApiResource/         # Resources API Platform
├── Controller/
│   ├── Admin/           # Panel d'administration
│   ├── HomeController   # Page d'accueil
│   └── SecurityController # Auth (login, register, verify)
├── DataFixtures/        # Fixtures (compte admin)
├── DataTable/           # Configurations DataTables
├── Entity/
│   ├── Trait/           # TimestampableTrait
│   └── User.php
├── Form/                # FormTypes (obligatoires)
├── Repository/          # Requetes Doctrine
├── Security/            # UserChecker
└── Service/
    ├── DatabaseIntrospectionService
    ├── SecurityCodeService
    └── ServerMonitoringService
```

## Conventions

- **FormTypes** : Obligatoires pour chaque formulaire (`src/Form/`)
- **Services** : Logique metier dans `src/Service/`, jamais dans les controllers
- **Repositories** : Requetes complexes dans les Repository
- **Textes** : Tous les textes visibles en **francais** avec accents
- **Trait** : Utiliser `TimestampableTrait` pour `createdAt` / `updatedAt`

## Documentation

- [Configuration DNS OVH](docs/DNS_SETUP.md)
- [Premier deploiement](docs/FIRST_DEPLOY.md)

## Licence

Projet prive - Karl Music
