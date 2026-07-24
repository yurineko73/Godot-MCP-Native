#!/usr/bin/env sh
set -eu
install_dir="${GDMCP_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
printf '%s\n' "Place the gdmcp release binary in $install_dir and ensure it is on PATH."
