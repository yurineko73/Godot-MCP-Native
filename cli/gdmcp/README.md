# gdmcp

`gdmcp` is an agent-friendly command-line client for Godot MCP Native. It uses the plugin's local `/cli/v1` API so shell-capable agents can discover and invoke tools without loading the complete MCP tool catalog into model context.

## Build

```bash
cargo build --manifest-path cli/gdmcp/Cargo.toml --release
```

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
