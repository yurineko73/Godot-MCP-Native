#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
install_root=${GDMCP_INSTALL_ROOT:-"$HOME/.local/gdmcp"}

exec "$script_dir/install-dev.sh" "$@"
