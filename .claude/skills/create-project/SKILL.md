---
name: create-project
description: Create and deploy a new project from the generateu boilerplate
user_invocable: true
---

# /create-project

Cree et deploie un nouveau projet a partir du boilerplate generateu-symfony.

## Utilisation

```
/create-project <nom-du-projet> <description du projet>
```

Exemples :
```
/create-project app-factures Application de gestion de factures pour freelances avec clients, factures, devis et paiements
/create-project gestion-stock Gestion d'inventaire pour un entrepot avec produits, categories, mouvements de stock et alertes
/create-project mon-blog Blog personnel avec articles, categories, tags et commentaires moderes
/create-project booking-salle Reservation de salles de reunion avec calendrier, creneaux et notifications
```

Le nom du projet doit etre en **kebab-case** (ex: `mon-saas`, `app-comptable`).
La description est optionnelle mais recommandee — elle permet de generer automatiquement les entites, pages et features adaptees.

## Etapes

### 1. Parser les arguments

- Le premier mot est le nom du projet (kebab-case)
- Tout le reste est la description / le prompt initial
- S'il n'y a pas de nom, demander a l'utilisateur
- Le sous-domaine sera `<nom>.karl-remy.fr`

### 2. Concevoir l'architecture du projet a partir de la description

A partir de la description fournie, concevoir l'architecture complete du projet :

#### a. Analyser la description et en deduire :
- Les **entites** necessaires (avec leurs champs, types, relations)
- Les **pages** a creer (accueil, listes, details, formulaires)
- Les **features** a activer (API, recherche, export, etc.)

#### b. Generer le fichier `infra/project-template.yaml`

Ecrire le template YAML base sur l'analyse. Format :

```yaml
project:
  name: nom-du-projet
  description: "Description du projet"

entities:
  - name: EntityName
    fields:
      - { name: fieldName, type: string, length: 255 }
      - { name: price, type: decimal, precision: 10, scale: 2 }
      - { name: description, type: text, nullable: true }
      - { name: isActive, type: boolean, default: true }
      - { name: date, type: datetime }
    timestamps: true    # Ajouter TimestampableTrait
    api: true           # Exposer via API Platform

relations:
  - { from: Entity1, to: Entity2, type: ManyToOne }
  - { from: Entity1, to: Entity3, type: ManyToMany }

pages:
  - name: home
    route: /
    template: landing
    description: "Page d'accueil"

  - name: entity_list
    route: /entities
    template: list
    description: "Liste des entites"

  - name: entity_show
    route: /entity/{slug}
    template: detail
    description: "Detail d'une entite"

features:
  - auth          # Deja inclus dans le boilerplate
  - admin         # Deja inclus dans le boilerplate
  - api           # Endpoints API Platform
  - search        # Barre de recherche sur les listes
  - export_csv    # Export CSV
```

Types de champs : `string`, `text`, `integer`, `decimal`, `boolean`, `datetime`, `date`, `float`, `json`, `array`
Types de relations : `ManyToOne`, `OneToMany`, `ManyToMany`, `OneToOne`
Types de templates : `landing`, `list`, `detail`, `form`, `dashboard`

#### c. Confirmer avec l'utilisateur

Afficher un resume de l'architecture proposee et demander confirmation avant de continuer :

```
Projet : app-factures
URL : https://app-factures.karl-remy.fr

Entites :
  - Client (5 champs) : nom, email, telephone, adresse, siret
  - Facture (6 champs) : numero, date, montant_ht, tva, statut, date_echeance
  - LigneFacture (4 champs) : description, quantite, prix_unitaire, montant
  - Devis (5 champs) : numero, date, montant_ht, statut, validite

Relations :
  - Facture → Client (ManyToOne)
  - LigneFacture → Facture (ManyToOne)
  - Devis → Client (ManyToOne)

Pages :
  - / (landing) : Page d'accueil
  - /clients (list) : Liste des clients
  - /factures (list) : Liste des factures
  - /facture/{id} (detail) : Detail facture

Features : auth, admin, api, export_csv

Continuer ? (oui/non)
```

### 3. Premier deploiement via SSH

```bash
# 1. Synchroniser les scripts infra sur le VPS
scp -r infra/ ubuntu@91.134.132.141:/tmp/generateu-infra/

# 2. Deployer le boilerplate vierge
ssh ubuntu@91.134.132.141 "sudo bash /tmp/generateu-infra/infra/deploy.sh <nom-du-projet>"
```

### 4. Generer le code du projet

#### a. Cloner le nouveau repo localement

```bash
git clone git@github.com:karl-remy/<nom-du-projet>.git /private/tmp/generateu-tmp/<nom-du-projet>
cd /private/tmp/generateu-tmp/<nom-du-projet>
```

#### b. Generer les entites

Pour chaque entite du YAML, creer le fichier PHP dans `src/Entity/` :

```php
#[ORM\Entity(repositoryClass: ProductRepository::class)]
class Product
{
    use TimestampableTrait;

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    private ?string $name = null;

    // getters/setters
}
```

- Ajouter `TimestampableTrait` si `timestamps: true`
- Ajouter `#[ApiResource]` si `api: true`
- Creer le `Repository` correspondant

#### c. Generer les relations

```php
// ManyToOne
#[ORM\ManyToOne(targetEntity: Category::class, inversedBy: 'products')]
private ?Category $category = null;

// OneToMany (cote inverse)
#[ORM\OneToMany(targetEntity: Product::class, mappedBy: 'category')]
private Collection $products;
```

#### d. Generer les controllers et templates

Pour chaque page du YAML :
- Controller dans `src/Controller/`
- Template Twig dans `templates/`
- Route selon le YAML
- Tous les textes en **francais** avec accents

#### e. Generer les FormTypes

Pour chaque entite qui a des pages de creation/edition :
- FormType dans `src/Form/`
- Labels en francais

#### f. Generer la migration

```bash
# En local avec docker compose (le boilerplate a un compose dev)
docker compose exec php php bin/console doctrine:migrations:diff
```

#### g. Pousser les modifications

```bash
git add -A
git commit -m "feat: generate project structure from template"
git push origin main
```

### 5. Redeployer avec le nouveau code

```bash
ssh ubuntu@91.134.132.141 "sudo bash /tmp/generateu-infra/infra/redeploy.sh <nom-du-projet>"
```

### 6. Afficher le resultat

```
Projet deploye avec succes !

URL : https://<nom-du-projet>.karl-remy.fr
Admin : https://<nom-du-projet>.karl-remy.fr/admin
Compte admin : admin@example.com / password

Entites generees :
- Client (5 champs)
- Facture (6 champs)
- LigneFacture (4 champs)

Pages generees :
- / (Page d'accueil)
- /clients (Liste des clients)
- /factures (Liste des factures)

Features activees :
- auth (inclus dans le boilerplate)
- admin (inclus dans le boilerplate)
- api (API Platform endpoints)
- export_csv
```

## Notes

- Le script `deploy.sh` cree automatiquement la base PostgreSQL et le sous-domaine
- Le script `redeploy.sh` pull les modifications, rebuild et relance les containers
- Le script `destroy.sh` supprime completement un projet (containers, BDD, config reverse proxy)
- Tous les textes generes dans les templates doivent etre en **francais**
- Les accents sont obligatoires dans les labels et messages
- Suivre les conventions du CLAUDE.md (FormTypes, Services, Repositories, nommage)
