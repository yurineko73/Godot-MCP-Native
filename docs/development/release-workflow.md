# Release Workflow

This document describes the complete release process for the Godot MCP Native plugin
and its companion `gdmcp` CLI tool.

## Overview

The project ships two artifacts:

| Artifact | Distribution | Platform |
|---|---|---|
| Godot MCP Native plugin (`addons/godot_mcp/`) | Godot Asset Library + GitHub Releases | Godot 4.6+ |
| gdmcp CLI (`gdmcp.exe` / `gdmcp`) | GitHub Releases | Windows / Linux / macOS |

## Versioning

Both the plugin and CLI share the same version number. The plugin version is declared in:

- `addons/godot_mcp/plugin.cfg` — `version` field
- `addons/godot_mcp/cli_release.json` — `version` field (must match CLI binary)
- `addons/godot_mcp/native_mcp/mcp_types.gd` — `PLUGIN_VERSION` constant (used for MCP serverInfo)

The CLI version is declared in:

- `cli/gdmcp/Cargo.toml` — `version` field
- `addons/godot_mcp/cli_release.json` — `version` field (read by the installer panel)

> **Rule:** All version numbers must be updated together before tagging a release.

## Release Checklist

### Step 1: Bump version numbers

Update all version declarations:

```text
addons/godot_mcp/plugin.cfg          version = "X.Y.Z"
addons/godot_mcp/cli_release.json    "version": "X.Y.Z"
addons/godot_mcp/native_mcp/mcp_types.gd   PLUGIN_VERSION
cli/gdmcp/Cargo.toml                 version = "X.Y.Z"
```

Also update `addons/godot_mcp/cli_release.json` with the correct Quark cloud drive
share URL if applicable.

### Step 2: Run full test suite

```powershell
# GUT unit tests
& "F:\Godot\Godot_v4.6.1-stable_win64.exe" --headless --path "." -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit

# Python integration tests
python test/integration/test_cli_api_flow.py

# Rust tests
cargo test --manifest-path cli/gdmcp/Cargo.toml --locked
cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets --locked -- -D warnings
cargo fmt --manifest-path cli/gdmcp/Cargo.toml --check

# Packaging tests
python test/integration/test_gdmcp_packaging.py
```

### Step 3: Build and package CLI

```powershell
# Windows
./cli/gdmcp/scripts/package.ps1 -Version X.Y.Z -Target x86_64-pc-windows-msvc

# Linux (on Linux host)
./cli/gdmcp/scripts/package.sh X.Y.Z x86_64-unknown-linux-gnu

# macOS (on macOS host)
./cli/gdmcp/scripts/package.sh X.Y.Z x86_64-apple-darwin
./cli/gdmcp/scripts/package.sh X.Y.Z aarch64-apple-darwin
```

Packages are output to `dist/`:

```text
dist/gdmcp-X.Y.Z-x86_64-pc-windows-msvc.zip
dist/gdmcp-X.Y.Z-x86_64-unknown-linux-gnu.zip
dist/gdmcp-X.Y.Z-x86_64-apple-darwin.zip
dist/gdmcp-X.Y.Z-aarch64-apple-darwin.zip
```

### Step 4: Prepare plugin archive

Package the `addons/godot_mcp/` directory for Godot Asset Library:

```powershell
Compress-Archive -Path addons/godot_mcp -DestinationPath dist/godot-mcp-native-X.Y.Z.zip
```

### Step 5: Create GitHub Release

1. Go to [GitHub Releases](https://github.com/yurineko73/Godot-MCP-Native/releases)
2. Click "Draft a new release"
3. Tag: `vX.Y.Z`
4. Title: `vX.Y.Z`
5. Upload all files from `dist/`:
   - `godot-mcp-native-X.Y.Z.zip` (plugin archive)
   - `gdmcp-X.Y.Z-x86_64-pc-windows-msvc.zip`
   - `gdmcp-X.Y.Z-x86_64-unknown-linux-gnu.zip`
   - `gdmcp-X.Y.Z-x86_64-apple-darwin.zip`
   - `gdmcp-X.Y.Z-aarch64-apple-darwin.zip`
6. Write release notes (see `docs/release-notes/` for templates)

### Step 6: Update Godot Asset Library

1. Go to [Godot Asset Library](https://godotengine.org/asset-library/)
2. Submit the `godot-mcp-native-X.Y.Z.zip` archive
3. Edit the asset listing description if needed

### Step 7: Update Quark cloud drive (optional)

Upload the same zip files to Quark cloud drive and update the `page_url` in
`addons/godot_mcp/cli_release.json` if sharing a new link.

### Step 8: Post-release

```powershell
# Update main branch with any post-release fixes
git checkout main
git pull
# Bump to next dev version if needed
git checkout -b chore/bump-version-X.Y.Z+1-dev
# ... update versions ...
git push
```

## Skill Installation (for users)

The `skills/gdmcp/` directory in the repository contains the companion Codex skill.
Users must manually install it:

```powershell
# Copy skill to Codex skills directory
Copy-Item -Recurse skills/gdmcp $env:USERPROFILE\.codex\skills\gdmcp
```

Users should also add the recommended snippet to their project's `AGENTS.md`:

```markdown
## gdmcp CLI Skill
When using the shell-oriented `gdmcp` companion for Godot editor operations,
read `skills/gdmcp/SKILL.md` first. Use the high-level bounded commands before
progressive discovery with `tools search`, `tools schema`, and `tool-call`.
```

The CLI Tools tab in the MCP panel displays download instructions and the GitHub
repository URL for these files.