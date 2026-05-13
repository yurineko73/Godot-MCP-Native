@tool
extends RefCounted

const RUNNER_SCRIPT := preload("res://test/manual/editor_gut_probe_runner.gd")

static func start_probe(run_id: String, test_path: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "error": "SceneTree unavailable"}
	var node_name := "EditorGutProbeRunner_" + run_id
	var existing := tree.root.get_node_or_null(node_name)
	if existing:
		existing.queue_free()
	var runner = RUNNER_SCRIPT.new()
	tree.root.add_child(runner)
	runner.start(run_id, test_path)
	return {"ok": true, "run_id": run_id, "node_name": node_name}

static func get_probe_status(run_id: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"found": false, "error": "SceneTree unavailable"}
	var node := tree.root.get_node_or_null("EditorGutProbeRunner_" + run_id)
	if node == null:
		return {"found": false}
	return {
		"found": true,
		"status": node.status,
		"result": node.result
	}
