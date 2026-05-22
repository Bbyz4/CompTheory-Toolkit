#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

state_root="$root_dir/.local-deploy"
legacy_state_root="$root_dir/.local_deploy"
state_dir="$state_root/state"
releases_dir="$state_root/releases"
current_link="$state_root/current"
runtime_env="$state_dir/.env.deploy.runtime"
recognita_rc="$state_dir/.recognitarc"
local_override="$state_dir/docker-compose.local-deploy.yml"
repo_certs_dir="$root_dir/infra/nginx/certs"
build_dir="$root_dir/_build"
trafficd_state_dir="$root_dir/var/trafficd"

project_name=${LOCAL_DEPLOY_PROJECT_NAME:-comp-theory-toolkit-local-deploy}
app_image=${LOCAL_DEPLOY_APP_IMAGE:-comp-theory-toolkit-runtime:local-deploy}
nginx_image=${LOCAL_DEPLOY_NGINX_IMAGE:-comp-theory-toolkit-nginx:local-deploy}
fail2ban_image=${LOCAL_DEPLOY_FAIL2BAN_IMAGE:-comp-theory-toolkit-fail2ban:local-deploy}
server_name=${LOCAL_DEPLOY_SERVER_NAME:-localhost}
nginx_enable_tls=${LOCAL_DEPLOY_NGINX_ENABLE_TLS:-off}
web_public_port=${LOCAL_DEPLOY_WEB_PUBLIC_PORT:-8080}
web_tls_public_port=${LOCAL_DEPLOY_WEB_TLS_PUBLIC_PORT:-8443}
mail_from=${LOCAL_DEPLOY_MAIL_FROM:-no-reply@localhost}
postgres_db=${LOCAL_DEPLOY_POSTGRES_DB:-toolkit}
postgres_user=${LOCAL_DEPLOY_POSTGRES_USER:-toolkit}
postgres_password=${LOCAL_DEPLOY_POSTGRES_PASSWORD:-toolkit}
dbro_user=${LOCAL_DEPLOY_DBRO_USER:-recognita_ro}
dbro_password=${LOCAL_DEPLOY_DBRO_PASSWORD:-recognita-ro-local}
dbrw_user=${LOCAL_DEPLOY_DBRW_USER:-recognita_rw}
dbrw_password=${LOCAL_DEPLOY_DBRW_PASSWORD:-recognita-rw-local}
rabbitmq_user=${LOCAL_DEPLOY_RABBITMQ_USER:-recognita}
rabbitmq_password=${LOCAL_DEPLOY_RABBITMQ_PASSWORD:-recognita-rabbit-local}
recognita_admin_username=${LOCAL_DEPLOY_RECOGNITA_ADMIN_USERNAME:-recognita_admin}
recognita_admin_password=${LOCAL_DEPLOY_RECOGNITA_ADMIN_PASSWORD:-RecognitaAdminLocal1!}
access_gate_code=${LOCAL_DEPLOY_ACCESS_GATE_CODE:-pezarski}
access_gate_cookie_secret=${LOCAL_DEPLOY_ACCESS_GATE_COOKIE_SECRET:-recognita-local-gate-cookie-secret-v1}
trafficd_seed=${LOCAL_DEPLOY_TRAFFICD_SEED:-20260508}
trafficd_rate=${LOCAL_DEPLOY_TRAFFICD_RATE:-3.0}
trafficd_report_every=${LOCAL_DEPLOY_TRAFFICD_REPORT_EVERY:-100}
trafficd_admin_client_id=${LOCAL_DEPLOY_TRAFFICD_ADMIN_CLIENT_ID:-trafficd-admin}
tz_value=${LOCAL_DEPLOY_TZ:-Europe/Rome}
include_fail2ban=${LOCAL_DEPLOY_INCLUDE_FAIL2BAN:-0}
site_name=${LOCAL_DEPLOY_SITE_NAME:-Recognita}
mailpit_webroot=${LOCAL_DEPLOY_MAILPIT_WEBROOT:-/mailpit}
app_base_url=${LOCAL_DEPLOY_APP_BASE_URL:-http://localhost:$web_public_port}
public_web_base_url=${LOCAL_DEPLOY_PUBLIC_WEB_BASE_URL:-$app_base_url}
nginx_certs_dir="$state_dir/nginx-certs"

usage() {
  cat <<'EOF'
Usage: ./scripts/local_deploy.sh {prepare|build|rebuild|up|down|logs|ps|source-line|clean}
EOF
}

run_docker() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
    sudo -n docker "$@"
    return
  fi
  printf '%s\n' "Docker daemon is not reachable for the current user." >&2
  exit 1
}

docker_available() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

