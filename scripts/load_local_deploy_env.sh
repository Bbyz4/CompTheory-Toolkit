#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runtime_env="$root_dir/.local-deploy/state/.env.deploy.runtime"

if [ "${IN_DEV_CONTAINER:-}" != "1" ] || [ ! -f "$runtime_env" ]; then
  return 0
fi

set -a
# shellcheck disable=SC1090
. "$runtime_env"
set +a

container_host=${LOCAL_DEPLOY_CONTAINER_HOST:-host.docker.internal}
postgres_public_port=${POSTGRES_PUBLIC_PORT:-5432}
rabbitmq_management_public_port=${RABBITMQ_MANAGEMENT_PUBLIC_PORT:-15672}
smtp_public_port=${SMTP_PUBLIC_PORT:-1025}
app_port=${APP_PORT:-8080}
web_port=${WEB_PORT:-8081}

export APP_MODE=local
export APP_BASE_URL=${DEVCONTAINER_APP_BASE_URL:-http://localhost:$app_port}
export PUBLIC_WEB_BASE_URL=${DEVCONTAINER_PUBLIC_WEB_BASE_URL:-http://localhost:$web_port}
export API_BASE_URL=${DEVCONTAINER_API_BASE_URL:-http://127.0.0.1:$app_port}
export TRAFFICD_API_BASE_URL=${DEVCONTAINER_TRAFFICD_API_BASE_URL:-http://127.0.0.1:$app_port}
export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${container_host}:${postgres_public_port}/${POSTGRES_DB}"
export DATABASE_URL_RO="postgresql://${DBRO_USER}:${DBRO_PASSWORD}@${container_host}:${postgres_public_port}/${POSTGRES_DB}"
export DATABASE_URL_RW="postgresql://${DBRW_USER}:${DBRW_PASSWORD}@${container_host}:${postgres_public_port}/${POSTGRES_DB}"
export SMTP_HOST=$container_host
export SMTP_PORT=$smtp_public_port
export RABBITMQ_API_BASE_URL="http://${container_host}:${rabbitmq_management_public_port}"
