@tool
class_name MCPCliInstaller
extends RefCounted

const CLI_VERSION: String = "0.1.0"
const GITHUB_RELEASE_BASE: String = "https://github.com/yurineko73/Godot-MCP-Native/releases/download"
const QUARK_PAGE_URL: String = "https://pan.quark.cn/s/your-share-id"
const QUARK_DIRECT_DOWNLOAD: String = ""  # Quark rarely supports direct download; fall back to browser

var _http: HTTPRequest = null
var _scene_tree: SceneTree = null
var _status_changed: Callable = Callable()
var _current_state: Dictionary = {}

signal download_finished(success: bool, message: String)
signal install_finished(success: bool, message: String)

func _init() -> void:
	pass

func set_scene_tree(tree: SceneTree) -> void:
	_scene_tree = tree

func detect_state(project_path: String) -> Dictionary:
	var install_dir: String = project_path.path_join(".gdmcp/bin")
	var exe_name: String = "gdmcp.exe" if OS.get_name() == "Windows" else "gdmcp"
	var exe_path: String = install_dir.path_join(exe_name)
	var installed: bool = FileAccess.file_exists(exe_path)
	_current_state = {
		"installed": installed,
		"exe_path": exe_path,
		"install_dir": install_dir,
		"version": CLI_VERSION,
	}
	return _current_state

func platform_target() -> String:
	match OS.get_name():
		"Windows":
			return "x86_64-pc-windows-msvc"
		"macOS":
			var arch: String = OS.get_processor_name().to_lower()
			if "arm" in arch:
				return "aarch64-apple-darwin"
			return "x86_64-apple-darwin"
		_:
			return "x86_64-unknown-linux-gnu"

func platform_exe_name() -> String:
	return "gdmcp.exe" if OS.get_name() == "Windows" else "gdmcp"

func github_download_url() -> String:
	var target: String = platform_target()
	return "%s/v%s/gdmcp-%s.zip" % [GITHUB_RELEASE_BASE, CLI_VERSION, target]

func quark_download_url() -> String:
	return QUARK_DIRECT_DOWNLOAD

func install_from(source: String, install_dir: String, on_complete: Callable) -> void:
	var url: String = github_download_url() if source == "github" else quark_download_url()
	if url.is_empty():
		# Quark can't direct-download; open browser
		OS.shell_open(QUARK_PAGE_URL)
		on_complete.call(false, "Quark cloud drive does not support direct download. Browser opened — download manually and place %s in:\n%s" % [platform_exe_name(), install_dir])
		return

	if _http == null:
		_http = HTTPRequest.new()
		_scene_tree.root.add_child(_http)
	else:
		# Disconnect previous callback to avoid accumulation
		if _http.request_completed.is_connected(_on_download_completed):
			_http.request_completed.disconnect(_on_download_completed)
	_http.request_completed.connect(_on_download_completed.bind(on_complete, install_dir), CONNECT_ONE_SHOT)
	var error: int = _http.request(url)
	if error != OK:
		on_complete.call(false, "Download request failed: error code %d" % error)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, on_complete: Callable, install_dir: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		on_complete.call(false, "Download failed (HTTP %d). Try the alternate download source." % response_code)
		return

	# Save zip to temp file, then extract with ZIPReader
	var tmp_zip: String = install_dir.path_join("_gdmcp_download.zip")
	DirAccess.make_dir_recursive_absolute(install_dir)
	var tmp_file: FileAccess = FileAccess.open(tmp_zip, FileAccess.WRITE)
	if tmp_file == null:
		on_complete.call(false, "Cannot write temp file to %s" % tmp_zip)
		return
	tmp_file.store_buffer(body)
	tmp_file.close()

	var zip_reader: ZIPReader = ZIPReader.new()
	var err: int = zip_reader.open(tmp_zip)
	if err != OK:
		DirAccess.remove_absolute(tmp_zip)
		on_complete.call(false, "Failed to open downloaded archive")
		return

	var exe_name: String = platform_exe_name()
	var exe_data: PackedByteArray = zip_reader.read_file(exe_name)
	zip_reader.close()
	DirAccess.remove_absolute(tmp_zip)

	if exe_data.is_empty():
		on_complete.call(false, "Archive does not contain %s" % exe_name)
		return

	DirAccess.make_dir_recursive_absolute(install_dir)
	var exe_path: String = install_dir.path_join(exe_name)
	var file: FileAccess = FileAccess.open(exe_path, FileAccess.WRITE)
	if file == null:
		on_complete.call(false, "Cannot write to %s" % exe_path)
		return
	file.store_buffer(exe_data)
	file.close()

	# Make executable on Unix
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["+x", exe_path])

	on_complete.call(true, "CLI installed to %s" % exe_path)

