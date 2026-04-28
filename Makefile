SHELL := /bin/sh

.DEFAULT_GOAL := help

.PHONY: help bootstrap up down logs ps rebuild build test shell run-api run-web

DOCKER_CHECK := ./scripts/ensure_docker.sh

help:
	@printf '%s\n' \
		'make bootstrap  - build images and start the Docker stack in background' \
		'make up         - build images and start the Docker stack in background' \
		'make down       - stop the Docker stack' \
		'make logs       - stream compose logs' \
		'make ps         - show compose services' \
		'make rebuild    - rebuild Docker images without cache' \
		'make build      - build all OCaml targets in the dev environment' \
		'make test       - run the test suite in the dev environment' \
		'make shell      - open a shell in the dev environment' \
		'make run-api    - run the API from source in the dev environment' \
		'make run-web    - run the web app from source in the dev environment' \
		'./bin/admincli  - run admin CLI without typing docker compose exec'

bootstrap: up

up:
	$(DOCKER_CHECK)
	docker compose up --build -d

down:
	$(DOCKER_CHECK)
	docker compose down --remove-orphans

logs:
	$(DOCKER_CHECK)
	docker compose logs -f --tail=100

ps:
	$(DOCKER_CHECK)
	docker compose ps

rebuild:
	$(DOCKER_CHECK)
	docker compose build --no-cache

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
