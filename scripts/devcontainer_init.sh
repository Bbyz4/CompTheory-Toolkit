#!/bin/sh
set -eu

docker_socket=/var/run/docker.sock

if [ -S "$docker_socket" ] && command -v stat >/dev/null 2>&1; then
  socket_gid=$(stat -c '%g' "$docker_socket")
  if [ -n "$socket_gid" ]; then
    group_name=$(getent group "$socket_gid" | cut -d: -f1 || true)
    if [ -z "$group_name" ]; then
      group_name=dockersock
      if ! getent group "$group_name" >/dev/null 2>&1; then
        groupadd -g "$socket_gid" "$group_name"
      fi
    fi
    usermod -aG "$group_name" opam
  fi
fi

exec sleep infinity
