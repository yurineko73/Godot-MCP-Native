# gdmcp

`gdmcp` is an agent-friendly command-line client for Godot MCP Native. It uses the plugin's local `/cli/v1` API so shell-capable agents can discover and invoke tools without loading the complete MCP tool catalog into model context.

## Development build

```bash
./cli/gdmcp/scripts/install-dev.sh
```

On Windows PowerShell, use `cli/gdmcp/scripts/install-dev.ps1`. The development installer keeps Rustup, Cargo, build artifacts, and the installed binary under the project `.gdmcp/` directory by default. It does not modify persistent PATH or user Cargo configuration. Use `-Offline`/`--offline` to fail instead of downloading a missing toolchain.

The development workflow is for contributors and runs format, clippy, tests, and a locked release build. `cargo build --manifest-path cli/gdmcp/Cargo.toml --release` remains available when Rust is already configured.

## Release package

End users should receive a prebuilt archive from `dist/`. Installing a release archive does not require Rust:

```powershell
.\install.ps1
```

```bash
./install.sh
```

Release archives contain the executable, installers, license, manifest, and SHA-256 checksums. To create one from a clean build environment:

```powershell
.\cli\gdmcp\scripts\package.ps1 -Version 0.1.0 -Target x86_64-pc-windows-msvc
```

```bash
./cli/gdmcp/scripts/package.sh --version 0.1.0 --target x86_64-unknown-linux-gnu
```

Packaging runs locked Rust checks and writes only the final archive to `dist/`. The archive installer verifies the checksum before copying the binary and does not modify persistent PATH by default.

## Platform validation

Windows PowerShell development, packaging, and release installation flows are validated. The POSIX shell scripts for Linux and macOS are included but have not been end-to-end validated yet.

## Discover

```bash
gdmcp --json doctor
gdmcp --json tools search "runtime scene tree" --limit 5
gdmcp --json tools schema get_runtime_scene_tree
```

## Common commands

```bash
gdmcp --json editor state
gdmcp --json scenes current
gdmcp --json scenes tree --depth 4
gdmcp --json scripts read res://player.gd
gdmcp --json debug logs --limit 50
gdmcp --json runtime tree --depth 4
```

Destructive domain commands require `--apply`:

```bash
gdmcp --json nodes delete /root/Main/Enemy --apply
gdmcp --json scripts replace res://player.gd --content-file player.gd --apply
```

Configuration precedence is command line, environment, config file, then defaults. Tokens are read from environment variables and are never printed by `doctor`.
