@tool
extends Node

const RESULT_META_PREFIX := "editor_gut_probe_result:"
const STATUS_META_PREFIX := "editor_gut_probe_status:"

var _test_path := ""
var _test_paths: Array = []
var _dirs: Array = []
var _include_subdirs := false
var _result_output_path := ""
var _run_id := ""
var status := "idle"
var result := {}

func mark(run_id: String) -> void:
	Engine.set_meta("editor_gut_probe_mark:" + run_id, "marked")

func start(run_id: String, test_path: String) -> void:
	start_suite(run_id, [], [test_path], false, "")

func start_suite(run_id: String, dirs: Array, tests: Array, include_subdirs: bool, result_output_path: String = "") -> void:
	_run_id = run_id
	_test_path = tests[0] if tests.size() > 0 else ""
	_test_paths = tests.duplicate()
	_dirs = dirs.duplicate()
	_include_subdirs = include_subdirs
	_result_output_path = result_output_path
	name = "EditorGutProbeRunner_" + _run_id
	status = "running"
	result = {}
	call_deferred("_run")

func _run() -> void:
	await _run_async()

func _run_async() -> void:
	var Gut = load("res://addons/gut/gut.gd")
	var GutConfig = load("res://addons/gut/gut_config.gd")
	var GutLogger = load("res://addons/gut/logger.gd")
	var gut = Gut.new(GutLogger.new())
	gut._should_print_versions = false
	gut._should_print_summary = false
	gut.logger.disable_all_printers(true)
	get_tree().root.add_child(gut)
	await get_tree().process_frame

	var config = GutConfig.new()
	config.options.dirs = _dirs
	config.options.tests = _test_paths
	config.options.include_subdirs = _include_subdirs
	config.options.log_level = 0
	config.options.should_exit = false
	config.options.should_exit_on_success = false
	config.options.hide_orphans = true
	config.options.junit_xml_file = ""
	config.options.no_error_tracking = false
	config.apply_options(gut)

	gut.test_scripts(true)
	await gut.end_run

	var summary := {
		"pass_count": gut.get_pass_count(),
		"fail_count": gut.get_fail_count(),
		"pending_count": gut.get_pending_count(),
		"assert_count": gut.get_assert_count(),
		"test_script_count": gut.get_test_script_count()
	}
	result = summary
	status = "complete"
	if not _result_output_path.is_empty():
		var ResultExporter = load("res://addons/gut/result_exporter.gd")
		var exporter = ResultExporter.new()
		var payload := {
			"summary": summary,
			"results": exporter.get_results_dictionary(gut)
		}
		var file := FileAccess.open(_result_output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(payload))
			file.close()
	gut.queue_free()