release_dir() {
  if [ -L "$current_link" ] || [ -d "$current_link" ]; then
    readlink "$current_link" 2>/dev/null || printf '%s\n' "$current_link"
  else
    printf '%s\n' ""
  fi
}

ensure_dirs() {
  mkdir -p "$state_dir" "$releases_dir" "$nginx_certs_dir"
}

generate_local_override() {
  cat > "$local_override" <<EOF
services:
  app:
    pull_policy: never
  web:
    pull_policy: never
  trafficd:
    pull_policy: never
  nginx:
    pull_policy: never
  fail2ban:
    pull_policy: never
EOF
}

prepare_release() {
  ensure_dirs
  next_release=$(mktemp -d "$releases_dir/release.XXXXXX")
  mkdir -p "$next_release/scripts"
  cp "$root_dir/docker-compose.yml" "$next_release/docker-compose.yml"
  cp "$root_dir/docker-compose.deploy.yml" "$next_release/docker-compose.deploy.yml"
  cp "$root_dir/scripts/generate_deploy_cert.sh" "$next_release/scripts/generate_deploy_cert.sh"
  cp "$root_dir/scripts/provision_db_access.sql" "$next_release/scripts/provision_db_access.sql"
  ln -sfn "$next_release" "$current_link"
}

write_runtime_env() {
  cat > "$runtime_env" <<EOF
APP_MODE=deployment
PROJECT_NAME=$project_name
APP_IMAGE=$app_image
NGINX_IMAGE=$nginx_image
FAIL2BAN_IMAGE=$fail2ban_image
POSTGRES_DB=$postgres_db
POSTGRES_USER=$postgres_user
POSTGRES_PASSWORD=$postgres_password
DBRO_USER=$dbro_user
DBRO_PASSWORD=$dbro_password
DBRW_USER=$dbrw_user
DBRW_PASSWORD=$dbrw_password
RABBITMQ_USER=$rabbitmq_user
RABBITMQ_PASSWORD=$rabbitmq_password
APP_HOST=0.0.0.0
APP_PORT=8080
APP_BASE_URL=$app_base_url
PUBLIC_WEB_BASE_URL=$public_web_base_url
WEB_HOST=0.0.0.0
WEB_PORT=8081
WEB_PUBLIC_PORT=$web_public_port
WEB_TLS_PUBLIC_PORT=$web_tls_public_port
API_BASE_URL=http://app:8080
SITE_NAME=$site_name
NGINX_SERVER_NAME=$server_name
NGINX_ENABLE_TLS=$nginx_enable_tls
NGINX_TLS_CERT_FILE=/etc/nginx/certs/origin.crt
NGINX_TLS_KEY_FILE=/etc/nginx/certs/origin.key
NGINX_CERTS_DIR=$nginx_certs_dir
ACCESS_GATE_CODE=$access_gate_code
ACCESS_GATE_COOKIE_SECRET=$access_gate_cookie_secret
DATABASE_URL=postgresql://$postgres_user:$postgres_password@db:5432/$postgres_db
DATABASE_URL_RO=postgresql://$dbro_user:$dbro_password@db:5432/$postgres_db
DATABASE_URL_RW=postgresql://$dbrw_user:$dbrw_password@db:5432/$postgres_db
ACCESS_TOKEN_TTL_SECONDS=900
REFRESH_TOKEN_TTL_SECONDS=604800
VERIFICATION_TOKEN_TTL_SECONDS=86400
RATE_LIMIT_WINDOW_SECONDS=60
RATE_LIMIT_MAX_REQUESTS=120
AUTH_RATE_LIMIT_WINDOW_SECONDS=60
AUTH_RATE_LIMIT_MAX_REQUESTS=20
SMTP_HOST=mailpit
SMTP_PORT=1025
MAILPIT_WEBROOT=$mailpit_webroot
MAIL_FROM=$mail_from
RECOGNITA_ADMIN_USERNAME=$recognita_admin_username
RECOGNITA_ADMIN_PASSWORD=$recognita_admin_password
TZ=$tz_value
TRAFFICD_API_BASE_URL=http://app:8080
TRAFFICD_CONTROL_SOCKET=/tmp/trafficd.sock
TRAFFICD_SEED=$trafficd_seed
TRAFFICD_RATE=$trafficd_rate
TRAFFICD_REPORT_EVERY=$trafficd_report_every
TRAFFICD_ADMIN_CLIENT_ID=$trafficd_admin_client_id
EOF
}

