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
TEMP_DIR = REPO_ROOT / ".tmp_editor_tools"
TEMP_SCENE_PATH = "res://.tmp_editor_tools/temp_editor_scene.tscn"
SCRIPT_PATH = "res://addons/godot_mcp/tools/project_tools_native.gd"


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
            "select_node",
            "select_file",
            "get_inspector_properties",
            "open_script_at_line",
            "list_open_scenes",
            "close_scene_tab",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected editor automation tools: {missing_tools}")

        project_info = tool_call("get_project_info", request_id=2)
        main_scene = project_info["main_scene"]
        if not main_scene:
            raise AssertionError("Project has no main scene configured")

        open_main_result = tool_call("open_scene", {"scene_path": main_scene}, request_id=3)
        if open_main_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_main_result}")

        current_scene = tool_call("get_current_scene", {}, request_id=4)
        root_path = f"/root/{current_scene['scene_name']}"

        select_result = tool_call("select_node", {"node_path": root_path}, request_id=5)
        if select_result.get("status") != "success":
            raise AssertionError(f"select_node failed: {select_result}")

        selected_nodes = tool_call("get_selected_nodes", {}, request_id=6)
        selected_paths = {node["path"] for node in selected_nodes["selected_nodes"]}
        if root_path not in selected_paths:
            raise AssertionError(f"Root node was not selected: {selected_nodes}")

        inspector_result = tool_call(
            "get_inspector_properties",
            {"node_path": root_path, "property_filter": "process", "include_values": False},
            request_id=7,
        )
        if inspector_result.get("target_kind") != "node":
            raise AssertionError(f"Unexpected inspector payload: {inspector_result}")
        if inspector_result.get("property_count", 0) < 1:
            raise AssertionError(f"Expected at least one matching inspector property: {inspector_result}")

        file_select_result = tool_call("select_file", {"file_path": main_scene}, request_id=8)
        if file_select_result.get("status") != "success":
            raise AssertionError(f"select_file failed: {file_select_result}")

        open_script_result = tool_call(
            "open_script_at_line",
            {"script_path": SCRIPT_PATH, "line": 10, "column": 0},
            request_id=9,
        )
        if open_script_result.get("status") != "success":
            raise AssertionError(f"open_script_at_line failed: {open_script_result}")
        if open_script_result.get("caret_line") != 10:
            raise AssertionError(f"Script caret did not land on requested line: {open_script_result}")

        current_script = tool_call("get_current_script", {}, request_id=10)
        if current_script.get("script_path") != SCRIPT_PATH:
            raise AssertionError(f"Current script did not switch to requested file: {current_script}")

        create_temp_scene = tool_call(
            "create_scene",
            {"scene_path": TEMP_SCENE_PATH, "root_node_type": "Node"},
            request_id=11,
        )
        if create_temp_scene.get("status") != "success":
            raise AssertionError(f"create_scene failed: {create_temp_scene}")

        open_temp_scene = tool_call("open_scene", {"scene_path": TEMP_SCENE_PATH}, request_id=12)
        if open_temp_scene.get("status") != "success":
            raise AssertionError(f"open temp scene failed: {open_temp_scene}")

        open_scenes_before = tool_call("list_open_scenes", {}, request_id=13)
        scene_paths_before = {scene["scene_path"] for scene in open_scenes_before["open_scenes"]}
        if TEMP_SCENE_PATH not in scene_paths_before:
            raise AssertionError(f"Temporary scene was not listed as open: {open_scenes_before}")

        close_result = tool_call("close_scene_tab", {"scene_path": TEMP_SCENE_PATH}, request_id=14)
        if close_result.get("status") != "success":
            raise AssertionError(f"close_scene_tab failed: {close_result}")

        open_scenes_after = tool_call("list_open_scenes", {}, request_id=15)
        scene_paths_after = {scene["scene_path"] for scene in open_scenes_after["open_scenes"]}
        if TEMP_SCENE_PATH in scene_paths_after:
            raise AssertionError(f"Temporary scene still listed after close: {open_scenes_after}")

        print("editor automation tools flow verified")
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
