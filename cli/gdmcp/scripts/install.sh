#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
install_root=${GDMCP_INSTALL_ROOT:-"$HOME/.local/gdmcp"}

if ! command -v cargo >/dev/null 2>&1; then
    printf '%s\n' "cargo was not found in PATH" >&2
    exit 1
fi

cargo install --path "$repo_root/cli/gdmcp" --root "$install_root" --force
printf '%s\n' "Installed gdmcp to $install_root/bin. Add that directory to PATH."
