import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"
PLUGIN_PATH = "res://addons/gut/plugin.cfg"
PLUGIN_NAME = "gut"
AUTOLOAD_NAME = "MCPTempSummaryAutoload"
AUTOLOAD_PATH = "res://.tmp_project_plugin_state_flow/temp_summary_autoload.gd"
PROFILE_NAME = "MCPTempSummaryProfile"


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


def plugin_state_snapshot(request_id: int) -> dict:
    result = execute_editor_script(
        f"""
var enabled_list = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
var payload = {{
	"enabled": EditorInterface.is_plugin_enabled("{PLUGIN_NAME}"),
	"listed": enabled_list.has("{PLUGIN_PATH}")
}}
_custom_print(JSON.stringify(payload))
""",
        request_id=request_id,
    )
    if result.get("success") is not True or not result.get("output"):
        raise AssertionError(f"execute_editor_script failed for plugin state snapshot: {result}")
    return json.loads(result["output"][-1])


def summary_snapshot(request_id: int, max_items: int = 5) -> dict:
    return tool_call(
        "get_project_configuration_summary",
        {"max_items": max_items},
        request_id=request_id,
    )


def plugin_inspection_snapshot(request_id: int) -> dict:
    return tool_call(
        "inspect_project_plugin",
        {"plugin_path": PLUGIN_PATH},
        request_id=request_id,
    )


