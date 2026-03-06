# Generateu - Guide Claude Code

## Vue d'ensemble

Generateu est un boilerplate Symfony concu pour le deploiement rapide de projets SaaS sous le domaine **karl-remy.fr**. Chaque nouveau projet est deploye en tant que sous-domaine (ex: `mon-saas.karl-remy.fr`) sur un VPS partage.

## Stack technique

| Composant        | Version / Detail                          |
|------------------|-------------------------------------------|
| PHP              | 8.4                                       |
| Symfony          | 7.2                                       |
| Serveur          | FrankenPHP (worker mode)                  |
| Base de donnees  | PostgreSQL 16 + PostGIS                   |
| CSS              | Tailwind CSS 4 (via symfonycasts/tailwind)|
| API              | API Platform 4                            |
| Temps reel       | Mercure                                   |
| Mailer           | Symfony Mailer (Mailpit en dev)           |
| Assets           | Asset Mapper + Stimulus + Turbo           |
| Icons            | UX Icons                                  |
| DataTables       | pentiminax/ux-datatables                  |

## Architecture

### Docker

- **Dev** : `compose.yaml` + `compose.override.yaml` (PostgreSQL, Mercure, Mailpit)
- **Prod** : `docker-compose.prod.yml` (FrankenPHP worker mode, reseau `generateu_network`)
- **Build multi-stage** : `docker/frankenphp/Dockerfile` avec target `prod`

### Infrastructure VPS

- **VPS** : `91.134.132.141` (OVH)
- **Acces SSH** : `ssh ubuntu@91.134.132.141`
- **Reverse proxy** : Caddy sur le VPS, routing par sous-domaine
- **BDD partagee** : PostgreSQL unique sur le VPS, une base par projet
- **Reseau Docker** : `generateu_network` (partage entre tous les projets)

### Caddyfile

- `Caddyfile` : Configuration dev locale
- `Caddyfile.prod` : Configuration production avec reverse proxy

## Structure du projet

```
generateu-symfony/
├── assets/                  # JS/CSS (Stimulus controllers, Tailwind)
├── bin/                     # Console Symfony
├── config/
│   └── packages/            # Configuration des bundles
│       ├── api_platform.yaml
│       ├── doctrine.yaml
│       ├── mercure.yaml
│       ├── rate_limiter.yaml
│       ├── security.yaml
│       └── ...
├── docker/
│   └── frankenphp/          # Dockerfile multi-stage
├── docs/                    # Documentation (DNS, deploiement)
├── infra/
│   ├── caddy/               # Config Caddy prod
│   ├── lib/
│   │   ├── colors.sh        # Couleurs pour les scripts
│   │   └── secrets.sh       # Gestion des secrets
│   └── nginx/               # Config Nginx (legacy)
├── migrations/              # Migrations Doctrine
├── public/                  # Point d'entree web
├── src/
│   ├── ApiResource/         # Resources API Platform
│   ├── Controller/
│   │   ├── Admin/           # AdminDashboardController
│   │   ├── HomeController.php
│   │   └── SecurityController.php
│   ├── DataFixtures/        # Fixtures (admin@example.com)
│   ├── DataTable/           # Configurations DataTables
│   ├── Entity/
│   │   ├── Trait/
│   │   │   └── TimestampableTrait.php
│   │   └── User.php
│   ├── Form/
│   │   ├── ForgotPasswordFormType.php
│   │   ├── RegistrationFormType.php
│   │   ├── ResetPasswordFormType.php
│   │   └── VerifyCodeFormType.php
│   ├── Repository/
│   │   └── UserRepository.php
│   ├── Security/
│   │   └── UserChecker.php
│   └── Service/
│       ├── DatabaseIntrospectionService.php
│       ├── SecurityCodeService.php
│       └── ServerMonitoringService.php
├── templates/
│   ├── admin/               # Templates panel admin
│   ├── base.html.twig       # Layout principal
│   ├── emails/              # Templates emails
│   ├── form/                # Themes de formulaires
│   ├── home/                # Page d'accueil
│   ├── partials/            # Composants reutilisables
│   └── security/            # Login, register, verification
├── translations/            # Fichiers de traduction
├── compose.yaml             # Docker Compose dev
├── compose.override.yaml    # Overrides dev (ports, mailpit)
├── docker-compose.prod.yml  # Docker Compose production
├── Makefile                 # Commandes make
└── importmap.php            # Asset Mapper importmap
```

## Commandes Make

```bash
make install          # Installation complete (build + start + vendor + db-reset + tailwind)
make start            # Demarre les containers Docker
make stop             # Arrete les containers
make build            # Build les containers
make logs             # Affiche les logs de l'app
make vendor           # Installe les dependances Composer
make sf c=<commande>  # Execute une commande Symfony
make cc               # Vide le cache
make db-create        # Cree la base de donnees
make db-migrate       # Execute les migrations
make db-diff          # Genere une migration
make db-fixtures      # Charge les fixtures
make db-reset         # Reset complet de la BDD (drop + migrate + fixtures)
make tailwind-build   # Compile Tailwind CSS
make tailwind-watch   # Compile Tailwind en mode watch
make test             # Lance les tests PHPUnit
make lint             # Lint Twig, YAML et container
```

