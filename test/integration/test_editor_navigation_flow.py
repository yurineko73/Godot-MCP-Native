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
TEMP_DIR = REPO_ROOT / ".tmp_editor_navigation"
TEMP_SCENE_PATH = "res://.tmp_editor_navigation/temp_navigation_scene.tscn"


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
        expected_tools = {"get_file_system_navigation", "select_file", "create_scene", "open_scene", "execute_editor_script"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected editor navigation tools: {missing_tools}")

        create_temp_scene = tool_call(
            "create_scene",
            {"scene_path": TEMP_SCENE_PATH, "root_node_type": "Node"},
            request_id=2,
        )
        if create_temp_scene.get("status") != "success":
            raise AssertionError(f"create_scene failed: {create_temp_scene}")

        open_temp_scene = tool_call(
            "open_scene",
            {"scene_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=3,
        )
        if open_temp_scene.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_temp_scene}")

        select_result = tool_call(
            "select_file",
            {"file_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=4,
        )
        if select_result.get("status") != "success":
            raise AssertionError(f"select_file failed: {select_result}")

        navigation = tool_call("get_file_system_navigation", {}, request_id=5)
        if navigation.get("current_path") != TEMP_SCENE_PATH:
            raise AssertionError(f"Expected current_path to follow selected file: {navigation}")
        if navigation.get("current_directory") != "res://.tmp_editor_navigation":
            raise AssertionError(f"Expected current_directory to be selected file base dir: {navigation}")

        direct_snapshot = execute_editor_script(
            """
_custom_print(JSON.stringify({
	"current_path": EditorInterface.get_current_path(),
	"current_directory": EditorInterface.get_current_directory(),
	"selected_paths": Array(EditorInterface.get_selected_paths())
}))
""",
            request_id=6,
        )
        if direct_snapshot.get("success") is not True or not direct_snapshot.get("output"):
            raise AssertionError(f"execute_editor_script failed for navigation snapshot: {direct_snapshot}")
        direct_payload = json.loads(direct_snapshot["output"][-1])
        selected_paths = navigation.get("selected_paths", [])
        if navigation.get("current_path") != direct_payload.get("current_path"):
            raise AssertionError(f"Tool current_path drifted from live EditorInterface truth: {navigation} vs {direct_payload}")
        if navigation.get("current_directory") != direct_payload.get("current_directory"):
            raise AssertionError(f"Tool current_directory drifted from live EditorInterface truth: {navigation} vs {direct_payload}")
        if selected_paths != direct_payload.get("selected_paths", []):
            raise AssertionError(f"Tool selected_paths drifted from live EditorInterface truth: {navigation} vs {direct_payload}")
        if navigation.get("selected_count") != len(selected_paths):
            raise AssertionError(f"Expected selected_count to match serialized selected paths: {navigation}")

        print("editor navigation flow verified")
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