def main() -> int:
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
            "list_project_plugins",
            "set_project_plugin_enabled",
            "inspect_project_plugin",
            "upsert_project_autoload",
            "remove_project_autoload",
            "set_project_feature_profile",
            "get_project_configuration_summary",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected plugin state tools: {missing_tools}")

        listed_before = tool_call("list_project_plugins", {}, request_id=20)
        if listed_before.get("count", 0) < 2:
            raise AssertionError(f"Expected project plugin listing to include installed plugins: {listed_before}")
        gut_before = next((entry for entry in listed_before.get("plugins", []) if entry.get("name") == PLUGIN_NAME), None)
        mcp_before = next((entry for entry in listed_before.get("plugins", []) if entry.get("name") == "godot_mcp"), None)
        if gut_before is None or mcp_before is None:
            raise AssertionError(f"Expected gut and godot_mcp plugin entries in listing: {listed_before}")

        baseline_result = tool_call(
            "set_project_plugin_enabled",
            {
                "plugin_path": PLUGIN_PATH,
                "enabled": False,
            },
            request_id=2,
        )
        if baseline_result.get("plugin_name") != PLUGIN_NAME:
            raise AssertionError(f"Unexpected plugin name during baseline disable: {baseline_result}")
        if baseline_result.get("enabled") is not False:
            raise AssertionError(f"Expected baseline disable to leave plugin disabled: {baseline_result}")
        baseline_snapshot = plugin_state_snapshot(request_id=3)
        if baseline_snapshot != {"enabled": False, "listed": False}:
            raise AssertionError(f"Unexpected baseline plugin snapshot: {baseline_snapshot}")
        baseline_inspection = plugin_inspection_snapshot(request_id=8)
        if baseline_inspection.get("plugin_name") != PLUGIN_NAME or baseline_inspection.get("enabled") is not False:
            raise AssertionError(f"Expected plugin inspection to reflect disabled baseline state: {baseline_inspection}")
        listed_after_disable = tool_call("list_project_plugins", {}, request_id=21)
        gut_after_disable = next((entry for entry in listed_after_disable.get("plugins", []) if entry.get("name") == PLUGIN_NAME), None)
        if gut_after_disable is None or gut_after_disable.get("enabled") is not False:
            raise AssertionError(f"Expected plugin listing to track disabled state: {listed_after_disable}")

        enable_result = tool_call(
            "set_project_plugin_enabled",
            {
                "plugin_path": PLUGIN_PATH,
                "enabled": True,
            },
            request_id=4,
        )
        if enable_result.get("plugin_path") != PLUGIN_PATH:
            raise AssertionError(f"Unexpected plugin path during enable: {enable_result}")
        if enable_result.get("plugin_name") != PLUGIN_NAME:
            raise AssertionError(f"Unexpected plugin name during enable: {enable_result}")
        if enable_result.get("enabled_requested") is not True:
            raise AssertionError(f"Expected enabled_requested=true during enable: {enable_result}")
        if enable_result.get("enabled") is not True:
            raise AssertionError(f"Expected plugin enable to succeed: {enable_result}")

        enabled_snapshot = plugin_state_snapshot(request_id=5)
        if enabled_snapshot != {"enabled": True, "listed": True}:
            raise AssertionError(f"Unexpected enabled plugin snapshot: {enabled_snapshot}")
        enabled_inspection = plugin_inspection_snapshot(request_id=9)
        if enabled_inspection.get("display_name") != "Gut":
            raise AssertionError(f"Expected plugin inspection to read plugin.cfg metadata: {enabled_inspection}")
        if enabled_inspection.get("enabled") is not True:
            raise AssertionError(f"Expected plugin inspection to reflect enabled state: {enabled_inspection}")
        listed_after_enable = tool_call("list_project_plugins", {}, request_id=22)
        gut_after_enable = next((entry for entry in listed_after_enable.get("plugins", []) if entry.get("name") == PLUGIN_NAME), None)
        if gut_after_enable is None or gut_after_enable.get("enabled") is not True:
            raise AssertionError(f"Expected plugin listing to track enabled state: {listed_after_enable}")
        fixture_setup = execute_editor_script(
            f"""
var autoload_dir = "res://.tmp_project_plugin_state_flow"
DirAccess.make_dir_recursive_absolute(autoload_dir)
var autoload_path = "{AUTOLOAD_PATH}"
var autoload_file = FileAccess.open(autoload_path, FileAccess.WRITE)
var autoload_write_ok = autoload_file != null
if autoload_file != null:
	autoload_file.store_string("extends Node\n")
	autoload_file.close()
var editor_paths = EditorInterface.get_editor_paths()
var feature_profiles_dir = editor_paths.get_config_dir().path_join("feature_profiles")
DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
var profile_path = feature_profiles_dir.path_join("{PROFILE_NAME}.profile")
var profile_file = FileAccess.open(profile_path, FileAccess.WRITE)
var profile_write_ok = profile_file != null
if profile_file != null:
	profile_file.store_string('{{"disabled_classes":[],"disabled_editors":[],"disabled_properties":{{}},"disabled_features":[1]}}')
	profile_file.close()
_custom_print(JSON.stringify({{
	"autoload_write_ok": autoload_write_ok,
	"profile_write_ok": profile_write_ok,
	"profile_path": profile_path
}}))
""",
            request_id=30,
        )
        if fixture_setup.get("success") is not True or not fixture_setup.get("output"):
            raise AssertionError(f"Failed to create summary fixtures: {fixture_setup}")
        fixture_payload = json.loads(fixture_setup["output"][-1])
        if fixture_payload.get("autoload_write_ok") is not True or fixture_payload.get("profile_write_ok") is not True:
            raise AssertionError(f"Expected temporary summary fixtures to be writable: {fixture_payload}")

        autoload_result = tool_call(
            "upsert_project_autoload",
            {
                "name": AUTOLOAD_NAME,
                "path": AUTOLOAD_PATH,
                "is_singleton": True,
            },
            request_id=31,
        )
        if autoload_result.get("name") != AUTOLOAD_NAME:
            raise AssertionError(f"Unexpected autoload upsert result: {autoload_result}")

        profile_result = tool_call(
            "set_project_feature_profile",
            {
                "profile_name": PROFILE_NAME,
            },
            request_id=32,
        )
        if profile_result.get("current_profile") != PROFILE_NAME:
            raise AssertionError(f"Expected temporary feature profile activation to succeed: {profile_result}")

        summary = summary_snapshot(request_id=33, max_items=5)
        if summary.get("enabled_plugin_count", 0) < 1:
            raise AssertionError(f"Expected project summary to report at least one enabled plugin: {summary}")
        if summary.get("current_feature_profile") != PROFILE_NAME:
            raise AssertionError(f"Expected project summary to report the active feature profile: {summary}")
        if summary.get("autoload_count", 0) < 1:
            raise AssertionError(f"Expected project summary to report the temporary autoload: {summary}")
        summary_plugins = summary.get("plugins", [])
        gut_summary = next((entry for entry in summary_plugins if entry.get("name") == PLUGIN_NAME), None)
        if gut_summary is None or gut_summary.get("enabled") is not True:
            raise AssertionError(f"Expected project summary to reflect enabled gut plugin state: {summary}")
        summary_autoloads = summary.get("autoloads", [])
        temp_autoload = next((entry for entry in summary_autoloads if entry.get("name") == AUTOLOAD_NAME), None)
        if temp_autoload is None or temp_autoload.get("path") != AUTOLOAD_PATH:
            raise AssertionError(f"Expected project summary to include the temporary autoload entry: {summary}")
        summary_profiles = summary.get("feature_profiles", [])
        temp_profile = next((entry for entry in summary_profiles if entry.get("name") == PROFILE_NAME), None)
        if temp_profile is None or temp_profile.get("is_current") is not True:
            raise AssertionError(f"Expected project summary to include the active feature profile entry: {summary}")

        disable_result = tool_call(
            "set_project_plugin_enabled",
            {
                "plugin_path": PLUGIN_PATH,
                "enabled": False,
            },
            request_id=6,
        )
        if disable_result.get("enabled_requested") is not False:
            raise AssertionError(f"Expected enabled_requested=false during disable: {disable_result}")
        if disable_result.get("enabled") is not False:
            raise AssertionError(f"Expected plugin disable to succeed: {disable_result}")

        disabled_snapshot = plugin_state_snapshot(request_id=7)
        if disabled_snapshot != {"enabled": False, "listed": False}:
            raise AssertionError(f"Unexpected disabled plugin snapshot: {disabled_snapshot}")
        disabled_inspection = plugin_inspection_snapshot(request_id=10)
        if disabled_inspection.get("enabled") is not False:
            raise AssertionError(f"Expected plugin inspection to reflect disabled state after reset: {disabled_inspection}")
        listed_after_reset = tool_call("list_project_plugins", {}, request_id=23)
        gut_after_reset = next((entry for entry in listed_after_reset.get("plugins", []) if entry.get("name") == PLUGIN_NAME), None)
        if gut_after_reset is None or gut_after_reset.get("enabled") is not False:
            raise AssertionError(f"Expected plugin listing to clear the enabled marker after disable: {listed_after_reset}")

        print("project plugin state flow verified")
        return 0
    finally:
        try:
            execute_editor_script(
                f"""
if EditorInterface.is_plugin_enabled("{PLUGIN_NAME}"):
	EditorInterface.set_plugin_enabled("{PLUGIN_NAME}", false)
var enabled_list = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
if enabled_list.has("{PLUGIN_PATH}"):
	enabled_list.erase("{PLUGIN_PATH}")
	ProjectSettings.set_setting("editor_plugins/enabled", enabled_list)
	ProjectSettings.save()
EditorInterface.set_current_feature_profile("")
var autoload_setting = "autoload/{AUTOLOAD_NAME}"
if ProjectSettings.has_setting(autoload_setting):
	ProjectSettings.clear(autoload_setting)
	ProjectSettings.save()
var editor_paths = EditorInterface.get_editor_paths()
var profile_path = editor_paths.get_config_dir().path_join("feature_profiles").path_join("{PROFILE_NAME}.profile")
if FileAccess.file_exists(profile_path):
	DirAccess.remove_absolute(profile_path)
if FileAccess.file_exists("{AUTOLOAD_PATH}"):
	DirAccess.remove_absolute("{AUTOLOAD_PATH}")
DirAccess.remove_absolute("res://.tmp_project_plugin_state_flow")
_custom_print(JSON.stringify({{"cleaned": true}}))
""",
                request_id=99,
            )
        except Exception:
            pass
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main())
