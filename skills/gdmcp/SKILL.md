---
name: gdmcp
description: Use the installed gdmcp CLI to inspect, edit, run, and debug a Godot project without loading the complete Godot MCP tool catalog.
---

# gdmcp

Use `gdmcp` from the shell for operations that require the running Godot editor.

Start with:

```bash
gdmcp --json doctor
gdmcp --json editor state
```

Prefer narrow domain commands for common operations:

```bash
gdmcp --json scenes current
gdmcp --json scenes list --limit 20
gdmcp --json scenes tree --depth 4
gdmcp --json nodes list --limit 20
gdmcp --json scripts list --limit 20
gdmcp --json scripts read res://player.gd
gdmcp --json resources list --limit 20
gdmcp --json project settings --filter display/
gdmcp --json debug logs --limit 50
gdmcp --json runtime tree --depth 4
```

When a domain command is unavailable, use progressive discovery:

```bash
gdmcp --json tools search "<intent>" --limit 5
gdmcp --json tools schema <tool-name>
gdmcp --json tool-call <tool-name> --args-file <request.json>
```

Rules:

- Use `--json` when the output will be analyzed programmatically.
- Prefer domain commands over raw `tool-call`.
- Do not request the complete catalog with full schemas.
- Bound output with `--limit`, `--depth`, `--fields`, `--max-bytes`, or `--out`.
- Use `scripts list --limit <n> [--cursor <cursor>]` for progressive script discovery.
- Bound `scenes list`, `nodes list`, and `resources list` with `--limit`; use `--cursor` when continuing a result set.
- `scenes list`, `nodes list`, `scripts list`, `resources list`, and `debug logs` default to 50 items; use a positive `--limit` and never pass zero.
- Use `debug logs --cursor <offset>` to continue log pages; add `--out <file>` when the received result is large.
- Always pass `project settings --filter <prefix>`; the unfiltered settings set can be too large.
- Use `batch preview` before `batch apply`.
- Batch validation completes before any request is sent; execution is sequential and non-atomic, so a later failure does not roll back earlier operations.
- Batch files use registered tool names and object arguments, for example:

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
- Destructive domain commands require `--apply`.
- Raw destructive calls require `--apply` after reviewing the selected tool schema.
- Runtime and other open-world raw calls require `--allow-open-world`.
- Never print or request the bearer token. Configure it through `GODOT_MCP_TOKEN` or another environment variable selected with `--token-env`.
- Use only output options shown by a command's `--help`; not every command supports every generic output option.

See `references/command-workflows.md` for copyable task flows.
