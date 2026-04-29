#!/bin/sh
set -eu

template_dir=/etc/nginx/templates
source_dir=/opt/recognita-nginx
selected_template="$template_dir/default.conf.template"
http_template="$source_dir/default.http.conf.template"
tls_template="$source_dir/default.tls.conf.template"

enable_tls_mode=${NGINX_ENABLE_TLS:-auto}
cert_file=${NGINX_TLS_CERT_FILE:-/etc/nginx/certs/origin.crt}
key_file=${NGINX_TLS_KEY_FILE:-/etc/nginx/certs/origin.key}

have_cert=false
if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
  have_cert=true
fi

mkdir -p "$template_dir"

case "$enable_tls_mode" in
  1|true|TRUE|yes|YES|on|ON)
    if [ "$have_cert" != true ]; then
      printf '%s\n' \
        "NGINX_ENABLE_TLS is enabled, but the TLS cert or key is missing." \
        "Expected: $cert_file and $key_file" >&2
      exit 1
    fi
    cp "$tls_template" "$selected_template"
    ;;
  0|false|FALSE|no|NO|off|OFF)
    cp "$http_template" "$selected_template"
    ;;
  auto|AUTO|'')
    if [ "$have_cert" = true ]; then
      cp "$tls_template" "$selected_template"
    else
      cp "$http_template" "$selected_template"
    fi
    ;;
  *)
    printf '%s\n' "Unsupported NGINX_ENABLE_TLS value: $enable_tls_mode" >&2
    exit 1
    ;;
esac
