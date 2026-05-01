# CompTheory-Toolkit

## Quick start

```bash
cp .env.example .env
make bootstrap
```

Po starcie:

- API: `http://localhost:8080`
- health: `http://localhost:8080/health`
- OpenAPI: `http://localhost:8080/openapi.json`
- web: `http://localhost:8081`
- Mailpit: `http://localhost:8025`

## Przydatne komendy

```bash
make up
make down
make logs
make test
make shell
make run-api
make run-web
./bin/admincli list-users
./bin/admincli ban-user 2 --reason spam
./bin/admincli promote-admin 2
```

## Deploy

```bash
cp .env.deploy.example .env
make deploy-cert
make deploy-up
```

GitHub Actions działa tylko na branchu `server`.
Buduje obraz w GitHub Actions, wrzuca go do GHCR i na serwerze robi tylko `pull + up -d`.

Do GitHub Secrets ustaw:

- `SERVER_ADDRESS`
- `SERVER_USERNAME`
- `SERVER_PRIVATE_KEY`
- `SECRET_CODE`
- opcjonalnie `GHCR_USERNAME` i `GHCR_TOKEN` jeśli pakiet w GHCR ma zostać prywatny

Opcjonalnie ustaw GitHub Variable `SERVER_APP_DIR`, jeśli repo na serwerze leży poza `~/CompTheory-Toolkit`, `/srv/CompTheory-Toolkit` albo `/opt/CompTheory-Toolkit`.

Jednorazowo na serwerze:

```bash
git clone git@github.com:Bbyz4/CompTheory-Toolkit.git
cd CompTheory-Toolkit
cp .env.deploy.example .env
make deploy-cert
```

Jeśli nie podasz `GHCR_USERNAME` i `GHCR_TOKEN` w GitHub Secrets, to zrób na serwerze jednorazowo:

```bash
echo TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```
