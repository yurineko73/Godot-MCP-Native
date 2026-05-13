import json
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"
TEMP_DIR = REPO_ROOT / ".tmp_editor_play_state"
TEMP_SCENE_PATH = "res://.tmp_editor_play_state/temp_play_state_scene.tscn"


def rpc_call(method: str, params: dict | None = None, request_id: int = 1) -> dict:
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or {},
        "id": request_id,
    }
    request = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def tool_call(name: str, arguments: dict | None = None, request_id: int = 100) -> dict:
    response = rpc_call(
        "tools/call",
        {"name": name, "arguments": arguments or {}},
        request_id=request_id,
    )
    result = response["result"]
    if result.get("isError"):
        raise AssertionError(f"Tool {name} failed: {result['content'][0]['text']}")
    if "structuredContent" in result:
        return result["structuredContent"]
    return json.loads(result["content"][0]["text"])


def resource_list(request_id: int = 200) -> list[dict]:
    response = rpc_call("resources/list", request_id=request_id)
    return response["result"]["resources"]


def resource_read(uri: str, request_id: int = 201) -> dict:
    response = rpc_call("resources/read", {"uri": uri}, request_id=request_id)
    contents = response["result"]["contents"]
    if len(contents) != 1:
        raise AssertionError(f"Expected one content item for {uri}: {contents}")
    return json.loads(contents[0]["text"])


