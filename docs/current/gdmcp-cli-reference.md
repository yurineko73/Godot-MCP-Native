# gdmcp CLI Reference

## Purpose

`gdmcp` is the shell-oriented companion to Godot MCP Native. MCP clients normally receive every enabled tool description and JSON Schema in their model context. `gdmcp` instead keeps the catalog inside a local process and exposes detailed schemas only when the agent asks for one specific tool.

The CLI and MCP adapters execute the same registered Godot callables through `ToolRegistry` and `ToolExecutor`.

## Server routes

| Method | Route | Purpose |
|---|---|---|
| GET | `/cli/v1/doctor` | Connection, version, project, runtime and catalog status |
| GET | `/cli/v1/catalog` | Compact tool summaries without input schemas |
| GET | `/cli/v1/tools/search` | Ranked tool discovery using `q` and `limit` |
| GET | `/cli/v1/tools/<name>` | One complete tool schema and policy |
| POST | `/cli/v1/tools/<name>/execute` | Execute one registered tool |

Requests use `X-GDMCP-API-Version: 1`. The CLI API shares the MCP HTTP port and bearer-token authentication. It accepts loopback requests by default; remote access follows the plugin's existing remote-access setting.

## Discovery

```powershell
gdmcp --json doctor
gdmcp --json tools search "runtime scene tree" --limit 5
gdmcp --json tools schema get_runtime_scene_tree
```

The compact catalog deliberately excludes complete input and output schemas.

## Raw execution

```powershell
gdmcp --json tool-call get_project_info --args-json "{}"
```

Complex arguments should be stored in a file:

```powershell
gdmcp --json tool-call update_node_property `
  --args-file .gdmcp\update-node.json
```

Supported output controls are `--fields`, `--limit`, `--cursor`, `--depth`, `--max-bytes`, and `--out`.

## Domain commands

The CLI includes ~33 domain commands for editor state, scenes, nodes, scripts,
resources, project operations, logs, runtime inspection, and batch preview/apply.
All other registered tools (~120 supplementary) are reachable through progressive
discovery: `tools search`, `tools schema`, `tool-call`.

### Scene operations

```powershell
gdmcp --json scenes current
gdmcp --json scenes list --limit 20
gdmcp --json scenes tree --depth 4 --fields path,type
gdmcp --json scenes resolve Player
```

### Node operations

```powershell
gdmcp --json nodes list --limit 20
gdmcp --json nodes get /root/Main/Player --fields position,visible
gdmcp --json nodes resolve Camera
gdmcp --json nodes create --parent /root --type Node2D --name Enemy
gdmcp --json nodes move /root/Main/Enemy --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy --new-name Boss
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
```

### Script operations

```powershell
gdmcp --json scripts list --limit 20
gdmcp --json scripts list --limit 20 --cursor 20
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json scripts resolve player
gdmcp --json scripts create res://enemy.gd --script-type GDScript
gdmcp --json scripts validate res://player.gd
```

### Resource operations

```powershell
gdmcp --json resources list --limit 20 --cursor 20
gdmcp --json resources get res://player.tres
gdmcp --json resources get res://player.tres --fields resource_path,resource_name
gdmcp --json resources resolve icon
```

### Project and runtime

```powershell
gdmcp --json project info
gdmcp --json project settings --filter display/
gdmcp --json runtime tree --depth 3
gdmcp --json runtime nodes get /root/Main/Player
```

Generic lists and logs default to 50 items. `--limit` must be a positive
integer; use `--cursor` (or the log-specific offset cursor) to continue.
`--fields` reduces output for node and resource property inspection.
`--lines <start>:<end>` bounds script reads. Resolve commands convert
human-readable names to stable paths.

Do not request the complete settings set without a filter. Use `tools schema get_project_settings` and a raw call only when a different filter is required.

Batch files use registered tool names and object arguments:

```json
{
  "operations": [
    {
      "tool": "get_project_info",
      "arguments": {}
    }
  ]
}
```

Run `batch preview` before `batch apply`; `batch apply` still requires `--apply`.
The CLI validates the complete batch before sending requests, then executes it
sequentially and non-atomically. A later failure does not roll back earlier
operations.

## Safety

The server derives policy from MCP annotations and category metadata:

- supplementary tools are hidden from MCP by default but remain discoverable through CLI when allowed;
- `destructiveHint=true` requires `apply_confirmed=true`;
- `openWorldHint=true` requires `allow_open_world=true`;
- dry-run returns a preview for write and destructive tools without invoking the callable;
- administrator availability and MCP visibility remain separate from CLI permission.

High-level destructive commands require `--apply` locally before any network request. Raw calls remain available as an escape hatch but are still checked by the server.

## Configuration

Precedence is command-line options, environment variables, the OS-specific config file, then defaults. Supported environment variables are `GODOT_MCP_URL`, `GODOT_MCP_TOKEN`, and `GODOT_MCP_TIMEOUT`. `--token-env` selects a different token variable.

## Development and release distribution

The repository separates contributor tooling from end-user distribution:

- `cli/gdmcp/scripts/install-dev.ps1` and `install-dev.sh` bootstrap or reuse a project-local Rust toolchain under `.gdmcp/`, run the locked checks, and install a development binary under `.gdmcp/bin/`.
- `cli/gdmcp/scripts/package.ps1` and `package.sh` build a versioned archive under `dist/`. The archive contains `gdmcp`, `install.ps1`, `install.sh`, `README.md`, `LICENSE`, `SHA256SUMS`, and `release-manifest.json`.
- Release users run the installer from the archive. A release archive contains a prebuilt binary and does not require Rust. The installer verifies SHA-256 before copying the executable and leaves persistent PATH unchanged unless the user adds it manually.

PowerShell packaging example:

```powershell
./cli/gdmcp/scripts/package.ps1 -Version 0.1.0 -Target x86_64-pc-windows-msvc
```

The checked-in `cli/gdmcp/Cargo.lock` and `cli/gdmcp/rust-toolchain.toml` make the development and packaging inputs explicit.

Windows PowerShell development, packaging, and release installation flows have been validated. Linux and macOS POSIX shell flows are included but remain unverified end-to-end.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success, including an empty result |
| 2 | Invalid CLI arguments or JSON shape |
| 3 | Configuration error |
| 4 | Godot service unreachable |
| 5 | API, HTTP, I/O or execution failure |
| 6 | Explicit permission or apply confirmation required |
| 8 | CLI API version mismatch |

## Verification

```powershell
cargo fmt --manifest-path cli/gdmcp/Cargo.toml --check
cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path cli/gdmcp/Cargo.toml
python test/integration/test_cli_api_flow.py
```
