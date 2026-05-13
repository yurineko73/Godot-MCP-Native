@tool
class_name GeneratedSceneScreenshotHelper
extends SceneTree

const RESULT_PREFIX: String = "__MCP_CAPTURE_RESULT__"
const DEFAULT_VIEWPORT_SIZE := Vector2i(256, 256)

static func capture_scene(scene_path: String, save_path: String, format: String = "png", viewport_size: Vector2i = DEFAULT_VIEWPORT_SIZE) -> Dictionary:
	var validation_error: Dictionary = _validate_capture_inputs(scene_path, save_path, format, viewport_size)
	if not validation_error.is_empty():
		return validation_error

	var executable_path: String = OS.get_executable_path()
	if executable_path.is_empty():
		return {"error": "Unable to locate the Godot executable for generated scene capture"}

	var args: Array[String] = [
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://addons/godot_mcp/utils/generated_scene_screenshot_helper.gd",
		"--",
		"--capture-scene",
		scene_path,
		save_path,
		format,
		str(viewport_size.x),
		str(viewport_size.y)
	]

	var logs: Array = []
	var exit_code: int = OS.execute(executable_path, args, logs, true)
	var result: Dictionary = _extract_capture_result(logs)
	if not result.is_empty():
		return result

	return {
		"error": "Generated scene screenshot helper did not return a capture result",
		"exit_code": exit_code,
		"logs": _sanitize_logs(logs)
	}

func _initialize() -> void:
	call_deferred("_run_cli_capture")

func _run_cli_capture() -> void:
	var result: Dictionary = await _capture_from_cli_args()
	print(RESULT_PREFIX + JSON.stringify(result))
	quit(0 if not result.has("error") else 1)

func _capture_from_cli_args() -> Dictionary:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 6 or args[0] != "--capture-scene":
		return {"error": "Expected args: --capture-scene <scene_path> <save_path> <format> <width> <height>"}

	var width: int = int(args[4])
	var height: int = int(args[5])
	return await _capture_scene_in_process(args[1], args[2], args[3], Vector2i(width, height))

func _capture_scene_in_process(scene_path: String, save_path: String, format: String, viewport_size: Vector2i) -> Dictionary:
	var validation_error: Dictionary = _validate_capture_inputs(scene_path, save_path, format, viewport_size)
	if not validation_error.is_empty():
		return validation_error

	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		return {"error": "Failed to load scene: " + scene_path}

	var scene_root: Node = packed_scene.instantiate()
	if scene_root == null:
		return {"error": "Failed to instantiate scene: " + scene_path}

	var capture_host: Node = Node.new()
	capture_host.name = "__mcp_generated_scene_capture__"

	var viewport: SubViewport = SubViewport.new()
	viewport.name = "GeneratedSceneViewport"
	viewport.size = viewport_size
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	capture_host.add_child(viewport)
	root.add_child(capture_host)

	var uses_3d: bool = _scene_uses_3d(scene_root)
	if uses_3d:
		_attach_3d_scene(viewport, scene_root)
	else:
		_attach_2d_scene(viewport, scene_root, viewport_size)

	var image: Image = await _await_viewport_image(viewport)
	if image == null or image.is_empty():
		_cleanup_capture_host(capture_host)
		return {
			"error": "Failed to capture generated scene image",
			"scene_path": scene_path,
			"viewport_size": [viewport_size.x, viewport_size.y],
			"render_mode": "3d" if uses_3d else "2d"
		}

	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var save_dir: String = absolute_path.get_base_dir()
	if not save_dir.is_empty() and not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var err: Error = OK
	if format == "jpg":
		err = image.save_jpg(absolute_path, 0.9)
	else:
		err = image.save_png(absolute_path)

	_cleanup_capture_host(capture_host)

	if err != OK:
		return {"error": "Failed to save screenshot: error " + str(err), "scene_path": scene_path}

	return {
		"status": "success",
		"scene_path": scene_path,
		"save_path": save_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"size": str(image.get_width()) + "x" + str(image.get_height()),
		"render_mode": "3d" if uses_3d else "2d"
	}