def wait_for_server(timeout_seconds: float = 30.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            rpc_call("tools/list")
            return
        except Exception:
            time.sleep(0.5)
    raise TimeoutError("Timed out waiting for MCP server on port 9080")


def execute_editor_script(code: str, request_id: int) -> dict:
    return tool_call("execute_editor_script", {"code": code}, request_id=request_id)


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    args = [
        str(GODOT_EXE),
        "--editor",
        "--headless",
        "--path",
        str(REPO_ROOT),
        "--",
        "--mcp-server",
    ]
    process = subprocess.Popen(
        args,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=REPO_ROOT,
    )

    try:
        wait_for_server()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "get_editor_paths",
            "get_editor_shell_state",
            "get_editor_language",
            "get_editor_play_state",
            "get_editor_3d_snap_state",
            "get_editor_subsystem_availability",
            "get_editor_previewer_availability",
            "get_editor_undo_redo_availability",
            "get_editor_viewport_availability",
            "get_editor_base_control_availability",
            "get_editor_file_system_dock_availability",
            "get_editor_inspector_availability",
            "get_editor_current_location",
            "get_editor_selected_paths_summary",
            "get_editor_selection_availability",
            "get_editor_command_palette_availability",
            "get_editor_toaster_availability",
            "get_editor_resource_filesystem_availability",
            "get_editor_script_editor_availability",
            "get_editor_open_script_summary",
            "get_editor_open_scene_summary",
            "get_editor_open_scenes_summary",
            "get_editor_open_scene_roots_summary",
            "get_editor_settings_availability",
            "get_editor_theme_availability",
            "get_editor_current_feature_profile",
            "get_editor_plugin_enabled_state",
            "get_editor_current_scene_dirty_state",
            "create_scene",
            "run_project",
            "stop_project",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected editor paths tools: {missing_tools}")

        tool_snapshot = tool_call("get_editor_paths", {}, request_id=2)
        direct_snapshot = execute_editor_script(
            """
var editor_paths = EditorInterface.get_editor_paths()
var data_dir = editor_paths.get_data_dir()
_custom_print(JSON.stringify({
	"config_dir": editor_paths.get_config_dir(),
	"data_dir": data_dir,
	"cache_dir": editor_paths.get_cache_dir(),
	"project_settings_dir": editor_paths.get_project_settings_dir(),
	"export_templates_dir": data_dir.path_join("export_templates"),
	"self_contained": editor_paths.is_self_contained(),
	"self_contained_file": editor_paths.get_self_contained_file()
}))
""",
            request_id=3,
        )
        if direct_snapshot.get("success") is not True or not direct_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor paths snapshot: {direct_snapshot}")

        direct_payload = json.loads(direct_snapshot["output"][-1])
        for key in (
            "config_dir",
            "data_dir",
            "cache_dir",
            "project_settings_dir",
            "export_templates_dir",
            "self_contained",
            "self_contained_file",
        ):
            if tool_snapshot.get(key) != direct_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorPaths truth: {tool_snapshot} vs {direct_payload}"
                )

        resources = resource_list(request_id=1001)
        resource_uris = {resource["uri"] for resource in resources}
        if "godot://editor/paths" not in resource_uris:
            raise AssertionError(f"Missing godot://editor/paths in resources/list: {sorted(resource_uris)}")

        resource_snapshot = resource_read("godot://editor/paths", request_id=1002)
        for key in (
            "config_dir",
            "data_dir",
            "cache_dir",
            "project_settings_dir",
            "export_templates_dir",
            "self_contained",
            "self_contained_file",
        ):
            if resource_snapshot.get(key) != tool_snapshot.get(key):
                raise AssertionError(
                    f"Resource {key} drifted from tool truth: {resource_snapshot} vs {tool_snapshot}"
                )
        if not isinstance(resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in editor paths resource snapshot: {resource_snapshot}")

        shell_snapshot = tool_call("get_editor_shell_state", {}, request_id=4)
        direct_shell_snapshot = execute_editor_script(
            """
var main_screen = EditorInterface.get_editor_main_screen()
_custom_print(JSON.stringify({
	"main_screen_name": str(main_screen.name),
	"main_screen_type": str(main_screen.get_class()),
	"editor_scale": EditorInterface.get_editor_scale(),
	"multi_window_enabled": EditorInterface.is_multi_window_enabled()
}))
""",
            request_id=5,
        )
        if direct_shell_snapshot.get("success") is not True or not direct_shell_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor shell snapshot: {direct_shell_snapshot}")

        direct_shell_payload = json.loads(direct_shell_snapshot["output"][-1])
        for key in (
            "main_screen_name",
            "main_screen_type",
            "editor_scale",
            "multi_window_enabled",
        ):
            if shell_snapshot.get(key) != direct_shell_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface shell truth: {shell_snapshot} vs {direct_shell_payload}"
                )

        if "godot://editor/shell_state" not in resource_uris:
            raise AssertionError(f"Missing godot://editor/shell_state in resources/list: {sorted(resource_uris)}")

        shell_resource_snapshot = resource_read("godot://editor/shell_state", request_id=1003)
        for key in (
            "main_screen_name",
            "main_screen_type",
            "editor_scale",
            "multi_window_enabled",
        ):
            if shell_resource_snapshot.get(key) != shell_snapshot.get(key):
                raise AssertionError(
                    f"Shell resource {key} drifted from tool truth: {shell_resource_snapshot} vs {shell_snapshot}"
                )
        if not isinstance(shell_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in editor shell resource snapshot: {shell_resource_snapshot}")

        language_snapshot = tool_call("get_editor_language", {}, request_id=6)
        direct_language_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"editor_language": str(EditorInterface.get_editor_language())
}))
""",
            request_id=7,
        )
        if direct_language_snapshot.get("success") is not True or not direct_language_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor language snapshot: {direct_language_snapshot}")

        direct_language_payload = json.loads(direct_language_snapshot["output"][-1])
        if language_snapshot.get("editor_language") != direct_language_payload.get("editor_language"):
            raise AssertionError(
                f"Tool editor_language drifted from live EditorInterface truth: {language_snapshot} vs {direct_language_payload}"
            )

        if "godot://editor/language" not in resource_uris:
            raise AssertionError(f"Missing godot://editor/language in resources/list: {sorted(resource_uris)}")

        language_resource_snapshot = resource_read("godot://editor/language", request_id=1004)
        if language_resource_snapshot.get("editor_language") != language_snapshot.get("editor_language"):
            raise AssertionError(
                f"Language resource drifted from tool truth: {language_resource_snapshot} vs {language_snapshot}"
            )
        if not isinstance(language_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in editor language resource snapshot: {language_resource_snapshot}")

        current_location = tool_call("get_editor_current_location", {}, request_id=31)
        direct_location_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"current_path": str(EditorInterface.get_current_path()),
	"current_directory": str(EditorInterface.get_current_directory())
}))
""",
            request_id=32,
        )
        if direct_location_snapshot.get("success") is not True or not direct_location_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor current-location snapshot: {direct_location_snapshot}")

        direct_location_payload = json.loads(direct_location_snapshot["output"][-1])
        for key in ("current_path", "current_directory"):
            if current_location.get(key) != direct_location_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface current-location truth: {current_location} vs {direct_location_payload}"
                )

        if "godot://editor/current_location" not in resource_uris:
            raise AssertionError(f"Missing godot://editor/current_location in resources/list: {sorted(resource_uris)}")

        location_resource_snapshot = resource_read("godot://editor/current_location", request_id=1005)
        for key in ("current_path", "current_directory"):
            if location_resource_snapshot.get(key) != current_location.get(key):
                raise AssertionError(
                    f"Current-location resource {key} drifted from tool truth: {location_resource_snapshot} vs {current_location}"
                )
        if not isinstance(location_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in editor current-location resource snapshot: {location_resource_snapshot}")

        if "godot://editor/current_feature_profile" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/current_feature_profile in resources/list: {sorted(resource_uris)}"
            )

        current_feature_profile_resource_snapshot = resource_read(
            "godot://editor/current_feature_profile",
            request_id=1006,
        )

        if "godot://editor/selected_paths" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/selected_paths in resources/list: {sorted(resource_uris)}"
            )

        selected_paths_resource_snapshot = resource_read(
            "godot://editor/selected_paths",
            request_id=1007,
        )

        if "godot://editor/play_state" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/play_state in resources/list: {sorted(resource_uris)}"
            )

        idle_play_state_resource_snapshot = resource_read(
            "godot://editor/play_state",
            request_id=1008,
        )

        if "godot://editor/3d_snap_state" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/3d_snap_state in resources/list: {sorted(resource_uris)}"
            )

        snap_state_resource_snapshot = resource_read(
            "godot://editor/3d_snap_state",
            request_id=1009,
        )

        if "godot://editor/subsystem_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/subsystem_availability in resources/list: {sorted(resource_uris)}"
            )

        subsystem_resource_snapshot = resource_read(
            "godot://editor/subsystem_availability",
            request_id=1010,
        )

        if "godot://editor/previewer_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/previewer_availability in resources/list: {sorted(resource_uris)}"
            )

        previewer_resource_snapshot = resource_read(
            "godot://editor/previewer_availability",
            request_id=1011,
        )

        if "godot://editor/undo_redo_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/undo_redo_availability in resources/list: {sorted(resource_uris)}"
            )

        undo_redo_resource_snapshot = resource_read(
            "godot://editor/undo_redo_availability",
            request_id=1012,
        )

        if "godot://editor/base_control_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/base_control_availability in resources/list: {sorted(resource_uris)}"
            )

        base_control_resource_snapshot = resource_read(
            "godot://editor/base_control_availability",
            request_id=1013,
        )

        if "godot://editor/file_system_dock_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/file_system_dock_availability in resources/list: {sorted(resource_uris)}"
            )

        file_system_dock_resource_snapshot = resource_read(
            "godot://editor/file_system_dock_availability",
            request_id=1022,
        )

        if "godot://editor/inspector_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/inspector_availability in resources/list: {sorted(resource_uris)}"
            )

        inspector_resource_snapshot = resource_read(
            "godot://editor/inspector_availability",
            request_id=1023,
        )

        if "godot://editor/viewport_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/viewport_availability in resources/list: {sorted(resource_uris)}"
            )

        viewport_resource_snapshot = resource_read(
            "godot://editor/viewport_availability",
            request_id=1024,
        )

        if "godot://editor/selection_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/selection_availability in resources/list: {sorted(resource_uris)}"
            )

        selection_resource_snapshot = resource_read(
            "godot://editor/selection_availability",
            request_id=1014,
        )

        if "godot://editor/command_palette_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/command_palette_availability in resources/list: {sorted(resource_uris)}"
            )

        command_palette_resource_snapshot = resource_read(
            "godot://editor/command_palette_availability",
            request_id=1015,
        )

        if "godot://editor/toaster_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/toaster_availability in resources/list: {sorted(resource_uris)}"
            )

        toaster_resource_snapshot = resource_read(
            "godot://editor/toaster_availability",
            request_id=1016,
        )

        if "godot://editor/resource_filesystem_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/resource_filesystem_availability in resources/list: {sorted(resource_uris)}"
            )

        resource_filesystem_resource_snapshot = resource_read(
            "godot://editor/resource_filesystem_availability",
            request_id=1017,
        )

        if "godot://editor/script_editor_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/script_editor_availability in resources/list: {sorted(resource_uris)}"
            )

        script_editor_resource_snapshot = resource_read(
            "godot://editor/script_editor_availability",
            request_id=1018,
        )

        if "godot://editor/settings_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/settings_availability in resources/list: {sorted(resource_uris)}"
            )

        editor_settings_resource_snapshot = resource_read(
            "godot://editor/settings_availability",
            request_id=1019,
        )

        if "godot://editor/theme_availability" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/theme_availability in resources/list: {sorted(resource_uris)}"
            )

        editor_theme_resource_snapshot = resource_read(
            "godot://editor/theme_availability",
            request_id=1020,
        )

        if "godot://editor/current_scene_dirty_state" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/current_scene_dirty_state in resources/list: {sorted(resource_uris)}"
            )

        current_scene_dirty_resource_snapshot = resource_read(
            "godot://editor/current_scene_dirty_state",
            request_id=1021,
        )

        if "godot://editor/open_scene_summary" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/open_scene_summary in resources/list: {sorted(resource_uris)}"
            )

        open_scene_resource_snapshot = resource_read(
            "godot://editor/open_scene_summary",
            request_id=1022,
        )

        if "godot://editor/open_scenes_summary" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/open_scenes_summary in resources/list: {sorted(resource_uris)}"
            )

        open_scenes_resource_snapshot = resource_read(
            "godot://editor/open_scenes_summary",
            request_id=1023,
        )

        if "godot://editor/open_scene_roots_summary" not in resource_uris:
            raise AssertionError(
                f"Missing godot://editor/open_scene_roots_summary in resources/list: {sorted(resource_uris)}"
            )

        open_scene_roots_resource_snapshot = resource_read(
            "godot://editor/open_scene_roots_summary",
            request_id=1024,
        )

        idle_play_state = tool_call("get_editor_play_state", {}, request_id=8)
        if idle_play_state.get("is_playing_scene") is not False or idle_play_state.get("playing_scene") != "":
            raise AssertionError(f"Expected idle editor play state before run_project: {idle_play_state}")
        for key in ("is_playing_scene", "playing_scene"):
            if idle_play_state_resource_snapshot.get(key) != idle_play_state.get(key):
                raise AssertionError(
                    f"Idle play-state resource {key} drifted from tool truth: "
                    f"{idle_play_state_resource_snapshot} vs {idle_play_state}"
                )

        create_temp_scene = tool_call(
            "create_scene",
            {"scene_path": TEMP_SCENE_PATH, "root_node_type": "Node"},
            request_id=9,
        )
        if create_temp_scene.get("status") != "success":
            raise AssertionError(f"create_scene failed: {create_temp_scene}")

        run_result = tool_call(
            "run_project",
            {"scene_path": TEMP_SCENE_PATH, "allow_window": True},
            request_id=10,
        )
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")

        time.sleep(1.0)

        playing_state = tool_call("get_editor_play_state", {}, request_id=11)
        playing_state_resource_snapshot = resource_read(
            "godot://editor/play_state",
            request_id=1009,
        )
        direct_play_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"is_playing_scene": EditorInterface.is_playing_scene(),
	"playing_scene": str(EditorInterface.get_playing_scene())
}))
""",
            request_id=12,
        )
        if direct_play_snapshot.get("success") is not True or not direct_play_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor play snapshot: {direct_play_snapshot}")

        direct_play_payload = json.loads(direct_play_snapshot["output"][-1])
        for key in ("is_playing_scene", "playing_scene"):
            if playing_state.get(key) != direct_play_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface play truth: {playing_state} vs {direct_play_payload}"
                )
            if playing_state_resource_snapshot.get(key) != playing_state.get(key):
                raise AssertionError(
                    f"Playing-state resource {key} drifted from tool truth: "
                    f"{playing_state_resource_snapshot} vs {playing_state}"
                )
        if playing_state.get("is_playing_scene") is not True:
            raise AssertionError(f"Expected playing scene state after run_project: {playing_state}")

        stop_result = tool_call("stop_project", {"allow_window": True}, request_id=13)
        if stop_result.get("status") != "success":
            raise AssertionError(f"stop_project failed: {stop_result}")

        time.sleep(0.5)

        stopped_state = tool_call("get_editor_play_state", {}, request_id=14)
        if stopped_state.get("is_playing_scene") is not False or stopped_state.get("playing_scene") != "":
            raise AssertionError(f"Expected idle editor play state after stop_project: {stopped_state}")
        stopped_state_resource_snapshot = resource_read(
            "godot://editor/play_state",
            request_id=1010,
        )
        for key in ("is_playing_scene", "playing_scene"):
            if stopped_state_resource_snapshot.get(key) != stopped_state.get(key):
                raise AssertionError(
                    f"Stopped play-state resource {key} drifted from tool truth: "
                    f"{stopped_state_resource_snapshot} vs {stopped_state}"
                )

        snap_state = tool_call("get_editor_3d_snap_state", {}, request_id=15)
        direct_snap_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"snap_enabled": EditorInterface.is_node_3d_snap_enabled(),
	"translate_snap": EditorInterface.get_node_3d_translate_snap(),
	"rotate_snap": EditorInterface.get_node_3d_rotate_snap(),
	"scale_snap": EditorInterface.get_node_3d_scale_snap()
}))
""",
            request_id=16,
        )
        if direct_snap_snapshot.get("success") is not True or not direct_snap_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor 3d snap snapshot: {direct_snap_snapshot}")

        direct_snap_payload = json.loads(direct_snap_snapshot["output"][-1])
        for key in ("snap_enabled", "translate_snap", "rotate_snap", "scale_snap"):
            if snap_state.get(key) != direct_snap_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface 3D snap truth: {snap_state} vs {direct_snap_payload}"
                )
            if snap_state_resource_snapshot.get(key) != snap_state.get(key):
                raise AssertionError(
                    f"3D-snap resource {key} drifted from tool truth: {snap_state_resource_snapshot} vs {snap_state}"
                )
        if not isinstance(snap_state_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor 3D snap resource snapshot: {snap_state_resource_snapshot}"
            )

        subsystem_state = tool_call("get_editor_subsystem_availability", {}, request_id=17)
        direct_subsystem_snapshot = execute_editor_script(
            """
var command_palette = EditorInterface.get_command_palette()
var toaster = EditorInterface.get_editor_toaster()
var resource_filesystem = EditorInterface.get_resource_filesystem()
var script_editor = EditorInterface.get_script_editor()
_custom_print(JSON.stringify({
	"command_palette_available": command_palette != null,
	"command_palette_type": command_palette.get_class() if command_palette else "",
	"toaster_available": toaster != null,
	"toaster_type": toaster.get_class() if toaster else "",
	"resource_filesystem_available": resource_filesystem != null,
	"resource_filesystem_type": resource_filesystem.get_class() if resource_filesystem else "",
	"script_editor_available": script_editor != null,
	"script_editor_type": script_editor.get_class() if script_editor else ""
}))
""",
            request_id=18,
        )
        if direct_subsystem_snapshot.get("success") is not True or not direct_subsystem_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor subsystem snapshot: {direct_subsystem_snapshot}")

        direct_subsystem_payload = json.loads(direct_subsystem_snapshot["output"][-1])
        for key in (
            "command_palette_available",
            "command_palette_type",
            "toaster_available",
            "toaster_type",
            "resource_filesystem_available",
            "resource_filesystem_type",
            "script_editor_available",
            "script_editor_type",
        ):
            if subsystem_state.get(key) != direct_subsystem_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface subsystem truth: {subsystem_state} vs {direct_subsystem_payload}"
                )
            if subsystem_resource_snapshot.get(key) != subsystem_state.get(key):
                raise AssertionError(
                    f"Subsystem resource {key} drifted from tool truth: {subsystem_resource_snapshot} vs {subsystem_state}"
                )
        if not isinstance(subsystem_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor subsystem resource snapshot: {subsystem_resource_snapshot}"
            )

        previewer_state = tool_call("get_editor_previewer_availability", {}, request_id=19)
        direct_previewer_snapshot = execute_editor_script(
            """
var resource_previewer = EditorInterface.get_resource_previewer()
_custom_print(JSON.stringify({
	"resource_previewer_available": resource_previewer != null,
	"resource_previewer_type": resource_previewer.get_class() if resource_previewer else ""
}))
""",
            request_id=20,
        )
        if direct_previewer_snapshot.get("success") is not True or not direct_previewer_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor previewer snapshot: {direct_previewer_snapshot}")

        direct_previewer_payload = json.loads(direct_previewer_snapshot["output"][-1])
        for key in ("resource_previewer_available", "resource_previewer_type"):
            if previewer_state.get(key) != direct_previewer_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface previewer truth: {previewer_state} vs {direct_previewer_payload}"
                )
            if previewer_resource_snapshot.get(key) != previewer_state.get(key):
                raise AssertionError(
                    f"Previewer resource {key} drifted from tool truth: {previewer_resource_snapshot} vs {previewer_state}"
                )
        if not isinstance(previewer_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor previewer resource snapshot: {previewer_resource_snapshot}"
            )

        undo_redo_state = tool_call("get_editor_undo_redo_availability", {}, request_id=21)
        direct_undo_redo_snapshot = execute_editor_script(
            """
var undo_redo = EditorInterface.get_editor_undo_redo()
_custom_print(JSON.stringify({
	"undo_redo_available": undo_redo != null,
	"undo_redo_type": undo_redo.get_class() if undo_redo else ""
}))
""",
            request_id=22,
        )
        if direct_undo_redo_snapshot.get("success") is not True or not direct_undo_redo_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor undo/redo snapshot: {direct_undo_redo_snapshot}")

        direct_undo_redo_payload = json.loads(direct_undo_redo_snapshot["output"][-1])
        for key in ("undo_redo_available", "undo_redo_type"):
            if undo_redo_state.get(key) != direct_undo_redo_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface undo/redo truth: {undo_redo_state} vs {direct_undo_redo_payload}"
                )
            if undo_redo_resource_snapshot.get(key) != undo_redo_state.get(key):
                raise AssertionError(
                    f"Undo-redo resource {key} drifted from tool truth: {undo_redo_resource_snapshot} vs {undo_redo_state}"
                )
        if not isinstance(undo_redo_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor undo-redo resource snapshot: {undo_redo_resource_snapshot}"
            )

        viewport_state = tool_call("get_editor_viewport_availability", {}, request_id=23)
        direct_viewport_snapshot = execute_editor_script(
            """
var viewport_2d = EditorInterface.get_editor_viewport_2d()
var viewport_3d = EditorInterface.get_editor_viewport_3d(0)
_custom_print(JSON.stringify({
	"viewport_2d_available": viewport_2d != null,
	"viewport_2d_type": viewport_2d.get_class() if viewport_2d else "",
	"viewport_3d_available": viewport_3d != null,
	"viewport_3d_type": viewport_3d.get_class() if viewport_3d else ""
}))
""",
            request_id=24,
        )
        if direct_viewport_snapshot.get("success") is not True or not direct_viewport_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor viewport snapshot: {direct_viewport_snapshot}")

        direct_viewport_payload = json.loads(direct_viewport_snapshot["output"][-1])
        for key in ("viewport_2d_available", "viewport_2d_type", "viewport_3d_available", "viewport_3d_type"):
            if viewport_state.get(key) != direct_viewport_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface viewport truth: {viewport_state} vs {direct_viewport_payload}"
                )
            if viewport_resource_snapshot.get(key) != viewport_state.get(key):
                raise AssertionError(
                    f"Viewport resource {key} drifted from tool truth: {viewport_resource_snapshot} vs {viewport_state}"
                )
        if not isinstance(viewport_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor viewport resource snapshot: {viewport_resource_snapshot}"
            )

        base_control_state = tool_call("get_editor_base_control_availability", {}, request_id=25)
        direct_base_control_snapshot = execute_editor_script(
            """
var base_control = EditorInterface.get_base_control()
_custom_print(JSON.stringify({
	"base_control_available": base_control != null,
	"base_control_type": base_control.get_class() if base_control else ""
}))
""",
            request_id=26,
        )
        if direct_base_control_snapshot.get("success") is not True or not direct_base_control_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor base control snapshot: {direct_base_control_snapshot}")

        direct_base_control_payload = json.loads(direct_base_control_snapshot["output"][-1])
        for key in ("base_control_available", "base_control_type"):
            if base_control_state.get(key) != direct_base_control_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface base control truth: {base_control_state} vs {direct_base_control_payload}"
                )
            if base_control_resource_snapshot.get(key) != base_control_state.get(key):
                raise AssertionError(
                    f"Base-control resource {key} drifted from tool truth: {base_control_resource_snapshot} vs {base_control_state}"
                )
        if not isinstance(base_control_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor base-control resource snapshot: {base_control_resource_snapshot}"
            )

        file_system_dock_state = tool_call("get_editor_file_system_dock_availability", {}, request_id=27)
        direct_file_system_dock_snapshot = execute_editor_script(
            """
var file_system_dock = EditorInterface.get_file_system_dock()
_custom_print(JSON.stringify({
	"file_system_dock_available": file_system_dock != null,
	"file_system_dock_type": file_system_dock.get_class() if file_system_dock else ""
}))
""",
            request_id=28,
        )
        if direct_file_system_dock_snapshot.get("success") is not True or not direct_file_system_dock_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor file system dock snapshot: {direct_file_system_dock_snapshot}")

        direct_file_system_dock_payload = json.loads(direct_file_system_dock_snapshot["output"][-1])
        for key in ("file_system_dock_available", "file_system_dock_type"):
            if file_system_dock_state.get(key) != direct_file_system_dock_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface file system dock truth: {file_system_dock_state} vs {direct_file_system_dock_payload}"
                )
            if file_system_dock_resource_snapshot.get(key) != file_system_dock_state.get(key):
                raise AssertionError(
                    f"File-system-dock resource {key} drifted from tool truth: "
                    f"{file_system_dock_resource_snapshot} vs {file_system_dock_state}"
                )
        if not isinstance(file_system_dock_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor file-system-dock resource snapshot: {file_system_dock_resource_snapshot}"
            )

        inspector_state = tool_call("get_editor_inspector_availability", {}, request_id=29)
        direct_inspector_snapshot = execute_editor_script(
            """
var inspector = EditorInterface.get_inspector()
_custom_print(JSON.stringify({
	"inspector_available": inspector != null,
	"inspector_type": inspector.get_class() if inspector else ""
}))
""",
            request_id=30,
        )
        if direct_inspector_snapshot.get("success") is not True or not direct_inspector_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor inspector snapshot: {direct_inspector_snapshot}")

        direct_inspector_payload = json.loads(direct_inspector_snapshot["output"][-1])
        for key in ("inspector_available", "inspector_type"):
            if inspector_state.get(key) != direct_inspector_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface inspector truth: {inspector_state} vs {direct_inspector_payload}"
                )
            if inspector_resource_snapshot.get(key) != inspector_state.get(key):
                raise AssertionError(
                    f"Inspector resource {key} drifted from tool truth: "
                    f"{inspector_resource_snapshot} vs {inspector_state}"
                )
        if not isinstance(inspector_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor inspector resource snapshot: {inspector_resource_snapshot}"
            )

        current_location = tool_call("get_editor_current_location", {}, request_id=31)
        direct_current_location_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"current_path": EditorInterface.get_current_path(),
	"current_directory": EditorInterface.get_current_directory()
}))
""",
            request_id=32,
        )
        if direct_current_location_snapshot.get("success") is not True or not direct_current_location_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor current-location snapshot: {direct_current_location_snapshot}")

        direct_current_location_payload = json.loads(direct_current_location_snapshot["output"][-1])
        for key in ("current_path", "current_directory"):
            if current_location.get(key) != direct_current_location_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface current-location truth: {current_location} vs {direct_current_location_payload}"
                )

        selected_paths_summary = tool_call("get_editor_selected_paths_summary", {}, request_id=33)
        direct_selected_paths_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"selected_paths": Array(EditorInterface.get_selected_paths())
}))
""",
            request_id=34,
        )
        if direct_selected_paths_snapshot.get("success") is not True or not direct_selected_paths_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor selected-paths snapshot: {direct_selected_paths_snapshot}")

        direct_selected_paths_payload = json.loads(direct_selected_paths_snapshot["output"][-1])
        if selected_paths_summary.get("selected_paths") != direct_selected_paths_payload.get("selected_paths", []):
            raise AssertionError(
                f"Tool selected_paths drifted from live EditorInterface truth: {selected_paths_summary} vs {direct_selected_paths_payload}"
            )
        if selected_paths_summary.get("selected_count") != len(selected_paths_summary.get("selected_paths", [])):
            raise AssertionError(f"Expected selected_count to match selected_paths length: {selected_paths_summary}")
        for key in ("selected_paths", "selected_count"):
            if selected_paths_resource_snapshot.get(key) != selected_paths_summary.get(key):
                raise AssertionError(
                    f"Selected-paths resource {key} drifted from tool truth: "
                    f"{selected_paths_resource_snapshot} vs {selected_paths_summary}"
                )
        if not isinstance(selected_paths_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor selected-paths resource snapshot: {selected_paths_resource_snapshot}"
            )

        selection_state = tool_call("get_editor_selection_availability", {}, request_id=35)
        direct_selection_snapshot = execute_editor_script(
            """
var selection = EditorInterface.get_selection()
_custom_print(JSON.stringify({
	"selection_available": selection != null,
	"selection_type": selection.get_class() if selection else ""
}))
""",
            request_id=36,
        )
        if direct_selection_snapshot.get("success") is not True or not direct_selection_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for editor selection snapshot: {direct_selection_snapshot}")

        direct_selection_payload = json.loads(direct_selection_snapshot["output"][-1])
        for key in ("selection_available", "selection_type"):
            if selection_state.get(key) != direct_selection_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface selection truth: {selection_state} vs {direct_selection_payload}"
                )
            if selection_resource_snapshot.get(key) != selection_state.get(key):
                raise AssertionError(
                    f"Selection-availability resource {key} drifted from tool truth: "
                    f"{selection_resource_snapshot} vs {selection_state}"
                )
        if not isinstance(selection_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor selection-availability resource snapshot: {selection_resource_snapshot}"
            )

        command_palette_state = tool_call("get_editor_command_palette_availability", {}, request_id=37)
        direct_command_palette_snapshot = execute_editor_script(
            """
var command_palette = EditorInterface.get_command_palette()
_custom_print(JSON.stringify({
	"command_palette_available": command_palette != null,
	"command_palette_type": command_palette.get_class() if command_palette else ""
}))
""",
            request_id=38,
        )
        if direct_command_palette_snapshot.get("success") is not True or not direct_command_palette_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor command palette snapshot: {direct_command_palette_snapshot}"
            )

        direct_command_palette_payload = json.loads(direct_command_palette_snapshot["output"][-1])
        for key in ("command_palette_available", "command_palette_type"):
            if command_palette_state.get(key) != direct_command_palette_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface command palette truth: "
                    f"{command_palette_state} vs {direct_command_palette_payload}"
                )
            if command_palette_resource_snapshot.get(key) != command_palette_state.get(key):
                raise AssertionError(
                    f"Command-palette resource {key} drifted from tool truth: "
                    f"{command_palette_resource_snapshot} vs {command_palette_state}"
                )
        if not isinstance(command_palette_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor command-palette resource snapshot: {command_palette_resource_snapshot}"
            )

        toaster_state = tool_call("get_editor_toaster_availability", {}, request_id=39)
        direct_toaster_snapshot = execute_editor_script(
            """
var toaster = EditorInterface.get_editor_toaster()
_custom_print(JSON.stringify({
	"toaster_available": toaster != null,
	"toaster_type": toaster.get_class() if toaster else ""
}))
""",
            request_id=40,
        )
        if direct_toaster_snapshot.get("success") is not True or not direct_toaster_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor toaster snapshot: {direct_toaster_snapshot}"
            )

        direct_toaster_payload = json.loads(direct_toaster_snapshot["output"][-1])
        for key in ("toaster_available", "toaster_type"):
            if toaster_state.get(key) != direct_toaster_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface toaster truth: "
                    f"{toaster_state} vs {direct_toaster_payload}"
                )
            if toaster_resource_snapshot.get(key) != toaster_state.get(key):
                raise AssertionError(
                    f"Toaster resource {key} drifted from tool truth: "
                    f"{toaster_resource_snapshot} vs {toaster_state}"
                )
        if not isinstance(toaster_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor toaster resource snapshot: {toaster_resource_snapshot}"
            )

        resource_filesystem_state = tool_call("get_editor_resource_filesystem_availability", {}, request_id=41)
        direct_resource_filesystem_snapshot = execute_editor_script(
            """
var resource_filesystem = EditorInterface.get_resource_filesystem()
_custom_print(JSON.stringify({
	"resource_filesystem_available": resource_filesystem != null,
	"resource_filesystem_type": resource_filesystem.get_class() if resource_filesystem else ""
}))
""",
            request_id=42,
        )
        if direct_resource_filesystem_snapshot.get("success") is not True or not direct_resource_filesystem_snapshot.get("output"):
            raise AssertionError(
                "execute_editor_script failed for editor resource filesystem snapshot: "
                f"{direct_resource_filesystem_snapshot}"
            )

        direct_resource_filesystem_payload = json.loads(direct_resource_filesystem_snapshot["output"][-1])
        for key in ("resource_filesystem_available", "resource_filesystem_type"):
            if resource_filesystem_state.get(key) != direct_resource_filesystem_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface resource filesystem truth: "
                    f"{resource_filesystem_state} vs {direct_resource_filesystem_payload}"
                )
            if resource_filesystem_resource_snapshot.get(key) != resource_filesystem_state.get(key):
                raise AssertionError(
                    f"Resource-filesystem resource {key} drifted from tool truth: "
                    f"{resource_filesystem_resource_snapshot} vs {resource_filesystem_state}"
                )
        if not isinstance(resource_filesystem_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                "Expected timestamp in editor resource-filesystem resource snapshot: "
                f"{resource_filesystem_resource_snapshot}"
            )

        script_editor_state = tool_call("get_editor_script_editor_availability", {}, request_id=43)
        direct_script_editor_snapshot = execute_editor_script(
            """
var script_editor = EditorInterface.get_script_editor()
_custom_print(JSON.stringify({
	"script_editor_available": script_editor != null,
	"script_editor_type": script_editor.get_class() if script_editor else ""
}))
""",
            request_id=44,
        )
        if direct_script_editor_snapshot.get("success") is not True or not direct_script_editor_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor script editor snapshot: {direct_script_editor_snapshot}"
            )

        direct_script_editor_payload = json.loads(direct_script_editor_snapshot["output"][-1])
        for key in ("script_editor_available", "script_editor_type"):
            if script_editor_state.get(key) != direct_script_editor_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface script editor truth: "
                    f"{script_editor_state} vs {direct_script_editor_payload}"
                )
            if script_editor_resource_snapshot.get(key) != script_editor_state.get(key):
                raise AssertionError(
                    f"Script-editor resource {key} drifted from tool truth: "
                    f"{script_editor_resource_snapshot} vs {script_editor_state}"
                )
        if not isinstance(script_editor_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor script-editor resource snapshot: {script_editor_resource_snapshot}"
            )

        open_script_summary = tool_call("get_editor_open_script_summary", {}, request_id=45)
        direct_open_script_snapshot = execute_editor_script(
            """
var script_editor = EditorInterface.get_script_editor()
var current_script = script_editor.get_current_script() if script_editor else null
var current_editor = script_editor.get_current_editor() if script_editor else null
var current_editor_breakpoints: Array = []
if current_editor:
	for line_number in current_editor.get_breakpoints():
		current_editor_breakpoints.append(int(line_number))
var open_script_paths: Array = []
var open_script_types: Array = []
if script_editor:
	for script in script_editor.get_open_scripts():
		if script:
			open_script_paths.append(str(script.resource_path))
			open_script_types.append(str(script.get_class()))
var open_script_editor_types: Array = []
if script_editor:
	for script_editor_base in script_editor.get_open_script_editors():
		open_script_editor_types.append(script_editor_base.get_class() if script_editor_base else "")
var breakpoints: Array = []
if script_editor:
	for breakpoint_entry in script_editor.get_breakpoints():
		breakpoints.append(str(breakpoint_entry))
_custom_print(JSON.stringify({
	"script_open": current_script != null,
	"script_path": str(current_script.resource_path) if current_script else "",
	"current_script_type": str(current_script.get_class()) if current_script else "",
	"current_editor_type": current_editor.get_class() if current_editor else "",
	"current_editor_breakpoints": current_editor_breakpoints,
	"current_editor_breakpoint_count": current_editor_breakpoints.size(),
	"open_script_paths": open_script_paths,
	"open_script_types": open_script_types,
	"open_script_count": open_script_paths.size(),
	"open_script_editor_types": open_script_editor_types,
	"open_script_editor_count": script_editor.get_open_script_editors().size() if script_editor else 0,
	"breakpoints": breakpoints,
	"breakpoint_count": breakpoints.size()
}))
""",
            request_id=46,
        )
        if direct_open_script_snapshot.get("success") is not True or not direct_open_script_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor open-script snapshot: {direct_open_script_snapshot}"
            )

        direct_open_script_payload = json.loads(direct_open_script_snapshot["output"][-1])
        for key in ("script_open", "script_path", "current_script_type", "current_editor_type", "current_editor_breakpoints", "current_editor_breakpoint_count", "open_script_paths", "open_script_types", "open_script_count", "open_script_editor_types", "open_script_editor_count", "breakpoints", "breakpoint_count"):
            if open_script_summary.get(key) != direct_open_script_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface open-script truth: "
                    f"{open_script_summary} vs {direct_open_script_payload}"
                )

        open_scene_summary = tool_call("get_editor_open_scene_summary", {}, request_id=47)
        direct_open_scene_snapshot = execute_editor_script(
            """
var active_scene = EditorInterface.get_edited_scene_root()
_custom_print(JSON.stringify({
	"scene_open": active_scene != null,
	"scene_path": str(active_scene.scene_file_path) if active_scene else ""
}))
""",
            request_id=48,
        )
        if direct_open_scene_snapshot.get("success") is not True or not direct_open_scene_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor open-scene snapshot: {direct_open_scene_snapshot}"
            )

        direct_open_scene_payload = json.loads(direct_open_scene_snapshot["output"][-1])
        for key in ("scene_open", "scene_path"):
            if open_scene_summary.get(key) != direct_open_scene_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface open-scene truth: "
                    f"{open_scene_summary} vs {direct_open_scene_payload}"
                )
            if open_scene_resource_snapshot.get(key) != open_scene_summary.get(key):
                raise AssertionError(
                    f"Open-scene resource {key} drifted from tool truth: "
                    f"{open_scene_resource_snapshot} vs {open_scene_summary}"
                )
        if not isinstance(open_scene_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor open-scene resource snapshot: {open_scene_resource_snapshot}"
            )

        open_scenes_summary = tool_call("get_editor_open_scenes_summary", {}, request_id=49)
        direct_open_scenes_snapshot = execute_editor_script(
            """
var open_scene_paths: Array = []
for scene_path in EditorInterface.get_open_scenes():
	open_scene_paths.append(str(scene_path))
var active_scene = EditorInterface.get_edited_scene_root()
_custom_print(JSON.stringify({
	"open_scene_paths": open_scene_paths,
	"active_scene_path": str(active_scene.scene_file_path) if active_scene else "",
	"open_scene_count": open_scene_paths.size()
}))
""",
            request_id=50,
        )
        if direct_open_scenes_snapshot.get("success") is not True or not direct_open_scenes_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor open-scenes snapshot: {direct_open_scenes_snapshot}"
            )

        direct_open_scenes_payload = json.loads(direct_open_scenes_snapshot["output"][-1])
        for key in ("open_scene_paths", "active_scene_path", "open_scene_count"):
            if open_scenes_summary.get(key) != direct_open_scenes_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface open-scenes truth: "
                    f"{open_scenes_summary} vs {direct_open_scenes_payload}"
                )
            if open_scenes_resource_snapshot.get(key) != open_scenes_summary.get(key):
                raise AssertionError(
                    f"Open-scenes resource {key} drifted from tool truth: "
                    f"{open_scenes_resource_snapshot} vs {open_scenes_summary}"
                )
        if not isinstance(open_scenes_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor open-scenes resource snapshot: {open_scenes_resource_snapshot}"
            )

        open_scene_roots_summary = tool_call("get_editor_open_scene_roots_summary", {}, request_id=51)
        direct_open_scene_roots_snapshot = execute_editor_script(
            """
var open_scene_roots: Array = []
for root in EditorInterface.get_open_scene_roots():
	if root:
		open_scene_roots.append({
			"root_name": str(root.name),
			"root_type": str(root.get_class())
		})
_custom_print(JSON.stringify({
	"open_scene_roots": open_scene_roots,
	"open_scene_root_count": open_scene_roots.size()
}))
""",
            request_id=52,
        )
        if direct_open_scene_roots_snapshot.get("success") is not True or not direct_open_scene_roots_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor open-scene-roots snapshot: {direct_open_scene_roots_snapshot}"
            )

        direct_open_scene_roots_payload = json.loads(direct_open_scene_roots_snapshot["output"][-1])
        for key in ("open_scene_roots", "open_scene_root_count"):
            if open_scene_roots_summary.get(key) != direct_open_scene_roots_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface open-scene-roots truth: "
                    f"{open_scene_roots_summary} vs {direct_open_scene_roots_payload}"
                )
            if open_scene_roots_resource_snapshot.get(key) != open_scene_roots_summary.get(key):
                raise AssertionError(
                    f"Open-scene-roots resource {key} drifted from tool truth: "
                    f"{open_scene_roots_resource_snapshot} vs {open_scene_roots_summary}"
                )
        if not isinstance(open_scene_roots_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor open-scene-roots resource snapshot: {open_scene_roots_resource_snapshot}"
            )

        editor_settings_state = tool_call("get_editor_settings_availability", {}, request_id=53)
        direct_editor_settings_snapshot = execute_editor_script(
            """
var editor_settings = EditorInterface.get_editor_settings()
_custom_print(JSON.stringify({
	"editor_settings_available": editor_settings != null,
	"editor_settings_type": editor_settings.get_class() if editor_settings else ""
}))
""",
            request_id=54,
        )
        if direct_editor_settings_snapshot.get("success") is not True or not direct_editor_settings_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor settings snapshot: {direct_editor_settings_snapshot}"
            )

        direct_editor_settings_payload = json.loads(direct_editor_settings_snapshot["output"][-1])
        for key in ("editor_settings_available", "editor_settings_type"):
            if editor_settings_state.get(key) != direct_editor_settings_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface editor settings truth: "
                    f"{editor_settings_state} vs {direct_editor_settings_payload}"
                )
            if editor_settings_resource_snapshot.get(key) != editor_settings_state.get(key):
                raise AssertionError(
                    f"Editor-settings resource {key} drifted from tool truth: "
                    f"{editor_settings_resource_snapshot} vs {editor_settings_state}"
                )
        if not isinstance(editor_settings_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor settings resource snapshot: {editor_settings_resource_snapshot}"
            )

        editor_theme_state = tool_call("get_editor_theme_availability", {}, request_id=55)
        direct_editor_theme_snapshot = execute_editor_script(
            """
var editor_theme = EditorInterface.get_editor_theme()
_custom_print(JSON.stringify({
	"editor_theme_available": editor_theme != null,
	"editor_theme_type": editor_theme.get_class() if editor_theme else ""
}))
""",
            request_id=56,
        )
        if direct_editor_theme_snapshot.get("success") is not True or not direct_editor_theme_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor theme snapshot: {direct_editor_theme_snapshot}"
            )

        direct_editor_theme_payload = json.loads(direct_editor_theme_snapshot["output"][-1])
        for key in ("editor_theme_available", "editor_theme_type"):
            if editor_theme_state.get(key) != direct_editor_theme_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface editor theme truth: "
                    f"{editor_theme_state} vs {direct_editor_theme_payload}"
                )
            if editor_theme_resource_snapshot.get(key) != editor_theme_state.get(key):
                raise AssertionError(
                    f"Editor-theme resource {key} drifted from tool truth: "
                    f"{editor_theme_resource_snapshot} vs {editor_theme_state}"
                )
        if not isinstance(editor_theme_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                f"Expected timestamp in editor theme resource snapshot: {editor_theme_resource_snapshot}"
            )

        current_feature_profile_state = tool_call("get_editor_current_feature_profile", {}, request_id=57)
        direct_current_feature_profile_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"current_feature_profile": str(EditorInterface.get_current_feature_profile()),
	"uses_default_profile": String(EditorInterface.get_current_feature_profile()).is_empty()
}))
""",
            request_id=58,
        )
        if direct_current_feature_profile_snapshot.get("success") is not True or not direct_current_feature_profile_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor current feature profile snapshot: {direct_current_feature_profile_snapshot}"
            )

        direct_current_feature_profile_payload = json.loads(direct_current_feature_profile_snapshot["output"][-1])
        for key in ("current_feature_profile", "uses_default_profile"):
            if current_feature_profile_state.get(key) != direct_current_feature_profile_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface current feature profile truth: "
                    f"{current_feature_profile_state} vs {direct_current_feature_profile_payload}"
                )
            if current_feature_profile_resource_snapshot.get(key) != current_feature_profile_state.get(key):
                raise AssertionError(
                    f"Current-feature-profile resource {key} drifted from tool truth: "
                    f"{current_feature_profile_resource_snapshot} vs {current_feature_profile_state}"
                )
        if not isinstance(current_feature_profile_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                "Expected timestamp in editor current-feature-profile resource snapshot: "
                f"{current_feature_profile_resource_snapshot}"
            )

        plugin_enabled_state = tool_call(
            "get_editor_plugin_enabled_state",
            {"plugin_name": "godot_mcp"},
            request_id=59,
        )
        direct_plugin_enabled_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"plugin_name": "godot_mcp",
	"enabled": EditorInterface.is_plugin_enabled("godot_mcp")
}))
""",
            request_id=60,
        )
        if direct_plugin_enabled_snapshot.get("success") is not True or not direct_plugin_enabled_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor plugin enabled-state snapshot: {direct_plugin_enabled_snapshot}"
            )

        direct_plugin_enabled_payload = json.loads(direct_plugin_enabled_snapshot["output"][-1])
        for key in ("plugin_name", "enabled"):
            if plugin_enabled_state.get(key) != direct_plugin_enabled_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface plugin enabled-state truth: "
                    f"{plugin_enabled_state} vs {direct_plugin_enabled_payload}"
                )

        current_scene_dirty_state = tool_call("get_editor_current_scene_dirty_state", {}, request_id=61)
        direct_current_scene_dirty_snapshot = execute_editor_script(
            """
var scene_root = EditorInterface.get_edited_scene_root()
_custom_print(JSON.stringify({
	"scene_open": scene_root != null,
	"scene_path": str(scene_root.scene_file_path) if scene_root else "",
	"scene_dirty": EditorInterface.is_object_edited(scene_root) if scene_root else false
}))
""",
            request_id=62,
        )
        if direct_current_scene_dirty_snapshot.get("success") is not True or not direct_current_scene_dirty_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for editor current scene dirty-state snapshot: {direct_current_scene_dirty_snapshot}"
            )

        direct_current_scene_dirty_payload = json.loads(direct_current_scene_dirty_snapshot["output"][-1])
        for key in ("scene_open", "scene_path", "scene_dirty"):
            if current_scene_dirty_state.get(key) != direct_current_scene_dirty_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface current scene dirty-state truth: "
                    f"{current_scene_dirty_state} vs {direct_current_scene_dirty_payload}"
                )
            if current_scene_dirty_resource_snapshot.get(key) != current_scene_dirty_state.get(key):
                raise AssertionError(
                    f"Current-scene-dirty resource {key} drifted from tool truth: "
                    f"{current_scene_dirty_resource_snapshot} vs {current_scene_dirty_state}"
                )
        if not isinstance(current_scene_dirty_resource_snapshot.get("timestamp"), (int, float)):
            raise AssertionError(
                "Expected timestamp in editor current-scene-dirty resource snapshot: "
                f"{current_scene_dirty_resource_snapshot}"
            )

        reopen_dirty_scene = tool_call(
            "open_scene",
            {"scene_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=63,
        )
        if reopen_dirty_scene.get("status") != "success":
            raise AssertionError(f"Failed to reopen dirty-state probe scene: {reopen_dirty_scene}")

        forced_dirty_state = tool_call(
            "get_editor_current_scene_dirty_state",
            {"set_dirty": True},
            request_id=64,
        )
        direct_forced_dirty_snapshot = execute_editor_script(
            """
var scene_root = EditorInterface.get_edited_scene_root()
_custom_print(JSON.stringify({
	"scene_open": scene_root != null,
	"scene_path": str(scene_root.scene_file_path) if scene_root else "",
	"scene_dirty": EditorInterface.is_object_edited(scene_root) if scene_root else false
}))
""",
            request_id=65,
        )
        if direct_forced_dirty_snapshot.get("success") is not True or not direct_forced_dirty_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for forced dirty-state snapshot: {direct_forced_dirty_snapshot}"
            )

        direct_forced_dirty_payload = json.loads(direct_forced_dirty_snapshot["output"][-1])
        for key in ("scene_open", "scene_path", "scene_dirty"):
            if forced_dirty_state.get(key) != direct_forced_dirty_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface forced dirty-state truth: "
                    f"{forced_dirty_state} vs {direct_forced_dirty_payload}"
                )
        if forced_dirty_state.get("scene_dirty") is not True:
            raise AssertionError(f"Expected set_dirty=true to mark the active scene dirty: {forced_dirty_state}")

        reset_dirty_state = tool_call(
            "get_editor_current_scene_dirty_state",
            {"set_dirty": False},
            request_id=66,
        )
        direct_reset_dirty_snapshot = execute_editor_script(
            """
var scene_root = EditorInterface.get_edited_scene_root()
_custom_print(JSON.stringify({
	"scene_open": scene_root != null,
	"scene_path": str(scene_root.scene_file_path) if scene_root else "",
	"scene_dirty": EditorInterface.is_object_edited(scene_root) if scene_root else false
}))
""",
            request_id=67,
        )
        if direct_reset_dirty_snapshot.get("success") is not True or not direct_reset_dirty_snapshot.get("output"):
            raise AssertionError(
                f"execute_editor_script failed for reset dirty-state snapshot: {direct_reset_dirty_snapshot}"
            )

        direct_reset_dirty_payload = json.loads(direct_reset_dirty_snapshot["output"][-1])
        for key in ("scene_open", "scene_path", "scene_dirty"):
            if reset_dirty_state.get(key) != direct_reset_dirty_payload.get(key):
                raise AssertionError(
                    f"Tool {key} drifted from live EditorInterface reset dirty-state truth: "
                    f"{reset_dirty_state} vs {direct_reset_dirty_payload}"
                )
        if reset_dirty_state.get("scene_dirty") is not False:
            raise AssertionError(f"Expected set_dirty=false to clear the active scene dirty state: {reset_dirty_state}")

        print(
            "editor paths, shell, language, play-state, 3d snap, subsystem, previewer, undo-redo, "
            "viewport, base-control, file-system-dock, inspector, current-location, selected-paths, "
            "selection, command-palette, toaster, resource-filesystem, script-editor, open-script, open-scene, open-scenes, open-scene-roots, editor-settings, editor-theme, current-feature-profile, plugin-enabled-state, and current-scene-dirty-state flow verified"
        )
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
        if TEMP_DIR.exists():
            shutil.rmtree(TEMP_DIR, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
