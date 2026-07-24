# gdmcp Agent CLI Architecture Design

**Status:** Approved for planning  
**Date:** 2026-07-24  
**Repository:** `yurineko73/Godot-MCP-Native`  
**Target:** Godot 4.6.x editor plugin, Codex/Claude Code and other shell-capable coding agents

## 1. Summary

Godot MCP Native currently exposes a large catalog of editor, scene, script, node, project, and runtime debugging operations through MCP. The complete catalog is useful, but sending dozens or hundreds of tool definitions to an AI client consumes context before the user task begins.

This design adds a companion command-line interface named `gdmcp`. Shell-capable agents call the CLI through their normal terminal tool. The CLI performs progressive discovery: it exposes a small stable command surface for common work and queries individual low-frequency tool schemas only when required.

The design keeps the existing Godot plugin as the execution authority. It does not duplicate the implementation of each tool in Rust. Instead, the plugin gains a protocol-neutral registry, executor, policy layer, and a small localhost CLI API. Both MCP and CLI adapters invoke the same executor.

## 2. Goals

1. Reduce model context consumed by the Godot integration.
2. Preserve access to the complete Godot tool catalog without exposing all schemas at session start.
3. Provide stable, composable, machine-readable commands for common agent workflows.
4. Keep one implementation of every Godot operation.
5. Separate tool availability, MCP visibility, and CLI permission.
6. Bound large outputs by default and support pagination, field projection, depth limits, and file output.
7. Provide deterministic safety behavior for destructive and open-world operations.
8. Ship as a cross-platform single executable for Windows, Linux, and macOS.
9. Provide a compact companion Skill and `AGENTS.md` guidance so agents know how to use the CLI.

## 3. Non-goals

1. Replacing MCP for clients that do not have shell access.
2. Reimplementing Godot editor operations in Rust.
3. Exposing a general arbitrary-code execution API beyond the existing tool policies.
4. Building an interactive terminal UI.
5. Automatically enabling every high-risk supplementary tool.
6. Making the first release a remote multi-user service. The CLI API is localhost-first.
7. Creating 154 or more hand-maintained Rust subcommands.

## 4. Current Constraints

- The plugin is a native Godot EditorPlugin with HTTP and stdio MCP transports.
- Tool metadata currently includes name, description, input schema, output schema, annotations, category, group, callable, and enabled state.
- Core and supplementary tool classifications already exist.
- Supplementary tools are disabled by default.
- `enabled` currently controls both visibility in `tools/list` and permission to execute through `tools/call`.
- Code files must contain English only. Chinese is permitted in project documentation.
- Every production code change requires direct tests and impact-range tests.
- The supported editor baseline is Godot 4.6.x.

## 5. Design Principles

### 5.1 Progressive disclosure

The agent receives only a short CLI usage contract initially. Detailed schemas are loaded only for the selected command or low-frequency tool.

Expected low-frequency flow:

```text
1. gdmcp --json tools search "runtime shader parameter" --limit 5
2. gdmcp --json tools schema set_runtime_shader_parameter
3. gdmcp --json tool-call set_runtime_shader_parameter --args-file request.json
```

The agent must not request the complete catalog with every schema unless explicitly diagnosing the integration.

### 5.2 One source of truth

The Godot tool registry remains authoritative for:

- tool name;
- description;
- input and output schemas;
- annotations;
- category and group;
- callable implementation;
- execution policy.

CLI documentation and low-level command metadata are generated or queried from this registry. The Rust CLI does not maintain a second copy of the full catalog.

### 5.3 Domain commands before raw calls

Common workflows use domain-oriented commands such as:

```text
gdmcp --json scenes tree --depth 4
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json nodes properties set /root/Main/Player --property speed --value-json 300
gdmcp --json debug logs --level error --limit 50
```

The generic `tool-call` command is an escape hatch for supplementary or newly added tools that do not yet have a high-level command.

### 5.4 Bounded output

All collection and tree commands support limits appropriate to their data shape:

- `--limit`;
- `--cursor`;
- `--depth`;
- `--fields`;
- `--max-bytes`;
- `--out`.

Commands must not silently dump an entire project tree, profiler stream, log history, or binary artifact into model context.

### 5.5 Explicit writes

Read commands and write commands are distinct. Write commands use explicit verbs such as `create`, `set`, `replace`, `delete`, `apply`, `run`, and `stop`.