## Systeme d'authentification

Le boilerplate inclut un systeme d'auth complet :

1. **Inscription** (`/register`) : Formulaire avec email + mot de passe
2. **Verification par code** (`/verify`) : Code a 6 chiffres envoye par email via `SecurityCodeService`
3. **Connexion** (`/login`) : Login classique avec `UserChecker` (verifie le statut du compte)
4. **Mot de passe oublie** (`/forgot-password`) : Envoi d'un code de reinitialisation
5. **Reset mot de passe** (`/reset-password`) : Saisie du nouveau mot de passe

### Rate Limiting

Le rate limiting est configure dans `config/packages/rate_limiter.yaml` pour proteger :
- Les tentatives de connexion
- L'envoi de codes de verification
- Les demandes de reinitialisation

## Panel Admin

Accessible sur `/admin` (requiert `ROLE_ADMIN`).

Fonctionnalites :
- **Dashboard** : Vue d'ensemble du systeme
- **Server monitoring** : CPU, RAM, disque, uptime (`ServerMonitoringService`)
- **Introspection BDD** : Tables, colonnes, tailles (`DatabaseIntrospectionService`)
- **Gestion utilisateurs** : Liste et administration

Compte admin par defaut (fixtures) : `admin@example.com` / `password`

## Deploiement

### Scripts d'infrastructure

```
infra/
├── deploy.sh          # Premier deploiement d'un nouveau projet
├── redeploy.sh        # Mise a jour d'un projet existant
├── destroy.sh         # Suppression d'un projet
├── caddy/             # Configuration Caddy production
└── lib/
    ├── colors.sh      # Couleurs terminal
    └── secrets.sh     # Gestion des secrets
```

### Skill /create-project

Utiliser la commande `/create-project <nom>` pour creer et deployer un nouveau projet.
Voir `.claude/skills/create-project/SKILL.md` pour les details.

Un fichier template YAML peut etre fourni dans `infra/project-template.yaml` pour definir
les entites, pages et fonctionnalites du projet.

## Patterns et conventions

### FormTypes obligatoires

Chaque formulaire doit avoir son `FormType` dans `src/Form/`. Ne jamais creer de formulaire inline dans un controller.

```php
// src/Form/ProductFormType.php
class ProductFormType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('name', TextType::class, ['label' => 'Nom'])
            ->add('price', MoneyType::class, ['label' => 'Prix']);
    }
}
```

### Services dans src/Service/

La logique metier va dans des services dedies, jamais dans les controllers.

```php
// src/Service/MonService.php
class MonService
{
    public function __construct(
        private EntityManagerInterface $em,
    ) {}
}
```

### Repositories pour les queries

Les requetes complexes vont dans les Repository, pas dans les controllers ou services.

```php
// src/Repository/ProductRepository.php
public function findActiveByCategory(Category $category): array
{
    return $this->createQueryBuilder('p')
        ->andWhere('p.category = :cat')
        ->andWhere('p.isActive = true')
        ->setParameter('cat', $category)
        ->getQuery()
        ->getResult();
}
```

### Nommage

- **Controllers** : `NomController.php` dans `src/Controller/`
- **Entities** : PascalCase, singulier (`Product.php`)
- **FormTypes** : `NomFormType.php` dans `src/Form/`
- **Templates** : `templates/nom_controller/action.html.twig`
- **Services** : `NomService.php` dans `src/Service/`

### Trait TimestampableTrait

Utiliser `TimestampableTrait` dans les entites pour ajouter automatiquement `createdAt` et `updatedAt`.

```php
use App\Entity\Trait\TimestampableTrait;

#[ORM\Entity]
class Product
{
    use TimestampableTrait;
}
```

## Regles pour les textes

- **Langue** : Tous les textes visibles dans les templates sont en **francais**
- **Accents** : Utiliser les accents dans les labels, messages flash, titres, etc.
- **Labels de formulaires** : En francais (`'label' => 'Adresse email'`)
- **Messages flash** : En francais (`$this->addFlash('success', 'Produit cree avec succes')`)
- **Traductions** : Utiliser le systeme de traduction Symfony si besoin (`translations/`)

## URLs utiles en dev

- **Application** : http://localhost:8080
- **Mailpit** : http://localhost:8025
- **Mercure Hub** : Configurable dans `.env`

## Configuration cles

- `config/packages/security.yaml` : Firewall, access control, providers
- `config/packages/doctrine.yaml` : Configuration PostgreSQL + PostGIS
- `config/packages/api_platform.yaml` : Configuration API Platform
- `config/packages/mercure.yaml` : Configuration Mercure
- `config/packages/rate_limiter.yaml` : Limites de taux
