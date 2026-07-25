# gdmcp Command Workflows

## Diagnose editor state

```bash
gdmcp --json doctor
gdmcp --json editor state
gdmcp --json scenes current
gdmcp --json debug logs --level Error --limit 50
```

## Inspect a scene

```bash
gdmcp --json scenes tree --depth 4
gdmcp --json nodes get /root/Main/Player --fields position,visible
```

## Inspect a script

```bash
gdmcp --json scripts list --limit 50
gdmcp --json scripts read res://scripts/player.gd --lines 1:200
```

## Modify a node property

```bash
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
```

## Replace a script explicitly

```bash
gdmcp --json scripts replace res://scripts/player.gd \
  --content-file ./player.gd \
  --apply
```

## Inspect a running game

```bash
gdmcp --json runtime info
gdmcp --json runtime tree --depth 4
gdmcp --json runtime nodes get /root/Main/Player
```

## Inspect logs progressively

```bash
gdmcp --json debug logs --limit 50
gdmcp --json debug logs --limit 50 --cursor 50
gdmcp --json debug logs --limit 100 --out ./logs.json
```

## Discover an advanced runtime tool

```bash
gdmcp --json tools search "runtime shader parameter" --limit 5
gdmcp --json tools schema set_runtime_shader_parameter
gdmcp --json tool-call set_runtime_shader_parameter \
  --args-file ./shader-request.json \
  --allow-open-world
```

## Preview and apply a batch

```bash
gdmcp --json batch preview ./operations.json
gdmcp --json batch apply ./operations.json --apply
```

Batch operations use registered tool names with JSON object arguments. They are
validated before the first request, then executed sequentially and are not
atomic; a later failure does not roll back earlier operations.

## Commands not yet available as domain commands

Use `tool-call` with the appropriate underlying tool for these operations:

- Resource resolution / retrieval / creation → `list_project_resources`, etc.
- Script creation → `create_script`
- Node move / rename → `move_node`, `rename_node`
- Scene / node / script resolution → list then match by exact path
- Runtime node property modification or method calls → use `tool-call` with
  `update_runtime_node_property` or `call_runtime_node_method` and
  `--allow-open-world`