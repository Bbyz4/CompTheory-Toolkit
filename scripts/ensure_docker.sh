#!/bin/sh
set -eu

print_missing_cli() {
  case "$(uname -s)" in
    Darwin)
      cat <<'EOF' >&2
Docker CLI is not available.

Install and launch one of:
  - Docker Desktop
  - OrbStack
  - Colima (+ docker CLI)
EOF
      ;;
    Linux)
      cat <<'EOF' >&2
Docker CLI is not available.

Install Docker Engine / Docker CLI first, for example on Debian or Ubuntu:
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-v2
EOF
      ;;
    *)
      printf '%s\n' "Docker CLI is not available. Install Docker first." >&2
      ;;
  esac
}

print_daemon_help() {
  case "$(uname -s)" in
    Darwin)
      cat <<'EOF' >&2
Docker is installed, but the daemon is not reachable.

Start your container runtime and try again:
  - Docker Desktop: open -a Docker
  - OrbStack: open -a OrbStack
  - Colima: colima start

Then verify:
  docker info
EOF
      ;;
    Linux)
      cat <<'EOF' >&2
Docker is installed, but the daemon is not reachable.

Start the daemon and try again:
  sudo systemctl start docker

Then verify:
  docker info

If permission is denied, add your user to the docker group and re-login:
  sudo usermod -aG docker "$USER"
EOF
      ;;
    *)
      cat <<'EOF' >&2
Docker is installed, but the daemon is not reachable.

Start Docker and verify with:
  docker info
EOF
      ;;
  esac
}

if ! command -v docker >/dev/null 2>&1; then
  print_missing_cli
  exit 127
fi

if docker info >/dev/null 2>&1; then
  exit 0
fi

if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
  exit 0
fi

print_daemon_help
exit 1
