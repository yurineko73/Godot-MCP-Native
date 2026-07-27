@tool
class_name MCPCliInstaller
extends RefCounted

var _http: HTTPRequest = null
var _scene_tree: SceneTree = null
var _release_config: Dictionary = {}

const CONFIG_PATH: String = "res://addons/godot_mcp/cli_release.json"

func _init() -> void:
	_load_config()

func set_scene_tree(tree: SceneTree) -> void:
	_scene_tree = tree

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("CLI release config not found: %s" % CONFIG_PATH)
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Failed to parse CLI release config")
		return
	_release_config = json.data

func cli_version() -> String:
	return str(_release_config.get("version", "0.0.0"))

static func resolve_platform_target(os_name: String, architecture: String) -> String:
	match os_name:
		"Windows":
			if architecture == "x86_64":
				return "x86_64-pc-windows-msvc"
		"Linux":
			if architecture == "arm64":
				return "aarch64-unknown-linux-gnu"
			if architecture == "x86_64":
				return "x86_64-unknown-linux-gnu"
		"macOS":
			if architecture == "arm64":
				return "aarch64-apple-darwin"
			if architecture == "x86_64":
				return "x86_64-apple-darwin"
	return ""

func platform_target() -> String:
	return resolve_platform_target(OS.get_name(), Engine.get_architecture_name())

func is_platform_supported() -> bool:
	var target: String = platform_target()
	if target.is_empty():
		return false
	var targets: Dictionary = _release_config.get("targets", {})
	return targets.has(target)

func platform_exe_name() -> String:
	var target: String = platform_target()
	if target.is_empty():
		return ""
	var targets: Dictionary = _release_config.get("targets", {})
	return str(targets.get(target, ""))

func detect_state(project_path: String) -> Dictionary:
	var install_dir: String = project_path.path_join(".gdmcp/bin")
	var exe_name: String = platform_exe_name()
	var exe_path: String = install_dir.path_join(exe_name) if not exe_name.is_empty() else ""
	var installed: bool = not exe_path.is_empty() and FileAccess.file_exists(exe_path)
	return {
		"installed": installed,
		"supported": is_platform_supported(),
		"exe_path": exe_path,
		"install_dir": install_dir,
		"version": cli_version(),
		"target": platform_target(),
	}

func download_url(source: String) -> String:
	var target: String = platform_target()
	if target.is_empty():
		return ""
	if source == "github":
		var tmpl: String = str(_release_config.get("github", {}).get("url_template", ""))
		return tmpl.replace("{version}", cli_version()).replace("{target}", target)
	var quark: Dictionary = _release_config.get("quark", {})
	return str(quark.get("direct_download", ""))

func download_page_url() -> String:
	return str(_release_config.get("quark", {}).get("page_url", ""))

func install_from(source: String, install_dir: String, on_complete: Callable) -> void:
	var target: String = platform_target()
	var exe_name: String = platform_exe_name()
	if target.is_empty() or exe_name.is_empty() or not is_platform_supported():
		on_complete.call(false, "Unsupported platform: %s / %s" % [OS.get_name(), Engine.get_architecture_name()])
		return

	var url: String = download_url(source)
	if url.is_empty():
		if source == "quark":
			OS.shell_open(download_page_url())
			on_complete.call(false, "Quark cloud drive does not support direct download. Browser opened — download manually and place %s in:\n%s" % [exe_name, install_dir])
		else:
			on_complete.call(false, "Download URL not configured for source: %s" % source)
		return

	if _scene_tree == null:
		on_complete.call(false, "SceneTree is not available for CLI download")
		return
	if _http == null:
		_http = HTTPRequest.new()
		_scene_tree.root.add_child(_http)
	elif _http.request_completed.is_connected(_on_download_completed):
		_http.request_completed.disconnect(_on_download_completed)
	_http.request_completed.connect(
		_on_download_completed.bind(on_complete, install_dir, target, exe_name),
		CONNECT_ONE_SHOT
	)
	var error: int = _http.request(url)
	if error != OK:
		on_complete.call(false, "Download request failed: error code %d" % error)

func _on_download_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	on_complete: Callable,
	install_dir: String,
	target: String,
	exe_name: String
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		on_complete.call(false, "Download failed (HTTP %d). Try the alternate download source." % response_code)
		return
	if body.is_empty():
		on_complete.call(false, "Downloaded archive is empty")
		return

	var temp_root: String = ProjectSettings.globalize_path("user://").path_join(
		"gdmcp_install_%d" % Time.get_ticks_usec()
	)
	var create_error: int = DirAccess.make_dir_recursive_absolute(temp_root)
	if create_error != OK:
		on_complete.call(false, "Cannot create temporary install directory: %s" % temp_root)
		return

	var zip_path: String = temp_root.path_join("gdmcp.zip")
	var archive_root: String = temp_root.path_join("archive")
	DirAccess.make_dir_recursive_absolute(archive_root)
	var zip_file: FileAccess = FileAccess.open(zip_path, FileAccess.WRITE)
	if zip_file == null:
		_remove_tree(temp_root)
		on_complete.call(false, "Cannot write temporary archive: %s" % zip_path)
		return
	zip_file.store_buffer(body)
	zip_file.close()

	var extract_error: String = _extract_archive(zip_path, archive_root)
	if not extract_error.is_empty():
		_remove_tree(temp_root)
		on_complete.call(false, extract_error)
		return

	var manifest_error: String = _validate_manifest(archive_root, target, exe_name)
	if not manifest_error.is_empty():
		_remove_tree(temp_root)
		on_complete.call(false, manifest_error)
		return

	var install_result: Dictionary = _run_packaged_installer(archive_root, install_dir, target)
	_remove_tree(temp_root)
	if not bool(install_result.get("success", false)):
		on_complete.call(false, str(install_result.get("message", "CLI installer failed")))
		return

	var exe_path: String = install_dir.path_join(exe_name)
	if not FileAccess.file_exists(exe_path):
		on_complete.call(false, "Installer completed but executable was not created: %s" % exe_path)
		return

	var version_output: Array = []
	var version_exit_code: int = OS.execute(exe_path, PackedStringArray(["--version"]), version_output, true)
	var version_text: String = _join_output(version_output)
	if version_exit_code != 0 or not version_text.contains(cli_version()):
		DirAccess.remove_absolute(exe_path)
		on_complete.call(false, "Installed CLI failed version verification (exit %d):\n%s" % [version_exit_code, version_text])
		return

	var installer_message: String = str(install_result.get("message", "")).strip_edges()
	var message: String = "CLI %s installed to %s" % [version_text.strip_edges(), exe_path]
	if not installer_message.is_empty():
		message += "\n" + installer_message
	on_complete.call(true, message)

