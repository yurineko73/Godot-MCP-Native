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
TEMP_DIR = REPO_ROOT / ".tmp_batch_scene_node_edits"
TEMP_SCENE_PATH = "res://.tmp_batch_scene_node_edits/temp_batch_nodes_scene.tscn"


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
        expected_tools = {"batch_scene_node_edits", "execute_editor_script"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected batch scene node edit tools: {missing_tools}")

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

        seed_node = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "OldNode"},
            request_id=4,
        )
        if seed_node.get("status") != "success":
            raise AssertionError(f"create_node failed: {seed_node}")

        move_target = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "MoveTarget"},
            request_id=5,
        )
        if move_target.get("status") != "success":
            raise AssertionError(f"create_node failed: {move_target}")

        target_parent = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "TargetParent"},
            request_id=6,
        )
        if target_parent.get("status") != "success":
            raise AssertionError(f"create_node failed: {target_parent}")

        delete_me = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "DeleteMe"},
            request_id=7,
        )
        if delete_me.get("status") != "success":
            raise AssertionError(f"create_node failed: {delete_me}")

        batch_result = tool_call(
            "batch_scene_node_edits",
            {
                "label": "Batch Scene Node Edits",
                "operations": [
                    {
                        "type": "create",
                        "parent_path": "/root",
                        "node_type": "Node2D",
                        "node_name": "NewNode",
                    },
                    {
                        "type": "rename",
                        "node_path": "/root/temp_batch_nodes_scene/OldNode",
                        "new_name": "RenamedOld",
                    },
                    {
                        "type": "move",
                        "node_path": "/root/temp_batch_nodes_scene/MoveTarget",
                        "new_parent_path": "/root/temp_batch_nodes_scene/TargetParent",
                    },
                    {
                        "type": "delete",
                        "node_path": "/root/temp_batch_nodes_scene/DeleteMe",
                    },
                ],
            },
            request_id=8,
        )
        if batch_result.get("status") != "success":
            raise AssertionError(f"batch_scene_node_edits failed: {batch_result}")
        if batch_result.get("operation_count") != 4:
            raise AssertionError(f"Expected four batch scene node operations: {batch_result}")

        post_batch = tool_call("list_nodes", {"recursive": True}, request_id=9)
        post_nodes = set(post_batch.get("nodes", []))
        if "/root/temp_batch_nodes_scene/NewNode" not in post_nodes:
            raise AssertionError(f"Expected NewNode to exist after batch create: {post_batch}")
        if "/root/temp_batch_nodes_scene/RenamedOld" not in post_nodes:
            raise AssertionError(f"Expected OldNode to be renamed after batch edit: {post_batch}")
        if "/root/temp_batch_nodes_scene/OldNode" in post_nodes:
            raise AssertionError(f"Expected OldNode path to be absent after batch edit: {post_batch}")
        if "/root/temp_batch_nodes_scene/TargetParent/MoveTarget" not in post_nodes:
            raise AssertionError(f"Expected MoveTarget to be moved under TargetParent: {post_batch}")
        if "/root/temp_batch_nodes_scene/MoveTarget" in post_nodes:
            raise AssertionError(f"Expected MoveTarget to be absent from scene root after move: {post_batch}")
        if "/root/temp_batch_nodes_scene/DeleteMe" in post_nodes:
            raise AssertionError(f"Expected DeleteMe to be deleted by batch edit: {post_batch}")

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
var old_exists = scene_root.get_node_or_null("OldNode") != null
var renamed_old_exists = scene_root.get_node_or_null("RenamedOld") != null
var new_exists = scene_root.get_node_or_null("NewNode") != null
var moved_back = scene_root.get_node_or_null("MoveTarget") != null
var moved_child_exists = scene_root.get_node("TargetParent").get_node_or_null("MoveTarget") != null
var delete_me_exists = scene_root.get_node_or_null("DeleteMe") != null
_custom_print(JSON.stringify({
    "old_exists": old_exists,
    "renamed_old_exists": renamed_old_exists,
    "new_exists": new_exists,
    "moved_back": moved_back,
    "moved_child_exists": moved_child_exists,
    "delete_me_exists": delete_me_exists
}))
""",
            },
            request_id=10,
        )
        if undo_check.get("success") is not True or not undo_check.get("output"):
            raise AssertionError(f"execute_editor_script failed: {undo_check}")
        undo_state = json.loads(undo_check["output"][-1])
        expected_undo_state = {
            "old_exists": True,
            "renamed_old_exists": False,
            "new_exists": False,
            "moved_back": True,
            "moved_child_exists": False,
            "delete_me_exists": True,
        }
        if undo_state != expected_undo_state:
            raise AssertionError(f"Expected undo to restore the original structure: {undo_state}")

        print("batch scene node edits flow verified")
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
