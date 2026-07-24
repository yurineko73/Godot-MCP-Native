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

The first release includes commands for editor state, scenes, nodes, scripts, project operations, logs, runtime inspection, and batch preview/apply.

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
