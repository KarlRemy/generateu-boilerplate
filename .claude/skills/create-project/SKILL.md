---
name: create-project
description: Create and deploy a new project from the generateu boilerplate
user_invocable: true
---

# /create-project

Cree et deploie un nouveau projet a partir du boilerplate generateu-symfony.

## Utilisation

```
/create-project <nom-du-projet>
```

Le nom du projet doit etre en **kebab-case** (ex: `mon-saas`, `app-comptable`, `gestion-stock`).

## Etapes

### 1. Parser le nom du projet

- Le nom est le premier argument passe a la commande
- S'il n'est pas fourni, demander a l'utilisateur
- Valider que le nom est en kebab-case (lettres minuscules, chiffres, tirets)
- Le sous-domaine sera `<nom>.karl-remy.fr`

### 2. Verifier le template (optionnel)

Verifier si le fichier `infra/project-template.yaml` existe dans le projet courant.
Si oui, le lire et parser pour recuperer la definition des entites, pages et features.

Le format du template est documente dans `infra/project-template.yaml`.

### 3. Premier deploiement via SSH

Se connecter au VPS et executer le script de deploiement :

```bash
# Connexion au VPS
ssh ubuntu@91.134.132.141

# Executer le script de deploiement
# Le script va :
# - Cloner le repo du boilerplate
# - Creer la base de donnees PostgreSQL
# - Configurer les variables d'environnement
# - Build et demarrer les containers Docker
# - Configurer le sous-domaine dans Caddy
sudo bash /home/ubuntu/generateu-symfony/infra/deploy.sh <nom-du-projet>
```

### 4. Generer le code a partir du template (si fourni)

Si un fichier `infra/project-template.yaml` est fourni avec des entites/pages/features :

#### a. Cloner le nouveau repo localement

```bash
# Cloner dans un repertoire temporaire
git clone git@github.com:karl-music/<nom-du-projet>.git /private/tmp/generateu-tmp/<nom-du-projet>
cd /private/tmp/generateu-tmp/<nom-du-projet>
```

#### b. Generer les entites

Pour chaque entite definie dans le YAML :

```bash
# Generer l'entite avec le MakerBundle
docker compose exec app php bin/console make:entity <EntityName>
```

Ou directement creer les fichiers PHP dans `src/Entity/` avec les attributs Doctrine :

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

    // ... autres champs selon le YAML
}
```

- Ajouter `TimestampableTrait` si `timestamps: true`
- Ajouter les attributs `#[ApiResource]` si `api: true`
- Creer le `Repository` correspondant

#### c. Generer les relations

Pour chaque relation dans le YAML :

```php
// ManyToOne : cote "from"
#[ORM\ManyToOne(targetEntity: Category::class, inversedBy: 'products')]
private ?Category $category = null;

// OneToMany : cote "to"
#[ORM\OneToMany(targetEntity: Product::class, mappedBy: 'category')]
private Collection $products;
```

#### d. Generer les controllers et templates

Pour chaque page dans le YAML :

- Creer le controller dans `src/Controller/`
- Creer le template Twig dans `templates/`
- Configurer la route selon le YAML
- Utiliser le type de template indique (`landing`, `list`, `detail`)

#### e. Generer les FormTypes

Pour chaque entite qui a des pages de creation/edition, creer le FormType correspondant dans `src/Form/`.

#### f. Generer les migrations

```bash
docker compose exec app php bin/console doctrine:migrations:diff
```

#### g. Pousser les modifications

```bash
git add -A
git commit -m "feat: generate project structure from template"
git push origin main
```

### 5. Redeployer avec le nouveau code

```bash
ssh ubuntu@91.134.132.141
sudo bash /home/ubuntu/<nom-du-projet>/infra/redeploy.sh
```

### 6. Afficher le resultat

```
Projet deploye avec succes !

URL : https://<nom-du-projet>.karl-remy.fr
Admin : https://<nom-du-projet>.karl-remy.fr/admin
Compte admin : admin@example.com / password

Entites generees :
- Product (5 champs)
- Category (2 champs)

Pages generees :
- / (Page d'accueil)
- /products (Liste des produits)
- /product/{slug} (Detail produit)

Features activees :
- auth (inclus dans le boilerplate)
- admin (inclus dans le boilerplate)
- api (API Platform endpoints)
- search
- export_csv
```

## Format du template YAML

Voir le fichier `infra/project-template.yaml` pour le format complet. Structure :

```yaml
project:
  name: nom-du-projet
  description: "Description"

entities:
  - name: EntityName
    fields:
      - { name: fieldName, type: string, length: 255 }
    timestamps: true    # Ajouter TimestampableTrait
    api: true           # Exposer via API Platform

relations:
  - { from: Entity1, to: Entity2, type: ManyToOne }

pages:
  - name: page_name
    route: /route
    template: landing|list|detail
    description: "Description de la page"

features:
  - auth          # Deja inclus
  - admin         # Deja inclus
  - api           # Endpoints API Platform
  - search        # Barre de recherche
  - export_csv    # Export CSV
```

## Notes

- Le script `deploy.sh` cree automatiquement la base PostgreSQL et le sous-domaine Caddy
- Le script `redeploy.sh` pull les modifications, rebuild et relance les containers
- Le script `destroy.sh` supprime completement un projet (containers, BDD, config Caddy)
- Tous les textes generes dans les templates doivent etre en **francais**
- Les accents sont obligatoires dans les labels et messages