write_recognitarc() {
  cat > "$recognita_rc" <<EOF
# Generated by local deployment-like Recognita setup.
export RECOGNITA_POSTGRES_DB="$postgres_db"
export RECOGNITA_DBRO_USER="$dbro_user"
export RECOGNITA_DBRO_PASSWORD="$dbro_password"
export RECOGNITA_DBRW_USER="$dbrw_user"
export RECOGNITA_DBRW_PASSWORD="$dbrw_password"

recognita_docker() {
  if docker info >/dev/null 2>&1; then
    docker "\$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
    sudo -n docker "\$@"
    return
  fi
  printf '%s\n' 'Docker daemon is not reachable for the current user.' >&2
  return 1
}

recognita_compose() {
  recognita_docker compose -p "$project_name" --env-file "$runtime_env" \
    -f "$current_link/docker-compose.yml" \
    -f "$current_link/docker-compose.deploy.yml" \
    -f "$local_override" "\$@"
}

alias rcompose='recognita_compose'

recognita_psql() {
  role_user="\$1"
  role_password="\$2"
  shift 2
  if [ \$# -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then
    recognita_compose exec db env PGPASSWORD="\$role_password" \
      psql -U "\$role_user" -d "\$RECOGNITA_POSTGRES_DB"
  else
    recognita_compose exec -T db env PGPASSWORD="\$role_password" \
      psql -U "\$role_user" -d "\$RECOGNITA_POSTGRES_DB" "\$@"
  fi
}

admincli() {
  if recognita_compose ps --status running --services 2>/dev/null | grep -qx 'app'; then
    recognita_compose exec -T app /app/admincli "\$@"
  else
    recognita_compose run --rm --no-deps app /app/admincli "\$@"
  fi
}

recognita-dbro() {
  recognita_psql "\$RECOGNITA_DBRO_USER" "\$RECOGNITA_DBRO_PASSWORD" "\$@"
}

recognita-dbrw() {
  recognita_psql "\$RECOGNITA_DBRW_USER" "\$RECOGNITA_DBRW_PASSWORD" "\$@"
}

trafficcli() {
  socket_path=\${TRAFFICD_CONTROL_SOCKET:-/tmp/trafficd.sock}
  if ! recognita_compose ps --status running --services 2>/dev/null | grep -qx 'trafficd'; then
    printf '%s\n' 'trafficd is not running. Start it with trafficd start' >&2
    return 1
  fi
  recognita_compose exec -T trafficd /app/trafficctl "\$@" --socket "\$socket_path"
}

trafficd() {
  command=\${1:-status}
  shift || true
  case "\$command" in
    start) recognita_compose up -d --pull never trafficd ;;
    stop) recognita_compose stop trafficd ;;
    restart) recognita_compose restart trafficd ;;
    status) recognita_compose ps trafficd ;;
    logs) recognita_compose logs -f --tail=100 trafficd ;;
    *)
      printf '%s\n' 'Usage: trafficd {start|stop|restart|status|logs}' >&2
      return 64
      ;;
  esac
}
EOF
}

provision_db_access() {
  compose exec -T db env PGPASSWORD="$postgres_password" \
    psql -v ON_ERROR_STOP=1 \
    -v APP_DB_NAME="$postgres_db" \
    -v APP_DB_OWNER="$postgres_user" \
    -v DBRO_USER="$dbro_user" \
    -v DBRO_PASSWORD="$dbro_password" \
    -v DBRW_USER="$dbrw_user" \
    -v DBRW_PASSWORD="$dbrw_password" \
    -U "$postgres_user" -d "$postgres_db" \
    -f - < "$current_link/scripts/provision_db_access.sql"
}

install_shell_include() {
  bashrc="$HOME/.bashrc"
  include_line="[ -f \"$recognita_rc\" ] && . \"$recognita_rc\""
  if [ -e "$bashrc" ] && [ ! -w "$bashrc" ]; then
    printf '%s\n' "Skipping ~/.bashrc update; file is not writable." >&2
    return
  fi
  if [ ! -f "$bashrc" ] || ! grep -Fqx "$include_line" "$bashrc"; then
    printf '\n%s\n' "$include_line" >> "$bashrc"
  fi
}

prepare() {
  prepare_release
  generate_local_override
  write_runtime_env
  write_recognitarc
  install_shell_include
  if [ "$nginx_enable_tls" != "0" ] && [ "$nginx_enable_tls" != "false" ] && \
     [ "$nginx_enable_tls" != "FALSE" ] && [ "$nginx_enable_tls" != "no" ] && \
     [ "$nginx_enable_tls" != "NO" ] && [ "$nginx_enable_tls" != "off" ] && \
     [ "$nginx_enable_tls" != "OFF" ]; then
    if [ ! -f "$nginx_certs_dir/origin.crt" ] || [ ! -f "$nginx_certs_dir/origin.key" ]; then
      RECOGNITA_CERT_DIR="$nginx_certs_dir" NGINX_SERVER_NAME="$server_name" \
        sh "$current_link/scripts/generate_deploy_cert.sh"
    fi
  fi
}

