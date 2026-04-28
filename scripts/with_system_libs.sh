#!/bin/sh
set -eu

prepend_path() {
  dir="$1"
  if [ -d "$dir" ]; then
    PATH="$dir:$PATH"
  fi
}

prepend_env_path() {
  var_name="$1"
  dir="$2"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  eval "current_value=\${$var_name:-}"
  if [ -n "$current_value" ]; then
    eval "export $var_name=\$dir:\$current_value"
  else
    eval "export $var_name=\$dir"
  fi
}

detect_pg_libdir() {
  if command -v brew >/dev/null 2>&1; then
    if brew --prefix libpq >/dev/null 2>&1; then
      printf "%s/lib" "$(brew --prefix libpq)"
      return 0
    fi

    if brew --prefix postgresql >/dev/null 2>&1; then
      printf "%s/lib" "$(brew --prefix postgresql)"
      return 0
    fi
  fi

  if command -v pg_config >/dev/null 2>&1; then
    pg_config --libdir
    return 0
  fi

  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libpq; then
    pkg-config --variable=libdir libpq
    return 0
  fi

  return 1
}

detect_openssl_libdir() {
  if command -v brew >/dev/null 2>&1; then
    if brew --prefix openssl@3 >/dev/null 2>&1; then
      printf "%s/lib" "$(brew --prefix openssl@3)"
      return 0
    fi

    if brew --prefix openssl >/dev/null 2>&1; then
      printf "%s/lib" "$(brew --prefix openssl)"
      return 0
    fi
  fi

  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists openssl; then
    pkg-config --variable=libdir openssl
    return 0
  fi

  return 1
}

detect_pkg_config_dir() {
  package_name="$1"

  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "$package_name"; then
    pkg-config --variable=pcfiledir "$package_name"
    return 0
  fi

  return 1
}

append_library_path() {
  dir="$1"

  case "$(uname -s)" in
    Darwin)
      prepend_env_path DYLD_LIBRARY_PATH "$dir"
      prepend_env_path DYLD_FALLBACK_LIBRARY_PATH "$dir"
      prepend_env_path LD_LIBRARY_PATH "$dir"
      ;;
    *)
      prepend_env_path LD_LIBRARY_PATH "$dir"
      ;;
  esac
}

if [ "$(uname -s)" = "Darwin" ]; then
  prepend_path /usr/bin
  prepend_path /bin
  prepend_path /usr/sbin
  prepend_path /sbin
  prepend_path /opt/homebrew/bin
  prepend_path /opt/homebrew/sbin
  export PATH

  if [ -x /usr/bin/ar ]; then
    export AR=/usr/bin/ar
  fi

  if [ -x /usr/bin/ranlib ]; then
    export RANLIB=/usr/bin/ranlib
  fi
fi

if pg_libdir="$(detect_pg_libdir)"; then
  append_library_path "$pg_libdir"
fi

if openssl_libdir="$(detect_openssl_libdir)"; then
  append_library_path "$openssl_libdir"
fi

if libpq_pkgconfig_dir="$(detect_pkg_config_dir libpq)"; then
  prepend_env_path PKG_CONFIG_PATH "$libpq_pkgconfig_dir"
fi

if openssl_pkgconfig_dir="$(detect_pkg_config_dir openssl)"; then
  prepend_env_path PKG_CONFIG_PATH "$openssl_pkgconfig_dir"
fi

exec "$@"