func _extract_archive(zip_path: String, archive_root: String) -> String:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: int = reader.open(zip_path)
	if open_error != OK:
		return "Failed to open downloaded ZIP archive"

	for entry in reader.get_files():
		var normalized: String = entry.replace("\\", "/")
		if normalized.is_empty():
			continue
		var components: PackedStringArray = normalized.split("/", false)
		if normalized.begins_with("/") or normalized.contains(":") or components.has(".."):
			reader.close()
			return "Archive contains an unsafe path: %s" % entry
		var destination: String = archive_root.path_join(normalized)
		if normalized.ends_with("/"):
			var dir_error: int = DirAccess.make_dir_recursive_absolute(destination)
			if dir_error != OK:
				reader.close()
				return "Cannot create archive directory: %s" % destination
			continue
		var parent_error: int = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if parent_error != OK:
			reader.close()
			return "Cannot create archive directory: %s" % destination.get_base_dir()
		var extracted_file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		if extracted_file == null:
			reader.close()
			return "Cannot extract archive file: %s" % destination
		extracted_file.store_buffer(reader.read_file(entry))
		extracted_file.close()
	reader.close()
	return ""

func _validate_manifest(archive_root: String, target: String, exe_name: String) -> String:
	var manifest_path: String = archive_root.path_join("release-manifest.json")
	var checksums_path: String = archive_root.path_join("SHA256SUMS")
	var script_name: String = "install.ps1" if OS.get_name() == "Windows" else "install.sh"
	var required_paths: PackedStringArray = PackedStringArray([
		manifest_path,
		checksums_path,
		archive_root.path_join(script_name),
		archive_root.path_join(exe_name),
	])
	for required_path in required_paths:
		if not FileAccess.file_exists(required_path):
			return "Archive is missing required file: %s" % required_path.get_file()

	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		return "Cannot read release manifest"
	var manifest_text: String = manifest_file.get_as_text()
	manifest_file.close()
	var json: JSON = JSON.new()
	var parse_error: int = json.parse(manifest_text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "Release manifest is not valid JSON"
	var manifest: Dictionary = json.data
	if int(manifest.get("schema_version", 0)) != 1:
		return "Unsupported release manifest schema"
	if str(manifest.get("package", "")) != "gdmcp":
		return "Release manifest package is not gdmcp"
	if str(manifest.get("version", "")) != cli_version():
		return "Release manifest version does not match requested version"
	if str(manifest.get("target", "")) != target:
		return "Release manifest target does not match this platform"
	if str(manifest.get("executable", "")) != exe_name:
		return "Release manifest executable does not match this platform"
	return ""

func _run_packaged_installer(archive_root: String, install_dir: String, target: String) -> Dictionary:
	var output: Array = []
	var exit_code: int = -1
	var script_path: String
	if OS.get_name() == "Windows":
		script_path = archive_root.path_join("install.ps1")
		exit_code = OS.execute(
			"powershell.exe",
			PackedStringArray([
				"-NoProfile",
				"-NonInteractive",
				"-ExecutionPolicy",
				"Bypass",
				"-File",
				script_path,
				"-InstallRoot",
				install_dir,
				"-ExpectedVersion",
				cli_version(),
				"-ExpectedTarget",
				target,
			]),
			output,
			true
		)
	else:
		script_path = archive_root.path_join("install.sh")
		exit_code = OS.execute(
			"/bin/sh",
			PackedStringArray([
				script_path,
				"--install-root",
				install_dir,
				"--expected-version",
				cli_version(),
				"--expected-target",
				target,
			]),
			output,
			true
		)
	var output_text: String = _join_output(output)
	if exit_code != 0:
		return {
			"success": false,
			"message": "Packaged installer failed (exit %d):\n%s" % [exit_code, output_text],
		}
	return {"success": true, "message": output_text}

func _join_output(output: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for item in output:
		var text: String = str(item).strip_edges()
		if not text.is_empty():
			lines.append(text)
	return "\n".join(lines)

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in dir.get_directories():
		_remove_tree(path.path_join(directory_name))
	DirAccess.remove_absolute(path)
