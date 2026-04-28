### co jest

- proste openapi
- obsługa mailów do rejestracji (na razie nie wysyłamy do sieci, tylko przechwycamy za pomocą mailpit)
- refresh tokeny rate limiting i rozsądne zabezpieczenie (brakuje cloudflare)
- admincli do zarządzania zdeployowanym serwerem
- teściory
- CI/CD prawie jak tylko tłoki z aruby mi ticket rozpatrzą

### layout

- `apps/api` - server entrypoint
- `apps/admincli` - admincli
- `apps/web` - demo web apka
- `src/shared` - wiadomo
- `src/server` - backend auth & mailer
- `src/web` - web i proxy kody
- `test` - auth & API tests

### Quick start

```bash
make bootstrap
```

Server:

- api base: `http://127.0.0.1:8080`
- health: `http://127.0.0.1:8080/health`
- openapi: `http://127.0.0.1:8080/openapi.json`
- web apka: `http://127.0.0.1:8081`
- mailpit: `http://127.0.0.1:8025`
- SMTP capture: `127.0.0.1:1025`

default admin w `docker-compose.yml` / `.env.example`:
trzeba obowiązkowo potem poprawić i zrobić bezpieczniej admina etc z admincli

- username: `admin`
- email: `admin@recognita.xyz`
- password: `adminpass123`

### codzienne komendy

```bash
make up
make down
make logs
make build
make test
make shell
make run-api
make run-web
./bin/admincli list-users
./bin/admincli ban-user 2 --reason spam
```

`make build`, `make test`, `make shell`, `make run-api` i `make run-web`
dzialaja tak samo:

- na hoście z Dockera
- wewnatrz VS Code Dev Containera

### Docker + Dev Container

Najprostsza sciezka developerska:

1. zainstaluj tylko Docker i VS Code
2. opcjonalnie skopiuj `.env.example` do `.env`, jesli chcesz zmienic porty albo sekrety
3. odpal `make bootstrap`
4. jesli pracujesz w VS Code: `Dev Containers: Reopen in Container`

Dev Container korzysta z `docker-compose.dev.yml`, ma gotowy toolchain OCaml
i automatycznie startuje `db` oraz `mailpit`.

### troubleshooting docker

Jesli dostaniesz blad podobny do:

```text
failed to connect to the docker API ... docker.sock ... no such file or directory
```

to znaczy, ze Docker CLI jest zainstalowany, ale sam daemon / runtime nie dziala.

macOS:

```bash
open -a Docker
# albo
open -a OrbStack
# albo
colima start
docker info
```

Linux:

```bash
sudo systemctl start docker
docker info
```

Od teraz `make up`, `make down`, `make logs`, `./bin/dev` i `./bin/admincli`
sprawdzaja to wczesniej i zwracaja krotszy, czytelniejszy komunikat.

### lokalny build bez kontenerow

To jest opcjonalne. Glowna sciezka dev to Docker / Dev Container, ale lokalny build
tez jest wspierany na macOS i Linux.

macOS:

```bash
brew install opam libpq gmp pkg-config docker
opam init
eval $(opam env)
opam install . --deps-only --with-test -y
```

Debian / Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y opam libpq-dev libgmp-dev libssl-dev libev-dev pkg-config m4
opam init
eval $(opam env)
opam install . --deps-only --with-test -y
```

Potem:

```bash
sh scripts/with_system_libs.sh opam exec -- dune build @all
sh scripts/with_system_libs.sh opam exec -- dune runtest
sh scripts/with_system_libs.sh opam exec -- dune exec apps/api/server.exe
```

### env

- `APP_HOST`
- `APP_PORT`
- `APP_BASE_URL`
- `PUBLIC_WEB_BASE_URL`
- `DATABASE_URL`
- `ADMIN_USERNAME`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `ACCESS_TOKEN_TTL_SECONDS`
- `REFRESH_TOKEN_TTL_SECONDS`
- `VERIFICATION_TOKEN_TTL_SECONDS`
- `SMTP_HOST`
- `SMTP_PORT`
- `MAIL_FROM`
- `RATE_LIMIT_MAX_REQUESTS`
- `AUTH_RATE_LIMIT_MAX_REQUESTS`
- `WEB_HOST`
- `WEB_PORT`
- `API_BASE_URL`
- `SITE_NAME`

### api

- `GET /health`
- `GET /openapi.json`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/verify-email`
- `GET /api/v1/me`
- `GET /api/v1/users`
- `POST /api/v1/users/:id/ban`
- `POST /api/v1/users/:id/unban`