func install_skill(on_complete: Callable) -> void:
	var skills_dir: String = OS.get_environment("USERPROFILE")
	if skills_dir.is_empty():
		skills_dir = OS.get_environment("HOME")
	skills_dir = skills_dir.path_join(".codex/skills/gdmcp")

	DirAccess.make_dir_recursive_absolute(skills_dir)
	DirAccess.make_dir_recursive_absolute(skills_dir.path_join("references"))

	var skill_content: String = _get_skill_md()
	var workflows_content: String = _get_command_workflows_md()

	var skill_file: FileAccess = FileAccess.open(skills_dir.path_join("SKILL.md"), FileAccess.WRITE)
	if skill_file == null:
		on_complete.call(false, "Cannot write skill to %s" % skills_dir)
		return
	skill_file.store_string(skill_content)
	skill_file.close()

	var ref_file: FileAccess = FileAccess.open(skills_dir.path_join("references/command-workflows.md"), FileAccess.WRITE)
	if ref_file == null:
		on_complete.call(false, "Cannot write reference to %s" % skills_dir)
		return
	ref_file.store_string(workflows_content)
	ref_file.close()

	on_complete.call(true, "Skill installed to %s" % skills_dir)

func get_agents_snippet() -> String:
	return """## gdmcp CLI Skill
When using the shell-oriented `gdmcp` companion for Godot editor operations,
read `skills/gdmcp/SKILL.md` first. Use the high-level bounded commands before
progressive discovery with `tools search`, `tools schema`, and `tool-call`."""

func get_skill_dir() -> String:
	var base: String = OS.get_environment("USERPROFILE")
	if base.is_empty():
		base = OS.get_environment("HOME")
	return base.path_join(".codex/skills/gdmcp")

func _get_skill_md() -> String:
	return """---
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
gdmcp --json nodes get /root/Main/Player --fields position,visible
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
gdmcp --json scripts list --limit 20
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json scripts create res://new_script.gd --script-type GDScript
gdmcp --json resources list --limit 20
gdmcp --json resources get res://player.tres --fields resource_path
gdmcp --json project settings --filter display/
gdmcp --json debug logs --limit 50
gdmcp --json runtime tree --depth 4
gdmcp --json runtime nodes get /root/Main/Player
```

Resolve names to stable paths (no tool-call needed):

```bash
gdmcp --json nodes resolve Player
gdmcp --json scenes resolve Main
gdmcp --json scripts resolve player
gdmcp --json resources resolve icon
```

Refactor nodes:

```bash
gdmcp --json nodes move /root/Main/Player --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy1 --new-name Boss
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
- Bound output with `--limit`, `--depth`, `--fields`, `--lines`, `--max-bytes`, or `--out`.
- Use `scripts list --limit <n> [--cursor <cursor>]` for progressive script discovery.
- Use `scripts read --lines <start>:<end>` to read specific line ranges.
- Use `nodes get --fields <field1,field2>` and `resources get --fields <field1,field2>` to retrieve only specific properties.
- Use `{scenes,nodes,scripts,resources} resolve <name>` to convert human-readable names to stable paths.
- `scenes list`, `nodes list`, `scripts list`, `resources list`, and `debug logs` default to 50 items.
- Use `debug logs --cursor <offset>` to continue log pages.
- Always pass `project settings --filter <prefix>`.
- Use `batch preview` before `batch apply`.
- Batch files use registered tool names and object arguments. Validation completes before any request is sent; execution is sequential and non-atomic.
- Destructive domain commands require `--apply`.
- Raw destructive calls require `--apply` after reviewing the schema.
- Runtime and open-world tools require `--allow-open-world`.
- Configure tokens via `GODOT_MCP_TOKEN` environment variable; never print them.

See `references/command-workflows.md` for copyable task flows.
"""

func _get_command_workflows_md() -> String:
	return """# gdmcp Command Workflows

## Diagnose editor state

```bash
gdmcp --json doctor
gdmcp --json editor state
gdmcp --json scenes current
gdmcp --json debug logs --level Error --limit 50
```

## Resolve names to paths

```bash
gdmcp --json nodes resolve Player
gdmcp --json scenes resolve Main
gdmcp --json scripts resolve player
gdmcp --json resources resolve icon
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

## Create a script

```bash
gdmcp --json scripts create res://scripts/enemy.gd --script-type GDScript
```

## Inspect a resource

```bash
gdmcp --json resources get res://player.tres
gdmcp --json resources get res://player.tres --fields resource_path,resource_name
```

## Modify a node property

```bash
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
```

## Move or rename a node

```bash
gdmcp --json nodes move /root/Main/Enemy --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy --new-name Boss
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
"""