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
Do deployu używa `SERVER_ADDRESS`, `SERVER_USERNAME`, `SERVER_PRIVATE_KEY` i `SECRET_CODE`.
Jeśli repo na serwerze leży gdzie indziej, ustaw `SERVER_APP_DIR` jako GitHub Variable.