Destructive operations require `--apply`. Open-world operations require `--allow-open-world`. Batch writes support `preview` and `apply` as separate commands.

## 6. Architecture

```text
┌───────────────────────────────────────────────────────────────┐
│                  Godot MCP Native Plugin                      │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  Protocol-neutral core                  │  │
│  │                                                         │  │
│  │  ToolRegistry       ToolExecutor       ToolPolicy       │  │
│  │  ToolDefinition     ExecutionContext   ExecutionResult  │  │
│  │  CatalogSearch      ResultLimiter      VersionInfo      │  │
│  └──────────────────────────┬──────────────────────────────┘  │
│                             │                                 │
│             ┌───────────────┴────────────────┐                │
│             │                                │                │
│  ┌──────────▼──────────┐          ┌──────────▼──────────┐     │
│  │ MCP Adapter          │          │ CLI API Adapter      │     │
│  │ initialize           │          │ /cli/v1/doctor       │     │
│  │ tools/list           │          │ /cli/v1/catalog      │     │
│  │ tools/call           │          │ /cli/v1/tools/...    │     │
│  │ resources/prompts    │          │ /cli/v1/execute      │     │
│  └──────────┬──────────┘          └──────────┬──────────┘     │
└─────────────┼────────────────────────────────┼────────────────┘
              │                                │
         MCP clients                    localhost HTTP
                                               │
                                      ┌────────▼────────┐
                                      │ Rust gdmcp CLI  │
                                      │ domain commands │
                                      │ stable JSON     │
                                      └────────┬────────┘
                                               │
                                      agent shell tool
```

## 7. Godot Core Components

### 7.1 ToolDefinition

`ToolDefinition` is a protocol-neutral replacement for using `MCPTool` as the central domain model.

Required fields:

```gdscript
class_name ToolDefinition
extends RefCounted

var name: String = ""
var description: String = ""
var input_schema: Dictionary = {}
var output_schema: Dictionary = {}
var annotations: Dictionary = {}
var callable: Callable = Callable()
var category: String = "core"
var group: String = ""
var policy: ToolPolicy = ToolPolicy.new()
```

During migration, `MCPTypes.MCPTool` may remain as a compatibility alias or adapter. Existing registration calls must continue to work until all tests and adapters use `ToolDefinition`.

### 7.2 ToolPolicy

The current single `enabled` flag is split into independent controls:

```gdscript
class_name ToolPolicy
extends RefCounted

var available: bool = true
var mcp_visible: bool = true
var cli_allowed: bool = true
var risk_level: String = "read"
var requires_apply: bool = false
var requires_open_world_permission: bool = false
```

Default policy derivation:

| Condition | Result |
|---|---|
| Core read-only tool | MCP visible, CLI allowed, no apply requirement |
| Core write tool | MCP visible, CLI allowed, explicit write command |
| Supplementary read-only tool | MCP hidden by default, CLI allowed |
| Supplementary write tool | MCP hidden by default, CLI allowed, may require apply |
| `destructiveHint=true` | `risk_level=destructive`, `requires_apply=true` |
| `openWorldHint=true` | `requires_open_world_permission=true` |
| Administrator-disabled tool | unavailable through both adapters |

Manual policy overrides are allowed for tools whose annotations are incomplete or whose behavior is more dangerous than the annotation implies.

### 7.3 ToolRegistry

Responsibilities:

- register and unregister tool definitions;
- retrieve one definition by exact name;
- list definitions by policy, category, or group;
- search compact catalog entries;
- compute a stable catalog hash;
- expose no transport-specific response shape.

Public interface:

```gdscript
class_name ToolRegistry
extends RefCounted

func register_tool(definition: ToolDefinition) -> Error
func unregister_tool(name: String) -> bool
func get_tool(name: String) -> ToolDefinition
func list_tools(filter: Dictionary = {}) -> Array[ToolDefinition]
func search_tools(query: String, limit: int = 5) -> Array[Dictionary]
func get_catalog_hash() -> String
```

Search is deterministic token matching in the first release. The searchable text is normalized from `name`, `description`, `group`, and category. Semantic embeddings are not required.

### 7.4 ToolExecutionContext

Each adapter supplies its execution context:

```gdscript
class_name ToolExecutionContext
extends RefCounted

var caller: String = "mcp"
var request_id: String = ""
var dry_run: bool = false
var apply_confirmed: bool = false
var allow_open_world: bool = false
var max_bytes: int = 65536
```

Allowed caller values in version 1 are `mcp`, `cli`, and `internal_test`.

### 7.5 ToolExecutionResult

All handlers are normalized before adapter serialization:

```gdscript
class_name ToolExecutionResult
extends RefCounted

var ok: bool = false
var data: Variant = null
var error_code: String = ""
var error_message: String = ""
var retryable: bool = false
var warnings: Array[String] = []
var artifacts: Array[Dictionary] = []
var truncated: bool = false
var next_cursor: String = ""
```

Legacy handlers may continue returning dictionaries. `ToolExecutor` converts these to `ToolExecutionResult`:

- a dictionary containing `error` becomes `ok=false`;
- every other return value becomes `ok=true` with the value in `data`;
- oversized serialized data is rejected or truncated according to the command contract;
- binary data is written as an artifact rather than included in JSON.

### 7.6 ToolExecutor

Responsibilities:

- resolve the tool;
- validate availability and caller permission;
- enforce `--apply` and open-world policy;
- validate input against existing handler validation and, where practical, schema-level checks;
- invoke the callable exactly once;
- normalize the result;
- emit existing execution signals and logs;
- contain no MCP or CLI JSON envelope logic.

Public interface:

```gdscript
class_name ToolExecutor
extends RefCounted

func execute(
    tool_name: String,
    arguments: Dictionary,
    context: ToolExecutionContext
) -> ToolExecutionResult
```

### 7.7 ResultLimiter

The limiter enforces output boundaries for CLI API responses. It supports:

- maximum serialized byte count;
- list slicing with cursor metadata;
- recursive depth limiting for known tree responses;
- field projection for dictionaries and arrays of dictionaries;
- artifact fallback for large text or binary content.

The first release may implement adapter-level limiters for known high-volume commands and a generic maximum byte guard for raw `tool-call`.

## 8. Adapter Behavior

### 8.1 MCP Adapter

The MCP adapter continues to implement the negotiated MCP protocol. Changes are internal:

- `tools/list` reads definitions from `ToolRegistry` and includes only tools with `available=true` and `mcp_visible=true`;
- `tools/call` creates an MCP execution context and calls `ToolExecutor`;
- the result mapper preserves current MCP `content`, `isError`, and `structuredContent` behavior;
- tool-list change notifications continue to work when MCP visibility changes.

Existing MCP clients remain compatible.

### 8.2 CLI API Adapter

The CLI API is served by the existing local HTTP server under `/cli/v1`. It is not an MCP protocol endpoint.

Initial routes:

```text
GET  /cli/v1/doctor
GET  /cli/v1/catalog
GET  /cli/v1/tools/search?q=<query>&limit=<n>
GET  /cli/v1/tools/<tool-name>
POST /cli/v1/tools/<tool-name>/execute
```

The adapter must reject non-loopback requests by default. Remote access requires the existing remote-access setting plus explicit CLI API permission. Existing bearer-token authentication applies when enabled.

### 8.3 Version negotiation

Every CLI API response includes:

```json
{
  "api_version": 1,
  "plugin_version": "1.0.7"
}
```

`gdmcp` sends its supported API version in `X-GDMCP-API-Version: 1`. A major version mismatch returns HTTP 409 with `API_VERSION_MISMATCH`.

## 9. CLI API Contracts

### 9.1 Doctor

`GET /cli/v1/doctor`

```json
{
  "api_version": 1,
  "plugin_version": "1.0.7",
  "godot_version": "4.6.2",
  "project_path": "F:/project",
  "editor_connected": true,
  "runtime_running": false,
  "catalog_hash": "sha256:...",
  "auth": {
    "required": false,
    "source": "localhost"
  }
}
```

Secrets are never returned.

### 9.2 Catalog

`GET /cli/v1/catalog`

The catalog contains compact summaries only:

```json
{
  "api_version": 1,
  "catalog_hash": "sha256:...",
  "tools": [
    {
      "name": "get_runtime_scene_tree",
      "summary": "Read the live runtime scene tree",
      "group": "Debug-Advanced",
      "category": "supplementary",
      "risk": "read",
      "cli_allowed": true,
      "schema_hash": "sha256:..."
    }
  ]
}
```

