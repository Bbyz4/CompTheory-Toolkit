# CompTheory-Toolkit

OCaml application for auth, tasks and submissions, with:
- API in Dream
- web frontend
- PostgreSQL
- RabbitMQ-backed submission queue
- worker judging submissions
- `trafficd` for synthetic API traffic

## Local Operation

Deployment-like local usage is the default path. It mirrors the server workflow and generates local operational commands in `.local-deploy/state/.recognitarc`.

```bash
./scripts/local_deploy.sh up
source ./.local-deploy/state/.recognitarc
recognita_compose ps
```

Default local endpoints:
- app via nginx: `http://localhost:8080`
- TLS via nginx: `https://localhost:8443`
- Mailpit: `http://localhost:8025`
- RabbitMQ management: `http://localhost:15672`
- PostgreSQL: `localhost:5432`

Useful operational commands after `source`:

```bash
admincli list-users
admincli recent-submissions --limit 20
recognita-dbro
recognita-dbrw -c "select count(*) from submissions;"
trafficd start
trafficcli status
trafficcli add-users 100
trafficcli add-tasks 20
trafficcli start
trafficcli get-rates
trafficcli set-rate submit 0.8
trafficcli set-rate list_tasks 2.4
trafficcli pause
recognita_compose logs -f app web worker
```

`./scripts/local_deploy.sh` also supports:

```bash
./scripts/local_deploy.sh up
./scripts/local_deploy.sh down
./scripts/local_deploy.sh logs
./scripts/local_deploy.sh ps
./scripts/local_deploy.sh rebuild
./scripts/local_deploy.sh clean
./scripts/local_deploy.sh source-line
```

`clean` stops and removes the local deployment Docker resources for this project,
then deletes repo-local temporary artifacts such as `.local-deploy/`,
`infra/nginx/certs/origin.{crt,key}`, `_build/` and `var/trafficd/`.

## Dev Helper

`./scripts/dev_helper.sh` is only a convenience wrapper for developers while changing code. It is not part of the deployment or operational path.

Examples:

```bash
./scripts/dev_helper.sh build
./scripts/dev_helper.sh test
./scripts/dev_helper.sh runtest
./scripts/dev_helper.sh dune build @all
./scripts/dev_helper.sh dune runtest
./scripts/dev_helper.sh shell
./scripts/dev_helper.sh run-api
./scripts/dev_helper.sh run-web
./scripts/dev_helper.sh run-worker
./scripts/dev_helper.sh run-trafficd
./scripts/dev_helper.sh run-trafficcli
```

## VS Code Devcontainer

The repo includes a VS Code devcontainer intended to run `local_deploy`
from inside the container, not to boot a parallel dev stack on its own.

Open the folder in VS Code and choose `Reopen in Container`, then use:

```bash
./scripts/local_deploy.sh up
source ./.local-deploy/state/.recognitarc
recognita_compose ps
./scripts/dev_helper.sh test
```

The devcontainer mounts `/var/run/docker.sock`, so Docker commands executed
inside VS Code control the host Docker daemon and can build or start the
deployment-like local stack from `scripts/local_deploy.sh`.

When `.local-deploy/state/.env.deploy.runtime` exists, `./bin/dev` and
`./scripts/dev_helper.sh` automatically remap database, SMTP and RabbitMQ
access from the devcontainer to the host-published local deploy ports.

## API Shape

Most important flows:
- `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`
- `GET /api/v1/me`, `DELETE /api/v1/me`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks?scope=all` for admin task listing including drafts/private tasks
- `GET /api/v1/tasks/slug/:slug`
- `POST /api/v1/tasks` for admin task creation
- `PUT /api/v1/tasks/:id` for admin task editing
- `GET /api/v1/task-types/MODEL_CONSTRUCTION/config-template`
- `POST /api/v1/tasks/:id/submissions`
- `GET /api/v1/submissions`, `GET /api/v1/submissions/:id`

Submission flow:
- API stores submission as `PENDING`
- API publishes submission id to RabbitMQ
- worker consumes pending submissions and writes a mock verdict

## Traffic

`trafficd` is the only synthetic-traffic daemon:
- starts paused
- keeps state in memory
- creates and removes users through the API
- can create mock tasks through the API with Faker-generated content
- cleans up created users on shutdown through the API
- supports live per-operation rate changes
- expresses all rates in requests per second
- keeps synthetic users logged in; `login` rate means relogin

Task creation uses the bootstrap admin configured through
`RECOGNITA_ADMIN_USERNAME` and `RECOGNITA_ADMIN_PASSWORD`.

Typical flow:

```bash
trafficd start
trafficcli add-users 1000
trafficcli add-tasks 200
trafficcli start
trafficcli get-rates
trafficcli set-rate list_tasks 2.0
trafficcli set-rate view_task 1.2
trafficcli set-rate login 0.4
trafficcli set-rate submit 0.8
trafficcli pause
trafficcli remove-users 200
```

Test identities are generated deterministically with Faker. `trafficd` models arrivals as a Poisson process: the total arrival rate is the sum of per-operation lambdas, and each request type is chosen with probability proportional to its lambda.

## Deploy

GitHub Actions builds and pushes three images:
- app runtime
- nginx
- fail2ban

Server deploy then does only:
- copy compose files and cert-generation script
- generate/update runtime env
- generate/update `.recognitarc`
- `docker compose pull`
- `docker compose up -d`

On the server, after deploy, shell commands come from `.recognitarc`:
- `recognita_compose`
- `admincli`
- `recognita-dbro`
- `recognita-dbrw`
- `trafficd`
- `trafficcli`

Minimal manual deploy shape:

```bash
cp .env.deploy.example .env
./scripts/generate_deploy_cert.sh
docker compose -f docker-compose.yml -f docker-compose.deploy.yml up --build -d
```

Important GitHub secrets:
- `SERVER_ADDRESS`
- `SERVER_USERNAME`
- `SERVER_PRIVATE_KEY`

Common optional secrets/vars:
- `POSTGRES_PASSWORD`
- `GHCR_USERNAME`, `GHCR_TOKEN`
- `SERVER_DEPLOY_DIR`
- `SERVER_PROJECT_NAME`
- `NGINX_SERVER_NAME`
- `APP_BASE_URL`
- `PUBLIC_WEB_BASE_URL`
- `MAIL_FROM`
- `TZ`
- `WEB_PUBLIC_PORT`
- `WEB_TLS_PUBLIC_PORT`
- `NGINX_ENABLE_TLS`
- `POSTGRES_DB`
- `POSTGRES_USER`
