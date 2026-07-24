#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
state_root="$repo_root/.gdmcp"
install_root="$state_root/bin"
toolchain_root="$state_root"
offline=false
use_system_cargo=false
dry_run=false
force=false
project_toolchain=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install-root) install_root=$2; shift 2 ;;
        --toolchain-root) toolchain_root=$2; shift 2 ;;
        --offline) offline=true; shift ;;
        --use-system-cargo) use_system_cargo=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        --force) force=true; shift ;;
        *) printf '%s\n' "Unknown option: $1" >&2; exit 2 ;;
    esac
done

manifest="$repo_root/cli/gdmcp/Cargo.toml"
cargo_home="$toolchain_root/cargo"
rustup_home="$toolchain_root/rustup"
local_cargo="$cargo_home/bin/cargo"

printf '%s\n' "Repository: $repo_root"
printf '%s\n' "Install root: $install_root"
printf '%s\n' "Toolchain root: $toolchain_root"
printf '%s\n' "System Cargo: $use_system_cargo"
printf '%s\n' "Offline: $offline"

if [ "$dry_run" = true ]; then
    printf '%s\n' "Dry run: no files, toolchains, PATH entries, or user configuration will be changed."
    exit 0
fi

[ -f "$manifest" ] || { printf '%s\n' "Cargo manifest not found: $manifest" >&2; exit 1; }

cargo=""
if [ "$use_system_cargo" = true ] && command -v cargo >/dev/null 2>&1; then
    cargo=$(command -v cargo)
fi
if [ -z "$cargo" ] && [ -x "$local_cargo" ]; then
    cargo=$local_cargo
    project_toolchain=true
    previous_rustup_home=${RUSTUP_HOME-}
    previous_cargo_home=${CARGO_HOME-}
    export RUSTUP_HOME="$rustup_home"
    export CARGO_HOME="$cargo_home"
fi

if [ -z "$cargo" ]; then
    if [ "$offline" = true ]; then
        printf '%s\n' "Offline mode cannot bootstrap a missing project-local Rust toolchain." >&2
        exit 1
    fi
    mkdir -p "$toolchain_root"
    previous_rustup_home=${RUSTUP_HOME-}
    previous_cargo_home=${CARGO_HOME-}
    export RUSTUP_HOME="$rustup_home"
    export CARGO_HOME="$cargo_home"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain stable --profile minimal
    cargo=$local_cargo
    project_toolchain=true
fi

[ -x "$cargo" ] || { printf '%s\n' "Cargo executable was not found after toolchain setup: $cargo" >&2; exit 1; }

if [ "$project_toolchain" = true ]; then
    rustup="$cargo_home/bin/rustup"
    [ -x "$rustup" ] || { printf '%s\n' "Rustup executable was not found for the project-local toolchain: $rustup" >&2; exit 1; }
    "$rustup" component add rustfmt clippy --toolchain stable
fi

mkdir -p "$install_root"
"$cargo" fmt --manifest-path "$manifest" --check
"$cargo" clippy --manifest-path "$manifest" --all-targets --locked -- -D warnings
"$cargo" test --manifest-path "$manifest" --locked
"$cargo" build --manifest-path "$manifest" --release --locked

if [ -n "${previous_rustup_home-}" ]; then export RUSTUP_HOME="$previous_rustup_home"; else unset RUSTUP_HOME; fi
if [ -n "${previous_cargo_home-}" ]; then export CARGO_HOME="$previous_cargo_home"; else unset CARGO_HOME; fi

binary="$repo_root/cli/gdmcp/target/release/gdmcp"
[ -f "$binary" ] || { printf '%s\n' "Release binary was not produced: $binary" >&2; exit 1; }
destination="$install_root/gdmcp"
if [ "$force" = true ] || [ ! -e "$destination" ]; then
    cp "$binary" "$destination"
    chmod +x "$destination"
else
    printf '%s\n' "Install target exists. Re-run with --force: $destination" >&2
    exit 1
fi

printf '%s\n' "Installed gdmcp to $destination"
printf '%s\n' "No persistent PATH or user Cargo configuration was changed."
