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
- opcjonalnie `POSTGRES_PASSWORD`
- opcjonalnie `ACCESS_GATE_COOKIE_SECRET`
- opcjonalnie `GHCR_USERNAME` i `GHCR_TOKEN` jeśli pakiet w GHCR ma zostać prywatny

Opcjonalnie ustaw GitHub Variable `SERVER_DEPLOY_DIR`.
Domyślnie workflow używa katalogu `~/comp-theory-toolkit-deploy`.
Opcjonalnie ustaw też `SERVER_PROJECT_NAME`, jeśli chcesz własną nazwę projektu compose.

Opcjonalnie możesz też ustawić GitHub Variables:

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

Workflow sam:

- tworzy katalog deployowy na serwerze
- używa świeżego katalogu release dla każdej wersji
- trzyma stan i certy osobno, poza katalogiem release
- wysyła aktualne pliki compose i `infra/`
- generuje i utrzymuje plik env na podstawie `.env.deploy.example`
- zachowuje trwałe sekrety między deployami, jeśli nie podasz ich jawnie w GitHub Secrets
- generuje self-signed cert, jeśli nie ma jeszcze certów originu

Jeśli używasz prywatnego pakietu GHCR i nie podasz `GHCR_USERNAME` i `GHCR_TOKEN` w GitHub Secrets, to zrób na serwerze jednorazowo:

```bash
echo TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```