### 9.3 Search

`GET /cli/v1/tools/search?q=runtime%20scene%20tree&limit=5`

Search returns at most 20 entries. Default is 5. Ranking order is deterministic:

1. exact name;
2. name prefix;
3. all query tokens in name;
4. token matches in description;
5. token matches in group or category;
6. lexical name order as the tie-breaker.

### 9.4 Schema

`GET /cli/v1/tools/<tool-name>`

Returns only one complete definition, excluding the callable:

```json
{
  "api_version": 1,
  "tool": {
    "name": "update_node_property",
    "description": "Update a node property",
    "input_schema": {},
    "output_schema": {},
    "annotations": {},
    "category": "core",
    "group": "Node-Write",
    "policy": {}
  }
}
```

### 9.5 Execute

`POST /cli/v1/tools/<tool-name>/execute`

Request:

```json
{
  "arguments": {},
  "dry_run": false,
  "apply_confirmed": false,
  "allow_open_world": false,
  "request_id": "optional-client-id",
  "max_bytes": 65536
}
```

Response:

```json
{
  "api_version": 1,
  "ok": true,
  "tool": "get_scene_tree",
  "data": {},
  "warnings": [],
  "artifacts": [],
  "meta": {
    "duration_ms": 18,
    "truncated": false,
    "next_cursor": null
  }
}
```

Policy failure example:

```json
{
  "api_version": 1,
  "ok": false,
  "tool": "delete_node",
  "error": {
    "code": "APPLY_REQUIRED",
    "message": "This operation requires explicit apply confirmation",
    "retryable": true,
    "hint": "Repeat the command with --apply"
  }
}
```

## 10. Rust CLI Design

### 10.1 Runtime and libraries

The CLI is implemented in Rust and distributed as one executable.

Initial dependencies:

- `clap` for commands and generated help;
- `reqwest` for HTTP;
- `serde` and `serde_json` for stable contracts;
- `toml` for configuration;
- `thiserror` for classified errors;
- `anyhow` only at the application boundary;
- `directories` for platform configuration paths;
- `tokio` for the asynchronous runtime.

### 10.2 Configuration

Precedence, highest first:

1. explicit non-secret command-line option;
2. environment variable;
3. user configuration file;
4. built-in default.

Environment variables:

```text
GODOT_MCP_URL
GODOT_MCP_TOKEN
GODOT_MCP_TIMEOUT
```

Configuration paths:

```text
Windows: %APPDATA%\gdmcp\config.toml
Linux:   ~/.config/gdmcp/config.toml
macOS:   ~/Library/Application Support/gdmcp/config.toml
```

Tokens are read from the environment or protected configuration source. `doctor` reports only whether a token is configured and its source.

### 10.3 Global options

```text
--json
--url <URL>
--timeout <SECONDS>
--no-color
--verbose
```

JSON mode rules:

- stdout contains exactly one JSON value or JSONL records for explicitly streaming commands;
- progress and diagnostics go to stderr;
- color and spinners are disabled;
- fields are stable within API schema version 1.

### 10.4 Command taxonomy

Connection and configuration:

```text
gdmcp doctor
gdmcp init
gdmcp config show
```

Discovery and raw access:

```text
gdmcp tools search <query>
gdmcp tools schema <tool-name>
gdmcp tool-call <tool-name>
```

High-level domains:

```text
gdmcp editor state
gdmcp scenes list|resolve|current|tree|open|save
gdmcp nodes resolve|get|create|delete|move|rename
gdmcp nodes properties set
gdmcp scripts list|resolve|read|create|replace|validate
gdmcp resources list|resolve|get|create
gdmcp project info|settings|run|stop
gdmcp debug logs|clear
gdmcp runtime info|tree
gdmcp runtime nodes get|set|call
gdmcp batch preview|apply
```

High-level commands are wrappers that map typed CLI arguments to an existing registry tool and then invoke the CLI API. They do not implement editor behavior.

### 10.5 Stable CLI envelope

Success:

```json
{
  "schema_version": 1,
  "ok": true,
  "command": "scenes.tree",
  "data": {},
  "meta": {
    "server_version": "1.0.7",
    "duration_ms": 18,
    "truncated": false,
    "next_cursor": null
  }
}
```