func _await_viewport_image(viewport: SubViewport) -> Image:
	var image: Image = null
	for _i in range(12):
		await process_frame
		RenderingServer.force_draw(false)
		var texture: ViewportTexture = viewport.get_texture()
		if texture:
			image = texture.get_image()
			if image and not image.is_empty():
				return image
	return image

static func _validate_capture_inputs(scene_path: String, save_path: String, format: String, viewport_size: Vector2i) -> Dictionary:
	var scene_validation: Dictionary = PathValidator.validate_file_path(scene_path, [".tscn", ".scn"])
	if not scene_validation.get("valid", false):
		return {"error": "Invalid scene path: " + str(scene_validation.get("error", "unknown error"))}

	var save_validation: Dictionary = PathValidator.validate_file_path(save_path, [".png", ".jpg", ".jpeg"])
	if not save_validation.get("valid", false):
		return {"error": "Invalid save path: " + str(save_validation.get("error", "unknown error"))}

	if format not in ["png", "jpg"]:
		return {"error": "Unsupported screenshot format: " + format}

	if viewport_size.x < 2 or viewport_size.y < 2:
		return {"error": "Viewport size must be at least 2x2"}

	return {}

static func _extract_capture_result(logs: Array) -> Dictionary:
	for entry in logs:
		var text: String = str(entry)
		for line in text.split("\n"):
			var trimmed: String = line.strip_edges()
			var marker_index: int = trimmed.find(RESULT_PREFIX)
			if marker_index >= 0:
				var payload: String = trimmed.substr(marker_index + RESULT_PREFIX.length())
				var json: JSON = JSON.new()
				if json.parse(payload) == OK and typeof(json.data) == TYPE_DICTIONARY:
					return json.data
	return {}

static func _sanitize_logs(logs: Array) -> Array[String]:
	var sanitized: Array[String] = []
	for entry in logs:
		var text: String = str(entry).strip_edges()
		if not text.is_empty():
			sanitized.append(text)
	return sanitized

static func _scene_uses_3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child in node.get_children():
		if child is Node and _scene_uses_3d(child):
			return true
	return false

static func _attach_2d_scene(viewport: SubViewport, scene_root: Node, viewport_size: Vector2i) -> void:
	viewport.disable_3d = true
	viewport.add_child(scene_root)
	if scene_root is Control:
		var control_root: Control = scene_root
		control_root.position = Vector2.ZERO
		control_root.size = Vector2(viewport_size)

static func _attach_3d_scene(viewport: SubViewport, scene_root: Node) -> void:
	viewport.disable_3d = false
	var world_root: Node3D = Node3D.new()
	world_root.name = "GeneratedScene3DRoot"
	viewport.add_child(world_root)
	world_root.add_child(scene_root)

	var camera: Camera3D = _find_first_camera(scene_root)
	if camera == null:
		camera = Camera3D.new()
		camera.name = "AutoCaptureCamera"
		camera.position = Vector3(0.0, 0.0, 3.0)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		world_root.add_child(camera)
	camera.current = true

	if _find_first_light(scene_root) == null:
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.name = "AutoCaptureLight"
		light.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
		world_root.add_child(light)

static func _find_first_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		if child is Node:
			var found: Camera3D = _find_first_camera(child)
			if found != null:
				return found
	return null

static func _find_first_light(node: Node) -> Light3D:
	if node is Light3D:
		return node
	for child in node.get_children():
		if child is Node:
			var found: Light3D = _find_first_light(child)
			if found != null:
				return found
	return null

static func _cleanup_capture_host(capture_host: Node) -> void:
	if capture_host == null or not is_instance_valid(capture_host):
		return
	if capture_host.get_parent():
		capture_host.get_parent().remove_child(capture_host)
	capture_host.queue_free()
