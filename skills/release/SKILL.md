---
name: release
description: Automate Godot MCP Native plugin and CLI release. Bumps versions, runs tests, builds packages, creates GitHub Release draft.
---

# Release Godot MCP Native

Use this skill when asked to release a new version of the Godot MCP Native plugin
and gdmcp CLI.

## Prerequisites

- Rust toolchain installed at `.gdmcp/` (or system-wide cargo)
- Godot 4.6.1 at `F:\Godot\Godot_v4.6.1-stable_win64.exe`
- Python 3 with `test/integration/` dependencies
- `gh` CLI authenticated with `yurineko73/Godot-MCP-Native` repo access

## Workflow

### 1. Run the release script

```powershell
.\scripts\release.ps1 -Version <X.Y.Z>
```

This automates:
- Version bump in `plugin.cfg`, `cli_release.json`, `mcp_types.gd`, `Cargo.toml`
- Full test suite (Rust tests + clippy + GUT + packaging)
- CLI package build (Windows x64; Linux/macOS built separately)
- Plugin archive (`dist/godot-mcp-native-X.Y.Z.zip`)
- GitHub Release draft with artifacts uploaded

Use `-DryRun` to preview without changes. Use `-SkipTests` for quick iteration.

### 2. Build other platform packages (on their respective hosts)

```bash
# Linux
./cli/gdmcp/scripts/package.sh X.Y.Z x86_64-unknown-linux-gnu

# macOS
./cli/gdmcp/scripts/package.sh X.Y.Z x86_64-apple-darwin
./cli/gdmcp/scripts/package.sh X.Y.Z aarch64-apple-darwin
```

Upload the resulting zip files to the GitHub Release draft.

### 3. Manual steps

- Submit `godot-mcp-native-X.Y.Z.zip` to [Godot Asset Library](https://godotengine.org/asset-library/)
- Upload packages to Quark cloud drive (share link pre-configured in cli_release.json; update only if Quark generates a new link)
- Publish the GitHub Release draft
- Commit version bump: `git commit -m "chore: bump version to X.Y.Z"`

### 4. Verify the release

After publishing:

```powershell
# Install from GitHub Release
gdmcp --json doctor

# Verify the plugin panel shows correct version in Godot editor
```

## Troubleshooting

- If `gh release create` fails, check `gh auth status`
- If Rust tests fail, run `cargo test --manifest-path cli/gdmcp/Cargo.toml` directly
- If GUT fails, open the project in Godot editor and run tests interactively
- If packaging tests fail, check `test/integration/test_gdmcp_packaging.py`