#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

domain=${1:-${NGINX_SERVER_NAME:-recognita.xyz}}
cert_dir=${RECOGNITA_CERT_DIR:-"$root_dir/infra/nginx/certs"}
cert_file="$cert_dir/origin.crt"
key_file="$cert_dir/origin.key"
days=${TLS_CERT_DAYS:-365}

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "OpenSSL is required to generate a deployment certificate." >&2
  exit 1
fi

mkdir -p "$cert_dir"

openssl req \
  -x509 \
  -newkey rsa:4096 \
  -sha256 \
  -nodes \
  -days "$days" \
  -keyout "$key_file" \
  -out "$cert_file" \
  -subj "/CN=$domain" \
  -addext "subjectAltName=DNS:$domain"

chmod 600 "$key_file"
chmod 644 "$cert_file"

printf '%s\n' \
  "Generated $cert_file and $key_file for $domain." \
  "Set Cloudflare SSL/TLS mode to Full if you use this self-signed certificate." \
  "For Full (strict), replace these files with a Cloudflare Origin CA certificate."
