SHELL := /bin/sh

.DEFAULT_GOAL := help

.PHONY: help bootstrap up down logs ps rebuild build test shell run-api run-web run-worker local-up deploy-up local-down deploy-down local-logs deploy-logs deploy-cert

DOCKER_CHECK := ./scripts/ensure_docker.sh

help:
	@printf '%s\n' \
		'make bootstrap   - build images and start the stack using APP_MODE from .env' \
		'make up          - build images and start the stack using APP_MODE from .env' \
		'make down        - stop the stack selected by APP_MODE from .env' \
		'make logs        - stream logs for the stack selected by APP_MODE from .env' \
		'make ps          - show services for the stack selected by APP_MODE from .env' \
		'make rebuild     - rebuild images for the stack selected by APP_MODE from .env' \
		'make local-up    - force local stack' \
		'make deploy-up   - force deployment stack' \
		'make deploy-cert - generate a self-signed TLS cert for the deployment nginx origin' \
		'make local-down  - stop local stack' \
		'make deploy-down - stop deployment stack' \
		'make local-logs  - stream local stack logs' \
		'make deploy-logs - stream deployment stack logs' \
		'make build      - build all OCaml targets in the dev environment' \
		'make test       - run the test suite in the dev environment' \
		'make shell      - open a shell in the dev environment' \
		'make run-api    - run the API from source in the dev environment' \
		'make run-web    - run the web app from source in the dev environment' \
		'make run-worker - run the submission worker from source in the dev environment' \
		'./bin/admincli  - run admin CLI without typing docker compose exec'

bootstrap: up

up:
	$(DOCKER_CHECK)
	./bin/compose up --build -d

down:
	$(DOCKER_CHECK)
	./bin/compose down --remove-orphans

logs:
	$(DOCKER_CHECK)
	./bin/compose logs -f --tail=100

ps:
	$(DOCKER_CHECK)
	./bin/compose ps

rebuild:
	$(DOCKER_CHECK)
	./bin/compose build --no-cache

local-up:
	$(DOCKER_CHECK)
	APP_MODE=local ./bin/compose up --build -d

deploy-up:
	$(DOCKER_CHECK)
	APP_MODE=deployment ./bin/compose up --build -d

deploy-cert:
	./scripts/generate_deploy_cert.sh

local-down:
	$(DOCKER_CHECK)
	APP_MODE=local ./bin/compose down --remove-orphans

deploy-down:
	$(DOCKER_CHECK)
	APP_MODE=deployment ./bin/compose down --remove-orphans

local-logs:
	$(DOCKER_CHECK)
	APP_MODE=local ./bin/compose logs -f --tail=100

deploy-logs:
	$(DOCKER_CHECK)
	APP_MODE=deployment ./bin/compose logs -f --tail=100

build:
	./bin/dev dune build @all

test:
	./bin/dev dune runtest

shell:
	./bin/dev

run-api:
	./bin/dev --service-ports dune exec apps/api/server.exe

run-web:
	./bin/dev --service-ports dune exec apps/web/webapp.exe

run-worker:
	./bin/dev dune exec apps/worker/worker.exe
