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
gdmcp --json nodes get /root/Main/Player
```

## Inspect a script

```bash
gdmcp --json scripts list --limit 50
gdmcp --json scripts read res://scripts/player.gd
```

## Replace a script explicitly

```bash
gdmcp --json scripts replace res://scripts/player.gd \
  --content-file ./player.gd \
  --apply
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
