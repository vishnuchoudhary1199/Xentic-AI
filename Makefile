# Convenience wrappers. Every target is a thin alias for a documented command.
.DEFAULT_GOAL := help
ENV ?= dev

.PHONY: help up down reset psql migrate backup restore restore-new-server explain bulk-load \
        tf-fmt tf-plan tf-plan-offline tf-plan-all lint

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

up: ## Start PostgreSQL (first start runs migrations + seed)
	docker compose up -d --wait

down: ## Stop containers (keeps data)
	docker compose --profile restore down

reset: ## Stop containers and delete all local data
	docker compose --profile restore down -v

psql: ## Open psql on the local database
	docker compose exec db psql -U bookings -d bookings

migrate: ## Apply pending migrations
	./scripts/migrate.sh

backup: ## Timestamped, verified dump into ./backups
	./scripts/backup.sh

restore: ## Restore newest dump into a fresh database and verify it
	./scripts/restore.sh

restore-new-server: ## Restore newest dump into a separate empty server and verify it
	./scripts/restore.sh --new-server

explain: ## EXPLAIN ANALYZE the Delhi report query, with and without the index
	./scripts/explain.sh --compare

bulk-load: ## Add 1M synthetic bookings for a realistic EXPLAIN (~1 min)
	./scripts/bulk-load.sh 1000000

tf-fmt: ## terraform fmt the whole infra tree
	terraform -chdir=infra fmt -recursive

tf-plan: ## fmt/init/validate/plan ENV=dev|prod against real AWS + S3 backend
	./scripts/tf-plan.sh $(ENV)

tf-plan-offline: ## Same, without an AWS account (ENV=dev|prod)
	./scripts/tf-plan.sh $(ENV) --offline

tf-plan-all: ## Offline plan for dev and prod
	./scripts/tf-plan.sh dev --offline
	./scripts/tf-plan.sh prod --offline

lint: ## shellcheck + terraform fmt check
	shellcheck -x scripts/*.sh db/migrate.sh db/initdb/*.sh
	terraform -chdir=infra fmt -check -recursive
