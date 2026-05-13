import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"
PROFILE_NAME = "MCPTempFeatureProfile"


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


def current_profile_snapshot(request_id: int) -> dict:
    result = execute_editor_script(
        f"""
var editor_paths = EditorInterface.get_editor_paths()
var profile_path = editor_paths.get_config_dir().path_join("feature_profiles").path_join("{PROFILE_NAME}.profile")
var payload = {{
	"current_profile": EditorInterface.get_current_feature_profile(),
	"profile_exists": FileAccess.file_exists(profile_path)
}}
_custom_print(JSON.stringify(payload))
""",
        request_id=request_id,
    )
    if result.get("success") is not True or not result.get("output"):
        raise AssertionError(f"execute_editor_script failed for feature profile snapshot: {result}")
    return json.loads(result["output"][-1])


def inspected_profile_snapshot(request_id: int) -> dict:
    return tool_call(
        "inspect_project_feature_profile",
        {"profile_name": PROFILE_NAME},
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
            "list_project_feature_profiles",
            "inspect_project_feature_profile",
            "set_project_feature_profile",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected feature profile tools: {missing_tools}")

        setup_result = execute_editor_script(
            f"""
var editor_paths = EditorInterface.get_editor_paths()
var feature_profiles_dir = editor_paths.get_config_dir().path_join("feature_profiles")
DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
var profile_path = feature_profiles_dir.path_join("{PROFILE_NAME}.profile")
var file = FileAccess.open(profile_path, FileAccess.WRITE)
var write_ok = file != null
if file != null:
	file.store_string('{{"disabled_classes":[],"disabled_editors":[],"disabled_properties":{{}},"disabled_features":[1]}}')
	file.close()
_custom_print(JSON.stringify({{"write_ok": write_ok, "profile_path": profile_path}}))
""",
            request_id=2,
        )
        if setup_result.get("success") is not True or not setup_result.get("output"):
            raise AssertionError(f"Failed to create temporary feature profile fixture: {setup_result}")
        setup_payload = json.loads(setup_result["output"][-1])
        if setup_payload.get("write_ok") is not True:
            raise AssertionError(f"Expected temporary feature profile fixture to be writable: {setup_payload}")

        listed_before = tool_call("list_project_feature_profiles", {}, request_id=21)
        if listed_before.get("count") < 1:
            raise AssertionError(f"Expected temporary feature profile to appear in listing: {listed_before}")
        if listed_before.get("current_profile") != "":
            raise AssertionError(f"Expected default profile to be active before activation: {listed_before}")
        listed_entry = next((entry for entry in listed_before.get("profiles", []) if entry.get("name") == PROFILE_NAME), None)
        if listed_entry is None:
            raise AssertionError(f"Expected temporary feature profile entry in listing: {listed_before}")
        if listed_entry.get("is_current") is not False:
            raise AssertionError(f"Expected temporary feature profile to be inactive before activation: {listed_entry}")
        inspected_before = inspected_profile_snapshot(request_id=24)
        if inspected_before.get("exists") is not True or inspected_before.get("is_current") is not False:
            raise AssertionError(f"Expected profile inspection to reflect inactive pre-activation state: {inspected_before}")

        activate_result = tool_call(
            "set_project_feature_profile",
            {
                "profile_name": PROFILE_NAME,
            },
            request_id=3,
        )
        if activate_result.get("profile_name_requested") != PROFILE_NAME:
            raise AssertionError(f"Unexpected feature profile request echo: {activate_result}")
        if activate_result.get("current_profile") != PROFILE_NAME:
            raise AssertionError(f"Expected feature profile activation to succeed: {activate_result}")
        if activate_result.get("used_default") is not False:
            raise AssertionError(f"Expected explicit feature profile activation to report used_default=false: {activate_result}")

        activated_snapshot = current_profile_snapshot(request_id=4)
        if activated_snapshot != {"current_profile": PROFILE_NAME, "profile_exists": True}:
            raise AssertionError(f"Unexpected activated feature profile snapshot: {activated_snapshot}")
        inspected_after_activate = inspected_profile_snapshot(request_id=25)
        if inspected_after_activate.get("profile_name") != PROFILE_NAME or inspected_after_activate.get("is_current") is not True:
            raise AssertionError(f"Expected profile inspection to reflect active state after activation: {inspected_after_activate}")
        listed_after_activate = tool_call("list_project_feature_profiles", {}, request_id=22)
        activated_entry = next((entry for entry in listed_after_activate.get("profiles", []) if entry.get("name") == PROFILE_NAME), None)
        if activated_entry is None or activated_entry.get("is_current") is not True:
            raise AssertionError(f"Expected MCP listing to mark the active feature profile: {listed_after_activate}")

        reset_result = tool_call(
            "set_project_feature_profile",
            {
                "profile_name": "",
            },
            request_id=5,
        )
        if reset_result.get("current_profile") != "":
            raise AssertionError(f"Expected default feature profile reset to clear current profile: {reset_result}")
        if reset_result.get("used_default") is not True:
            raise AssertionError(f"Expected default feature profile reset to report used_default=true: {reset_result}")

        reset_snapshot = current_profile_snapshot(request_id=6)
        if reset_snapshot != {"current_profile": "", "profile_exists": True}:
            raise AssertionError(f"Unexpected reset feature profile snapshot: {reset_snapshot}")
        inspected_after_reset = inspected_profile_snapshot(request_id=26)
        if inspected_after_reset.get("exists") is not True or inspected_after_reset.get("is_current") is not False:
            raise AssertionError(f"Expected profile inspection to clear active marker after reset: {inspected_after_reset}")
        listed_after_reset = tool_call("list_project_feature_profiles", {}, request_id=23)
        reset_entry = next((entry for entry in listed_after_reset.get("profiles", []) if entry.get("name") == PROFILE_NAME), None)
        if reset_entry is None or reset_entry.get("is_current") is not False:
            raise AssertionError(f"Expected MCP listing to clear the active marker after reset: {listed_after_reset}")

        print("project feature profile flow verified")
        return 0
    finally:
        try:
            execute_editor_script(
                f"""
EditorInterface.set_current_feature_profile("")
var editor_paths = EditorInterface.get_editor_paths()
var profile_path = editor_paths.get_config_dir().path_join("feature_profiles").path_join("{PROFILE_NAME}.profile")
if FileAccess.file_exists(profile_path):
	DirAccess.remove_absolute(profile_path)
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
