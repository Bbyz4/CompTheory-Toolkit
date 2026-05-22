#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

usage() {
  cat <<'EOF'
Usage: ./scripts/dev_helper.sh <command> [args...]

Dev-only convenience commands:
  build            Build all OCaml targets in the dev environment
  test             Run the OCaml test suite in the dev environment
  runtest          Alias for test
  shell            Open a shell in the dev environment
  dune ...         Run an arbitrary dune command in the dev environment
  exec ...         Run an arbitrary command in the dev environment
  run-api          Run the API from source with service ports
  run-web          Run the web app from source with service ports
  run-worker       Run the submission worker from source
  run-trafficd     Run trafficd from source with service ports
  run-trafficcli   Run trafficctl from source
EOF
}

command=${1:-}
if [ -z "$command" ]; then
  usage >&2
  exit 64
fi
shift || true

case "$command" in
  build)
    exec ./bin/dev dune build @all "$@"
    ;;
  test|runtest)
    exec ./bin/dev env RUN_DB_INTEGRATION_TESTS=1 dune runtest "$@"
    ;;
  shell)
    exec ./bin/dev "$@"
    ;;
  dune)
    exec ./bin/dev dune "$@"
    ;;
  exec)
    if [ "$#" -eq 0 ]; then
      printf '%s\n' "dev-helper exec requires a command" >&2
      exit 64
    fi
    exec ./bin/dev "$@"
    ;;
  run-api)
    exec ./bin/dev --service-ports dune exec apps/api/server.exe -- "$@"
    ;;
  run-web)
    exec ./bin/dev --service-ports dune exec apps/web/webapp.exe -- "$@"
    ;;
  run-worker)
    exec ./bin/dev dune exec apps/worker/worker.exe -- "$@"
    ;;
  run-trafficd)
    exec ./bin/dev --service-ports dune exec apps/trafficd/trafficd.exe -- "$@"
    ;;
  run-trafficcli)
    exec ./bin/dev dune exec apps/trafficctl/trafficctl.exe -- "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    printf '%s\n' "Unknown dev-helper command: $command" >&2
    usage >&2
    exit 64
    ;;
esac
