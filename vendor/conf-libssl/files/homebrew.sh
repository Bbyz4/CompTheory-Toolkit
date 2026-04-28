#!/bin/sh -ex

brew_prefix="$(brew --prefix openssl@3 2>/dev/null || brew --prefix openssl)"
brew_pkg_config="$brew_prefix/lib/pkgconfig"

case "$1" in
  check)
    if test "$#" != 1; then
      echo "Usage: $0 check"
      exit 1
    fi
    export PKG_CONFIG_PATH="$brew_pkg_config:$PKG_CONFIG_PATH"
    pkg-config --print-errors --exists openssl
    ;;
  install)
    if test "$#" != 2; then
      echo "Usage: $0 install <libdir>"
      exit 1
    fi
    for fpath in "$brew_pkg_config"/*.pc; do
      test -e "$fpath" || break
      fname=$(basename "$fpath")
      tdir="$2/pkgconfig"
      mkdir -p "$tdir"
      ln -sf "$fpath" "$tdir/$fname"
    done
    ;;
  *)
    echo "Usage: $0 <check|install>"
    exit 1
    ;;
esac

