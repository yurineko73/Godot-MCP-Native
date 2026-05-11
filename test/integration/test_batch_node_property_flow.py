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
TEMP_DIR = REPO_ROOT / ".tmp_batch_node_properties"
TEMP_SCENE_PATH = "res://.tmp_batch_node_properties/temp_batch_scene.tscn"


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
            "batch_update_node_properties",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected batch node property tools: {missing_tools}")

        create_scene = tool_call(
            "create_scene",
            {"scene_path": TEMP_SCENE_PATH, "root_node_type": "Node2D"},
            request_id=2,
        )
        if create_scene.get("status") != "success":
            raise AssertionError(f"create_scene failed: {create_scene}")

        open_scene = tool_call("open_scene", {"scene_path": TEMP_SCENE_PATH}, request_id=3)
        if open_scene.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_scene}")

        mover = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "Mover"},
            request_id=4,
        )
        pivot = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "Pivot"},
            request_id=5,
        )
        if mover.get("status") != "success" or pivot.get("status") != "success":
            raise AssertionError(f"create_node failed: {mover} / {pivot}")

        batch_result = tool_call(
            "batch_update_node_properties",
            {
                "label": "Batch Property Test",
                "changes": [
                    {
                        "node_path": "/root/temp_batch_scene/Mover",
                        "property_name": "position",
                        "property_value": {"x": 12, "y": 24},
                    },
                    {
                        "node_path": "/root/temp_batch_scene/Pivot",
                        "property_name": "visible",
                        "property_value": False,
                    },
                ],
            },
            request_id=6,
        )
        if batch_result.get("status") != "success":
            raise AssertionError(f"batch_update_node_properties failed: {batch_result}")
        if batch_result.get("change_count") != 2:
            raise AssertionError(f"Expected two property changes: {batch_result}")

        mover_props = tool_call("get_node_properties", {"node_path": "/root/temp_batch_scene/Mover"}, request_id=7)
        pivot_props = tool_call("get_node_properties", {"node_path": "/root/temp_batch_scene/Pivot"}, request_id=8)
        if mover_props["properties"].get("position") != {"x": 12.0, "y": 24.0}:
            raise AssertionError(f"Mover position was not updated: {mover_props}")
        if pivot_props["properties"].get("visible") is not False:
            raise AssertionError(f"Pivot visible flag was not updated: {pivot_props}")

        undo_check = tool_call(
            "execute_editor_script",
            {
                "code": """
var plugin = Engine.get_meta("GodotMCPPlugin")
var editor_interface = plugin.get_editor_interface()
var scene_root = editor_interface.get_edited_scene_root()
var undo_redo_mgr = editor_interface.get_editor_undo_redo()
var history_id = undo_redo_mgr.get_object_history_id(scene_root)
var undo_redo = undo_redo_mgr.get_history_undo_redo(history_id)
undo_redo.undo()
var mover = scene_root.get_node("Mover")
var pivot = scene_root.get_node("Pivot")
_custom_print(JSON.stringify({
    "position": {"x": mover.position.x, "y": mover.position.y},
    "visible": pivot.visible
}))
""",
            },
            request_id=9,
        )
        if undo_check.get("success") is not True or not undo_check.get("output"):
            raise AssertionError(f"execute_editor_script failed: {undo_check}")
        undo_state = json.loads(undo_check["output"][-1])
        if undo_state.get("position") != {"x": 0.0, "y": 0.0}:
            raise AssertionError(f"Expected undo to restore Mover position: {undo_state}")
        if undo_state.get("visible") is not True:
            raise AssertionError(f"Expected undo to restore Pivot visibility: {undo_state}")

        print("batch node property flow verified")
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
