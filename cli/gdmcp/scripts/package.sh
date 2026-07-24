#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
cli_root=$repo_root/cli/gdmcp
manifest=$cli_root/Cargo.toml
lockfile=$cli_root/Cargo.lock
local_cargo_home=$repo_root/.gdmcp/cargo
local_rustup_home=$repo_root/.gdmcp/rustup
local_cargo=$local_cargo_home/bin/cargo
output_dir=${GDMCP_OUTPUT_DIR:-$repo_root/dist}
version=
target=
clean=0
dry_run=0

usage() {
    printf '%s\n' "Usage: package.sh [--version VERSION] [--target TARGET] [--output-dir DIR] [--clean] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; version=$2; shift 2 ;;
        --target) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; target=$2; shift 2 ;;
        --output-dir) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; output_dir=$2; shift 2 ;;
        --clean) clean=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -f "$manifest" ] || { printf 'Cargo manifest not found: %s\n' "$manifest" >&2; exit 1; }
[ -f "$lockfile" ] || { printf 'Cargo.lock is required for reproducible packaging.\n' >&2; exit 1; }

source_version=$(awk -F '"' '/^[[:space:]]*version[[:space:]]*=/ { print $2; exit }' "$manifest")
[ -n "$source_version" ] || { printf 'Package version was not found.\n' >&2; exit 1; }
if [ -z "$version" ]; then version=$source_version; fi
[ "$version" = "$source_version" ] || { printf 'Version mismatch: requested %s but Cargo.toml declares %s\n' "$version" "$source_version" >&2; exit 1; }

if [ -z "$target" ]; then
    target=$(rustc -vV 2>/dev/null | awk '/^host:/ { print $2; exit }' || true)
fi
[ -n "$target" ] || { printf 'Target is required when rustc is not available on PATH.\n' >&2; exit 1; }
case "$target" in *[!A-Za-z0-9._-]*) printf 'Target contains unsupported characters: %s\n' "$target" >&2; exit 1 ;; esac

archive_name=gdmcp-$version-$target.tar.gz
output_dir=$(CDPATH= cd -- "$output_dir" 2>/dev/null && pwd || { mkdir -p -- "$output_dir"; CDPATH= cd -- "$output_dir" && pwd; })
staging=$output_dir/.staging/gdmcp-$version-$target
archive=$output_dir/$archive_name

printf 'Packaging gdmcp %s for %s\n' "$version" "$target"
if [ "$dry_run" -eq 1 ]; then
    printf '%s\n' 'Dry run: no build, archive, or filesystem changes will be made.'
    exit 0
fi

if command -v cargo >/dev/null 2>&1; then
    cargo_command=$(command -v cargo)
    project_toolchain=false
elif [ -x "$local_cargo" ]; then
    cargo_command=$local_cargo
    project_toolchain=true
    previous_rustup_home=${RUSTUP_HOME-}
    previous_cargo_home=${CARGO_HOME-}
    export RUSTUP_HOME="$local_rustup_home"
    export CARGO_HOME="$local_cargo_home"
else
    printf 'Cargo was not found on PATH or in .gdmcp. Run install-dev.sh first or use a release package.\n' >&2
    exit 1
fi

if [ -e "$staging" ]; then
    [ "$clean" -eq 1 ] || { printf 'Staging directory exists. Re-run with --clean: %s\n' "$staging" >&2; exit 1; }
    rm -rf -- "$staging"
fi
mkdir -p -- "$staging"
cleanup() { rm -rf -- "$staging"; }
trap cleanup EXIT INT TERM

cargo fmt --manifest-path "$manifest" --check
cargo clippy --manifest-path "$manifest" --all-targets --locked -- -D warnings
cargo test --manifest-path "$manifest" --locked
"$cargo_command" fmt --manifest-path "$manifest" --check
"$cargo_command" clippy --manifest-path "$manifest" --all-targets --locked -- -D warnings
"$cargo_command" test --manifest-path "$manifest" --locked
"$cargo_command" build --manifest-path "$manifest" --release --locked --target "$target"

binary=$cli_root/target/$target/release/gdmcp
if [ ! -f "$binary" ]; then binary=$cli_root/target/release/gdmcp; fi
[ -f "$binary" ] || { printf 'Release binary was not produced: %s\n' "$binary" >&2; exit 1; }
cp -- "$binary" "$staging/gdmcp"
cp -- "$cli_root/packaging/install.ps1" "$staging/install.ps1"
cp -- "$cli_root/packaging/install.sh" "$staging/install.sh"
cp -- "$cli_root/packaging/README.md" "$staging/README.md"
cp -- "$cli_root/packaging/LICENSE" "$staging/LICENSE"

if command -v sha256sum >/dev/null 2>&1; then
    (cd "$staging" && sha256sum gdmcp > SHA256SUMS)
else
    (cd "$staging" && shasum -a 256 gdmcp > SHA256SUMS)
fi
printf '{\n  "schema_version": 1,\n  "package": "gdmcp",\n  "version": "%s",\n  "target": "%s",\n  "executable": "gdmcp"\n}\n' "$version" "$target" > "$staging/release-manifest.json"
rm -f -- "$archive"
(cd "$staging" && tar -czf "$archive" .)
printf 'Created %s\n' "$archive"
if [ "${project_toolchain:-false}" = true ]; then
    if [ -n "${previous_rustup_home-}" ]; then export RUSTUP_HOME="$previous_rustup_home"; else unset RUSTUP_HOME; fi
    if [ -n "${previous_cargo_home-}" ]; then export CARGO_HOME="$previous_cargo_home"; else unset CARGO_HOME; fi
fi
