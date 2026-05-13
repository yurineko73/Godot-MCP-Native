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

        open_scene = tool_call(
            "open_scene",
            {"scene_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=3,
        )
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

        mover_groups = tool_call(
            "set_node_groups",
            {"node_path": "/root/temp_batch_scene/Mover", "groups": ["paged_group"]},
            request_id=61,
        )
        pivot_groups = tool_call(
            "set_node_groups",
            {"node_path": "/root/temp_batch_scene/Pivot", "groups": ["paged_group"]},
            request_id=62,
        )
        extra = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "Extra"},
            request_id=63,
        )
        extra_groups = tool_call(
            "set_node_groups",
            {"node_path": "/root/temp_batch_scene/Extra", "groups": ["paged_group"]},
            request_id=64,
        )
        if mover_groups.get("status") != "success" or pivot_groups.get("status") != "success" or extra.get("status") != "success" or extra_groups.get("status") != "success":
            raise AssertionError(f"Failed to prepare paged group fixtures: {mover_groups} / {pivot_groups} / {extra} / {extra_groups}")

        mover_props = tool_call("get_node_properties", {"node_path": "/root/temp_batch_scene/Mover"}, request_id=7)
        pivot_props = tool_call("get_node_properties", {"node_path": "/root/temp_batch_scene/Pivot"}, request_id=8)
        if mover_props["properties"].get("position") != {"x": 12.0, "y": 24.0}:
            raise AssertionError(f"Mover position was not updated: {mover_props}")
        if pivot_props["properties"].get("visible") is not False:
            raise AssertionError(f"Pivot visible flag was not updated: {pivot_props}")

        mover_props_page_1 = tool_call(
            "get_node_properties",
            {"node_path": "/root/temp_batch_scene/Mover", "max_properties": 2},
            request_id=81,
        )
        if mover_props_page_1.get("truncated") is not True or mover_props_page_1.get("has_more") is not True:
            raise AssertionError(f"Expected paged get_node_properties metadata on first page: {mover_props_page_1}")
        if mover_props_page_1.get("count") != 2 or mover_props_page_1.get("total_available", 0) <= 2:
            raise AssertionError(f"Unexpected first get_node_properties page sizing: {mover_props_page_1}")
        next_cursor = mover_props_page_1.get("next_cursor")
        if not isinstance(next_cursor, int):
            raise AssertionError(f"Expected integer next_cursor from first property page: {mover_props_page_1}")

        mover_props_page_2 = tool_call(
            "get_node_properties",
            {"node_path": "/root/temp_batch_scene/Mover", "max_properties": 2, "cursor": next_cursor},
            request_id=82,
        )
        if mover_props_page_2.get("count", 0) < 1 or mover_props_page_2.get("count", 0) > 2:
            raise AssertionError(f"Expected continuation get_node_properties page to stay within max_properties: {mover_props_page_2}")
        if mover_props_page_2.get("properties") == mover_props_page_1.get("properties"):
            raise AssertionError(f"Expected continuation get_node_properties page to advance beyond the first window: {mover_props_page_2}")

        final_cursor = mover_props_page_1.get("total_available", 0) - 1
        mover_props_last_page = tool_call(
            "get_node_properties",
            {"node_path": "/root/temp_batch_scene/Mover", "max_properties": 2, "cursor": final_cursor},
            request_id=83,
        )
        if mover_props_last_page.get("has_more") is not False or mover_props_last_page.get("truncated") is not False:
            raise AssertionError(f"Expected last get_node_properties page to be complete: {mover_props_last_page}")
        if mover_props_last_page.get("count") != 1:
            raise AssertionError(f"Expected last get_node_properties page to contain exactly one trailing property: {mover_props_last_page}")

        group_page_1 = tool_call(
            "find_nodes_in_group",
            {"group": "paged_group", "max_items": 2},
            request_id=84,
        )
        if group_page_1.get("truncated") is not True or group_page_1.get("has_more") is not True:
            raise AssertionError(f"Expected paged find_nodes_in_group metadata on first page: {group_page_1}")
        if group_page_1.get("node_count") != 2 or group_page_1.get("total_available", 0) != 3:
            raise AssertionError(f"Unexpected first find_nodes_in_group page sizing: {group_page_1}")
        group_next_cursor = group_page_1.get("next_cursor")
        if not isinstance(group_next_cursor, int):
            raise AssertionError(f"Expected integer next_cursor from first group page: {group_page_1}")

        group_last_page = tool_call(
            "find_nodes_in_group",
            {"group": "paged_group", "max_items": 2, "cursor": group_next_cursor},
            request_id=85,
        )
        if group_last_page.get("has_more") is not False or group_last_page.get("truncated") is not False:
            raise AssertionError(f"Expected last find_nodes_in_group page to be complete: {group_last_page}")
        if group_last_page.get("node_count") != 1:
            raise AssertionError(f"Expected last find_nodes_in_group page to contain one trailing node: {group_last_page}")

        extra_more_groups = tool_call(
            "set_node_groups",
            {
                "node_path": "/root/temp_batch_scene/Extra",
                "groups": ["group_alpha", "group_beta", "group_gamma"],
            },
            request_id=86,
        )
        if extra_more_groups.get("status") != "success":
            raise AssertionError(f"Failed to prepare paged get_node_groups fixture: {extra_more_groups}")

        groups_page_1 = tool_call(
            "get_node_groups",
            {"node_path": "/root/temp_batch_scene/Extra", "max_items": 2},
            request_id=87,
        )
        if groups_page_1.get("truncated") is not True or groups_page_1.get("has_more") is not True:
            raise AssertionError(f"Expected paged get_node_groups metadata on first page: {groups_page_1}")
        if groups_page_1.get("group_count") != 2 or groups_page_1.get("total_available", 0) < 4:
            raise AssertionError(f"Unexpected first get_node_groups page sizing: {groups_page_1}")
        groups_next_cursor = groups_page_1.get("next_cursor")
        if not isinstance(groups_next_cursor, int):
            raise AssertionError(f"Expected integer next_cursor from first get_node_groups page: {groups_page_1}")

        groups_last_page = tool_call(
            "get_node_groups",
            {"node_path": "/root/temp_batch_scene/Extra", "max_items": 2, "cursor": groups_next_cursor + 1},
            request_id=88,
        )
        if groups_last_page.get("has_more") is not False or groups_last_page.get("truncated") is not False:
            raise AssertionError(f"Expected last get_node_groups page to be complete: {groups_last_page}")
        if groups_last_page.get("group_count") != 1:
            raise AssertionError(f"Expected last get_node_groups page to contain one trailing group: {groups_last_page}")

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