Failure:

```json
{
  "schema_version": 1,
  "ok": false,
  "command": "nodes.properties.set",
  "error": {
    "code": "NODE_NOT_FOUND",
    "message": "Node was not found",
    "retryable": false,
    "hint": "Run gdmcp --json nodes resolve Player first"
  }
}
```

### 10.6 Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success, including an empty collection |
| 2 | Invalid CLI arguments |
| 3 | Configuration or authentication failure |
| 4 | Godot service unavailable |
| 5 | Tool execution failed |
| 6 | Explicit apply or permission required |
| 7 | Partial result or output limit reached where the command requires completeness |
| 8 | CLI/API version incompatibility |

### 10.7 File input

Complex arguments support files to avoid shell quoting problems:

```text
--args-json <JSON>
--args-file <PATH>
--value-json <JSON>
--content-file <PATH>
--out <PATH>
```

When both inline and file forms are present, the CLI returns argument error code 2.

## 11. High-level Command Mapping

The first release implements the commands that cover the most common workflows.

| CLI command | Existing tool |
|---|---|
| `editor state` | `get_editor_state` |
| `scenes list` | `list_project_scenes` |
| `scenes current` | `get_current_scene` |
| `scenes tree` | `get_scene_tree` or `get_scene_structure` according to requested fields |
| `scenes open` | `open_scene` |
| `scenes save` | `save_scene` |
| `nodes get` | `get_node_properties` |
| `nodes create` | `create_node` |
| `nodes delete` | `delete_node` |
| `nodes move` | `move_node` |
| `nodes rename` | `rename_node` |
| `nodes properties set` | `update_node_property` |
| `scripts list` | `list_project_scripts` |
| `scripts read` | `read_script` |
| `scripts create` | `create_script` |
| `scripts replace` | `modify_script` |
| `scripts validate` | `validate_script` |
| `resources list` | `list_project_resources` |
| `project info` | `get_project_info` |
| `project settings --filter <prefix>` | `get_project_settings` with `filter` |
| `project run` | `run_project` |
| `project stop` | `stop_project` |
| `debug logs` | `get_editor_logs` |
| `debug clear` | `clear_output` |
| `runtime info` | `get_runtime_info` |
| `runtime tree` | `get_runtime_scene_tree` |
| `runtime nodes get` | `inspect_runtime_node` |
| `runtime nodes set` | `update_runtime_node_property` |
| `runtime nodes call` | `call_runtime_node_method` |

Resolve commands use project lists and exact-name/path matching in the CLI. They return a stable path and do not modify state.

## 12. Batch Operations

Batch input:

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

The first release uses raw registered tool names and JSON object arguments in batch files. It does not accept high-level domain command objects such as `command`, `target`, or `property`; use a domain command directly for one high-level operation, or resolve the underlying tool first with `tools schema`.

`batch preview` validates every operation, checks tool policy, and returns the calls that would be made without invoking write handlers.

`batch apply` requires `--apply`, executes operations sequentially, and stops at the first failure by default. A later `--continue-on-error` option is not part of the first release.

When a native atomic MCP batch tool exists, the CLI may map the compatible subset to that tool. Otherwise it reports that the batch is sequential and not atomic.

## 13. Security

1. CLI API binds to loopback by default.
2. Existing bearer-token authentication is reused when enabled.
3. The CLI never logs tokens or authorization headers.
4. Destructive operations require `--apply`.
5. Open-world operations require `--allow-open-world`.
6. Raw `tool-call` cannot bypass tool policy.
7. API errors do not include arbitrary stack traces unless server debug logging is enabled.
8. Paths are validated by the existing project path validation utilities.
9. Artifact output paths are local client paths; the server returns bytes or a bounded transfer response rather than writing arbitrary client paths.
10. The CLI warns when connected to a non-loopback address.

## 14. Token and Output Controls

Defaults:

| Data type | Default bound |
|---|---:|
| Search results | 5 |
| Generic lists | 50 |
| Log entries | 50 |
| Tree depth | 4 |
| Raw response size | 65,536 bytes |
| Search maximum | 20 |

Commands return `truncated=true` and a cursor or narrowing hint when output is incomplete.

`--out` writes the complete received result to a local file and prints only metadata in JSON mode:

```json
{
  "schema_version": 1,
  "ok": true,
  "command": "debug.logs",
  "data": {
    "path": ".gdmcp/logs/errors.jsonl",
    "bytes": 18234,
    "records": 100
  }
}
```

## 15. Companion Skill

The repository includes `skills/gdmcp/SKILL.md`. Its purpose is to teach the usage pattern, not duplicate command reference documentation.

Required guidance:

- run `gdmcp --json doctor` first when connection state is unknown;
- use high-level domain commands for common work;
- use `tools search`, then `tools schema`, then `tool-call` for uncommon work;
- request narrow fields and bounds;
- use file arguments for complex JSON on Windows;
- preview destructive batches;
- do not use destructive or open-world operations without user intent.

The project `AGENTS.md` receives a short pointer to this Skill and the minimum discovery commands.

## 16. Testing Strategy

### 16.1 Godot unit tests

Add GUT coverage for:

- policy derivation;
- independent MCP and CLI permission behavior;
- registry registration, lookup, filtering, search ranking, and hash stability;
- executor success and legacy error normalization;
- apply and open-world enforcement;
- MCP adapter compatibility;
- CLI API routing, authentication, version mismatch, and response envelopes;
- result limiting.

### 16.2 Python integration tests

Extend existing HTTP integration tests to launch Godot and verify:

- `doctor` response;
- catalog/search/schema flow;
- a read execution;
- a write execution rejected without apply;
- a permitted write execution;
- MCP behavior remains unchanged;
- supplementary CLI-allowed tools can execute while remaining absent from MCP `tools/list`.

### 16.3 Rust tests

Add:

- command parser tests;
- config precedence tests;
- JSON envelope snapshots;
- error-to-exit-code mapping;
- mocked HTTP client tests;
- argument file conflict tests;
- output truncation/file writing tests;
- mapping tests for every high-level command.

### 16.4 Cross-platform smoke tests

CI builds and runs help/doctor parser smoke tests on:

- Windows x86_64;
- Linux x86_64;
- macOS arm64 where available.

Godot integration tests may remain on the repository's supported Windows runner initially.

## 17. Migration and Compatibility

Migration is incremental:

1. Add protocol-neutral models and executor behind current MCP behavior.
2. Switch MCP adapter to the shared executor without changing external responses.
3. Add CLI API endpoints.
4. Add the Rust CLI foundation and raw discovery/call workflow.
5. Add high-level domain commands.
6. Add output bounds, batch preview/apply, Skill, packaging, and documentation.
7. After usage data confirms the CLI workflow, optionally reduce the default MCP-visible core set further.

At no point does the first implementation require removal of an existing MCP tool.

## 18. Observability

Every execution records:

- caller (`mcp` or `cli`);
- request ID;
- tool name;
- duration;
- success/failure;
- error code;
- truncation state.

Arguments and results follow existing logging policy and must redact secrets. CLI requests are distinguishable from MCP requests in logs.

## 19. Documentation Layout

```text
docs/superpowers/specs/2026-07-24-gdmcp-agent-cli-design.md
docs/superpowers/plans/2026-07-24-gdmcp-agent-cli.md
docs/current/gdmcp-cli-reference.md
cli/gdmcp/README.md
skills/gdmcp/SKILL.md
```

The generated CLI `--help` is the command-line source of truth. `gdmcp-cli-reference.md` explains workflows and contracts rather than manually reproducing every help line.

## 20. Acceptance Criteria

The feature is complete when:

1. A shell-capable agent can use `gdmcp` without loading the full MCP tool catalog.
2. `gdmcp --json doctor` reports connection and version state without exposing secrets.
3. Search, one-tool schema retrieval, and raw execution work through progressive discovery.
4. The initial high-level domain command set maps to existing Godot tools.
5. Supplementary CLI-allowed tools can remain hidden from MCP while being callable through CLI.
6. Destructive and open-world policies are enforced server-side.
7. All machine-readable commands return versioned stable JSON and deterministic exit codes.
8. High-volume commands are bounded and can write full output to a file.
9. Existing MCP integration tests remain green.
10. Godot unit tests, Python integration tests, Rust tests, and CLI builds pass on supported environments.
11. The companion Skill and project guidance document the progressive discovery workflow.
12. No second hand-maintained copy of the complete tool catalog exists in Rust or documentation.
