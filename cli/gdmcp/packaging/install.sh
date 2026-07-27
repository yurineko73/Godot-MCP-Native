#!/usr/bin/env sh
set -eu

archive_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_root=${GDMCP_INSTALL_ROOT:-"$HOME/.local/gdmcp/bin"}
expected_version=
expected_target=
add_path=0
uninstall=0
dry_run=0

usage() {
    printf '%s\n' "Usage: install.sh [--install-root DIR] [--expected-version VERSION] [--expected-target TARGET] [--add-path] [--uninstall] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install-root)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            install_root=$2
            shift 2
            ;;
        --expected-version)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            expected_version=$2
            shift 2
            ;;
        --expected-target)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            expected_target=$2
            shift 2
            ;;
        --add-path) add_path=1; shift ;;
        --uninstall) uninstall=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

manifest_path=$archive_root/release-manifest.json
checksums_path=$archive_root/SHA256SUMS
[ -f "$manifest_path" ] || { printf 'Release manifest not found: %s\n' "$manifest_path" >&2; exit 1; }
[ -f "$checksums_path" ] || { printf 'Checksum file not found: %s\n' "$checksums_path" >&2; exit 1; }

json_string_value() {
    key=$1
    sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest_path" | head -n 1
}

schema_version=$(sed -n 's/.*"schema_version"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$manifest_path" | head -n 1)
package_name=$(json_string_value package)
manifest_version=$(json_string_value version)
manifest_target=$(json_string_value target)
executable=$(json_string_value executable)

[ "$schema_version" = "1" ] || { printf 'Unsupported release manifest schema: %s\n' "$schema_version" >&2; exit 1; }
[ "$package_name" = "gdmcp" ] || { printf 'Release manifest package is not gdmcp: %s\n' "$package_name" >&2; exit 1; }
if [ -n "$expected_version" ] && [ "$manifest_version" != "$expected_version" ]; then
    printf 'Release manifest version mismatch: expected %s but found %s\n' "$expected_version" "$manifest_version" >&2
    exit 1
fi
if [ -n "$expected_target" ] && [ "$manifest_target" != "$expected_target" ]; then
    printf 'Release manifest target mismatch: expected %s but found %s\n' "$expected_target" "$manifest_target" >&2
    exit 1
fi
[ -n "$executable" ] || { printf 'Manifest executable is missing.\n' >&2; exit 1; }
case "$executable" in */*|*\\*) printf 'Manifest executable is invalid.\n' >&2; exit 1 ;; esac

source=$archive_root/$executable
destination=$install_root/$executable

if [ "$uninstall" -eq 1 ]; then
    if [ "$dry_run" -eq 1 ]; then
        printf 'Dry run: would remove %s\n' "$destination"
    elif [ -e "$destination" ]; then
        rm -f -- "$destination"
        printf 'Removed %s\n' "$destination"
    else
        printf 'Not installed: %s\n' "$destination"
    fi
    exit 0
fi

[ -f "$source" ] || { printf 'Release executable not found: %s\n' "$source" >&2; exit 1; }
checksum=$(awk -v name="$executable" '$2 == name || $2 == "*" name { print $1; exit }' "$checksums_path")
[ "${#checksum}" -eq 64 ] || { printf 'Checksum entry is missing for %s\n' "$executable" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$source" | awk '{print $1}')
else
    actual=$(shasum -a 256 "$source" | awk '{print $1}')
fi
[ "$actual" = "$checksum" ] || { printf 'SHA-256 verification failed for %s\n' "$source" >&2; exit 1; }

if [ "$dry_run" -eq 1 ]; then
    printf 'Dry run: would install %s to %s\n' "$source" "$destination"
else
    mkdir -p -- "$install_root"
    cp -- "$source" "$destination"
    chmod +x -- "$destination"
    printf 'Installed %s\n' "$destination"
fi

if [ "$add_path" -eq 1 ]; then
    printf 'Add this directory to your PATH if desired: %s\n' "$install_root"
    printf '%s\n' 'The installer does not modify persistent PATH automatically.'
fi