ensure_prepared() {
  if [ ! -f "$runtime_env" ] || [ ! -f "$recognita_rc" ] || [ ! -f "$local_override" ] || \
     [ ! -L "$current_link" ]; then
    prepare
  fi
}

compose() {
  run_docker compose -p "$project_name" --env-file "$runtime_env" \
    -f "$current_link/docker-compose.yml" \
    -f "$current_link/docker-compose.deploy.yml" \
    -f "$local_override" "$@"
}

build_images() {
  run_docker build -f "$root_dir/Dockerfile" --target runtime -t "$app_image" "$root_dir"
  run_docker build -f "$root_dir/infra/nginx/Dockerfile" -t "$nginx_image" "$root_dir"
  run_docker build -f "$root_dir/infra/fail2ban/Dockerfile" -t "$fail2ban_image" "$root_dir"
}

remove_path_if_present() {
  path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    printf '%s\n' "Removed $path"
  fi
}

remove_file_if_present() {
  file="$1"
  if [ -f "$file" ] || [ -L "$file" ]; then
    rm -f "$file"
    printf '%s\n' "Removed $file"
  fi
}

remove_docker_project_resources() {
  if ! docker_available; then
    printf '%s\n' "Skipping Docker cleanup; Docker daemon is not reachable." >&2
    return
  fi

  if [ -f "$runtime_env" ] && [ -f "$local_override" ] && [ -L "$current_link" ] && \
     [ -f "$current_link/docker-compose.yml" ] && [ -f "$current_link/docker-compose.deploy.yml" ]; then
    compose down --remove-orphans --volumes >/dev/null 2>&1 || true
  fi

  container_ids=$(run_docker ps -aq --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || true)
  if [ -n "$container_ids" ]; then
    # Docker object IDs are whitespace-delimited; splitting is intentional here.
    if run_docker rm -f $container_ids >/dev/null 2>&1; then
      printf '%s\n' "Removed Docker containers for project $project_name"
    fi
  fi

  network_ids=$(run_docker network ls -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || true)
  if [ -n "$network_ids" ]; then
    if run_docker network rm $network_ids >/dev/null 2>&1; then
      printf '%s\n' "Removed Docker networks for project $project_name"
    fi
  fi

  volume_ids=$(run_docker volume ls -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null || true)
  if [ -n "$volume_ids" ]; then
    if run_docker volume rm -f $volume_ids >/dev/null 2>&1; then
      printf '%s\n' "Removed Docker volumes for project $project_name"
    fi
  fi

  for image in "$app_image" "$nginx_image" "$fail2ban_image"; do
    if run_docker image inspect "$image" >/dev/null 2>&1; then
      if run_docker image rm -f "$image" >/dev/null 2>&1; then
        printf '%s\n' "Removed Docker image $image"
      fi
    fi
  done
}

clean_local_artifacts() {
  remove_docker_project_resources
  remove_path_if_present "$state_root"
  remove_path_if_present "$legacy_state_root"
  remove_file_if_present "$repo_certs_dir/origin.crt"
  remove_file_if_present "$repo_certs_dir/origin.key"
  remove_path_if_present "$build_dir"
  remove_path_if_present "$trafficd_state_dir"
}

ensure_images() {
  if ! run_docker image inspect "$app_image" >/dev/null 2>&1; then
    build_images
    return
  fi
  if ! run_docker image inspect "$nginx_image" >/dev/null 2>&1; then
    build_images
    return
  fi
  if ! run_docker image inspect "$fail2ban_image" >/dev/null 2>&1; then
    build_images
  fi
}

default_services() {
  services="db rabbitmq mailpit app worker web trafficd nginx"
  if [ "$include_fail2ban" = "1" ]; then
    services="$services fail2ban"
  fi
  printf '%s\n' "$services"
}

command=${1:-up}
shift || true

case "$command" in
  prepare)
    prepare
    ;;
  build|rebuild)
    prepare
    build_images
    ;;
  up)
    prepare
    ensure_images
    compose up -d --no-build --pull never $(default_services)
    provision_db_access
    ;;
  down)
    ensure_prepared
    compose down --remove-orphans
    ;;
  logs)
    ensure_prepared
    compose logs -f --tail=100 "$@"
    ;;
  ps)
    ensure_prepared
    compose ps "$@"
    ;;
  source-line)
    ensure_prepared
    printf 'source %s\n' "$recognita_rc"
    ;;
  clean)
    clean_local_artifacts
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
