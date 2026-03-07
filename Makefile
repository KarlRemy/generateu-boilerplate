.DEFAULT_GOAL := help
.PHONY: help start stop build install db-create db-migrate db-fixtures db-reset sf tailwind-watch test cc

DC = docker compose
EXEC = $(DC) exec php
CONSOLE = $(EXEC) php bin/console

## —— Generateu Makefile ——————————————————————————

help: ## Affiche cette aide
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-20s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m## /[33m/'

## —— Docker ——————————————————————————————————————

start: ## Demarre les containers
	$(DC) up -d

stop: ## Arrete les containers
	$(DC) down

build: ## Build les containers
	$(DC) build

logs: ## Affiche les logs
	$(DC) logs -f php

## —— Symfony ————————————————————————————————————

install: build start vendor db-reset tailwind-build ## Installation complete du projet
	@echo "\n✅ Projet installe ! → http://localhost:8081"
	@echo "📧 Mailpit → http://localhost:8026"
	@echo "👤 Admin: admin@example.com / password"

start-dev: build start vendor db-reset ## Lance tout l'environnement de dev en une commande
	$(CONSOLE) tailwind:build
	@echo "\n✅ Environnement de dev pret !"
	@echo "🌐 App → http://localhost:8081"
	@echo "📧 Mailpit → http://localhost:8026"
	@echo "👤 Admin: admin@example.com / password"
	@echo "💡 Lance 'make tailwind-watch' dans un autre terminal pour le hot-reload CSS"

vendor: ## Installe les dependances PHP
	$(EXEC) composer install

sf: ## Execute une commande Symfony (ex: make sf c=debug:router)
	$(CONSOLE) $(c)

cc: ## Vide le cache
	$(CONSOLE) cache:clear

## —— Base de donnees ————————————————————————————

db-create: ## Cree la base de donnees
	$(CONSOLE) doctrine:database:create --if-not-exists

db-migrate: ## Execute les migrations
	$(CONSOLE) doctrine:migrations:migrate --no-interaction

db-diff: ## Genere une migration
	$(CONSOLE) doctrine:migrations:diff

db-fixtures: ## Charge les fixtures
	$(CONSOLE) doctrine:fixtures:load --no-interaction

db-reset: db-create ## Reset complet de la BDD
	$(DC) exec database psql -U app -d app -c "DROP EXTENSION IF EXISTS postgis_topology CASCADE; DROP EXTENSION IF EXISTS postgis CASCADE;"
	$(CONSOLE) doctrine:schema:drop --force --full-database
	$(DC) exec database psql -U app -d app -c "CREATE EXTENSION IF NOT EXISTS postgis; CREATE EXTENSION IF NOT EXISTS postgis_topology;"
	$(CONSOLE) doctrine:migrations:migrate --no-interaction --allow-no-migration
	$(CONSOLE) doctrine:fixtures:load --no-interaction

## —— Assets ————————————————————————————————————

tailwind-build: ## Compile Tailwind CSS
	$(CONSOLE) tailwind:build

tailwind-watch: ## Compile Tailwind CSS en mode watch
	$(CONSOLE) tailwind:build --watch

## —— Tests ————————————————————————————————————

test: ## Lance les tests
	$(EXEC) php bin/phpunit

## —— Qualite ——————————————————————————————————

lint: ## Lint les fichiers Twig et YAML
	$(CONSOLE) lint:twig templates/
	$(CONSOLE) lint:yaml config/
	$(CONSOLE) lint:container
