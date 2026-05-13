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
SECOND_TEMP_SCENE_PATH = "res://.tmp_editor_tools/temp_editor_scene_second.tscn"
SAVE_AS_TEMP_SCENE_PATH = "res://.tmp_editor_tools/temp_editor_scene_saved_as.tscn"
TEMP_SCENE_FILE = TEMP_DIR / "temp_editor_scene.tscn"
SECOND_TEMP_SCENE_FILE = TEMP_DIR / "temp_editor_scene_second.tscn"
SAVE_AS_TEMP_SCENE_FILE = TEMP_DIR / "temp_editor_scene_saved_as.tscn"
SCRIPT_PATH = "res://addons/godot_mcp/tools/project_tools_native.gd"

RELOADED_SCENE_TEXT = """
[gd_scene format=3]

[node name="ReloadedSceneRoot" type="Node2D"]

[node name="ReloadedChild" type="Node" parent="."]
""".strip() + "\n"


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
            "create_node",
            "get_scene_tree",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected editor automation tools: {missing_tools}")

        project_info = tool_call("get_project_info", request_id=2)
        main_scene = project_info["main_scene"]
        if not main_scene:
            raise AssertionError("Project has no main scene configured")

        open_main_result = tool_call(
            "open_scene",
            {"scene_path": main_scene, "allow_ui_focus": True},
            request_id=3,
        )
        if open_main_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_main_result}")

        current_scene = tool_call("get_current_scene", {}, request_id=4)
        root_path = f"/root/{current_scene['scene_name']}"

        select_result = tool_call(
            "select_node",
            {"node_path": root_path, "allow_ui_focus": True},
            request_id=5,
        )
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

        file_select_result = tool_call(
            "select_file",
            {"file_path": main_scene, "allow_ui_focus": True},
            request_id=8,
        )
        if file_select_result.get("status") != "success":
            raise AssertionError(f"select_file failed: {file_select_result}")

        open_script_result = tool_call(
            "open_script_at_line",
            {"script_path": SCRIPT_PATH, "line": 10, "column": 0, "allow_ui_focus": True},
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

        open_temp_scene = tool_call(
            "open_scene",
            {"scene_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=12,
        )
        if open_temp_scene.get("status") != "success":
            raise AssertionError(f"open temp scene failed: {open_temp_scene}")

        temp_scene = tool_call("get_current_scene", {}, request_id=120)
        temp_root_path = f"/root/{temp_scene['scene_name']}"

        create_child = tool_call(
            "create_node",
            {"parent_path": temp_root_path, "node_type": "Node", "node_name": "Child"},
            request_id=121,
        )
        if create_child.get("status") != "success":
            raise AssertionError(f"create child node failed: {create_child}")

        create_grandchild = tool_call(
            "create_node",
            {"parent_path": temp_root_path + "/Child", "node_type": "Node", "node_name": "Grandchild"},
            request_id=122,
        )
        if create_grandchild.get("status") != "success":
            raise AssertionError(f"create grandchild node failed: {create_grandchild}")

        truncated_tree = tool_call("get_scene_tree", {"max_depth": 1}, request_id=123)
        if truncated_tree.get("truncated") is not True:
            raise AssertionError(f"Expected truncated scene tree metadata: {truncated_tree}")
        if truncated_tree.get("max_depth_applied") != 1:
            raise AssertionError(f"Expected echoed max depth metadata: {truncated_tree}")
        if truncated_tree.get("next_max_depth") != 2:
            raise AssertionError(f"Expected continuation metadata for scene tree: {truncated_tree}")
        root_children = truncated_tree.get("tree", {}).get("children", [])
        if len(root_children) != 1 or root_children[0].get("children_truncated") is not True:
            raise AssertionError(f"Expected child truncation marker in scene tree: {truncated_tree}")

        list_nodes_page_1 = tool_call("list_nodes", {"recursive": True, "max_items": 2}, request_id=124)
        if list_nodes_page_1.get("truncated") is not True or list_nodes_page_1.get("has_more") is not True:
            raise AssertionError(f"Expected paged list_nodes metadata on first page: {list_nodes_page_1}")
        if list_nodes_page_1.get("count") != 2 or list_nodes_page_1.get("total_available", 0) < 3:
            raise AssertionError(f"Unexpected first list_nodes page sizing: {list_nodes_page_1}")
        next_cursor = list_nodes_page_1.get("next_cursor")
        if not isinstance(next_cursor, int) or next_cursor <= 0:
            raise AssertionError(f"Expected integer next_cursor from first list_nodes page: {list_nodes_page_1}")

        list_nodes_page_2 = tool_call(
            "list_nodes",
            {"recursive": True, "max_items": 2, "cursor": next_cursor},
            request_id=125,
        )
        if list_nodes_page_2.get("has_more") is not False or list_nodes_page_2.get("truncated") is not False:
            raise AssertionError(f"Expected final list_nodes page to be complete: {list_nodes_page_2}")
        if list_nodes_page_2.get("count", 0) < 1:
            raise AssertionError(f"Expected trailing list_nodes page to contain remaining nodes: {list_nodes_page_2}")

        TEMP_SCENE_FILE.write_text(RELOADED_SCENE_TEXT, encoding="utf-8")
        reload_temp_scene = tool_call(
            "open_scene",
            {
                "scene_path": TEMP_SCENE_PATH,
                "reload_from_disk": True,
                "allow_ui_focus": True,
            },
            request_id=126,
        )
        if reload_temp_scene.get("status") != "success":
            raise AssertionError(f"reload temp scene failed: {reload_temp_scene}")
        if reload_temp_scene.get("root_node_type") != "Node2D":
            raise AssertionError(f"Reloaded scene did not report the updated root type: {reload_temp_scene}")

        reloaded_scene = tool_call("get_current_scene", {}, request_id=127)
        if reloaded_scene.get("scene_name") != "ReloadedSceneRoot":
            raise AssertionError(f"Reloaded scene did not pick up the updated root name: {reloaded_scene}")
        if reloaded_scene.get("root_node_type") != "Node2D":
            raise AssertionError(f"Reloaded scene did not pick up the updated root type: {reloaded_scene}")
        if reloaded_scene.get("node_count") != 2:
            raise AssertionError(f"Reloaded scene did not pick up the updated node count: {reloaded_scene}")

        reloaded_tree = tool_call("get_scene_tree", {"max_depth": 2}, request_id=128)
        if reloaded_tree.get("scene_name") != "ReloadedSceneRoot":
            raise AssertionError(f"Reloaded scene tree did not pick up the updated root name: {reloaded_tree}")
        reloaded_children = reloaded_tree.get("tree", {}).get("children", [])
        if len(reloaded_children) != 1 or reloaded_children[0].get("name") != "ReloadedChild":
            raise AssertionError(f"Reloaded scene tree did not pick up the updated child structure: {reloaded_tree}")

        create_second_scene = tool_call(
            "create_scene",
            {"scene_path": SECOND_TEMP_SCENE_PATH, "root_node_type": "Node"},
            request_id=129,
        )
        if create_second_scene.get("status") != "success":
            raise AssertionError(f"create second scene failed: {create_second_scene}")

        open_second_scene = tool_call(
            "open_scene",
            {"scene_path": SECOND_TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=130,
        )
        if open_second_scene.get("status") != "success":
            raise AssertionError(f"open second temp scene failed: {open_second_scene}")

        second_scene = tool_call("get_current_scene", {}, request_id=131)
        second_root_path = f"/root/{second_scene['scene_name']}"
        create_second_child = tool_call(
            "create_node",
            {"parent_path": second_root_path, "node_type": "Node", "node_name": "SecondChild"},
            request_id=132,
        )
        if create_second_child.get("status") != "success":
            raise AssertionError(f"create second child node failed: {create_second_child}")

        open_first_scene_again = tool_call(
            "open_scene",
            {"scene_path": TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=133,
        )
        if open_first_scene_again.get("status") != "success":
            raise AssertionError(f"reopen first temp scene before save-all failed: {open_first_scene_again}")

        reloaded_first_scene = tool_call("get_current_scene", {}, request_id=1331)
        reloaded_first_root_path = f"/root/{reloaded_first_scene['scene_name']}"
        create_first_saved_child = tool_call(
            "create_node",
            {"parent_path": reloaded_first_root_path, "node_type": "Node", "node_name": "FirstSavedChild"},
            request_id=1332,
        )
        if create_first_saved_child.get("status") != "success":
            raise AssertionError(f"create first saved child node failed: {create_first_saved_child}")

        save_all_result = tool_call(
            "save_scene",
            {"save_all_open_scenes": True},
            request_id=134,
        )
        if save_all_result.get("status") != "success":
            raise AssertionError(f"save_scene(save_all_open_scenes=true) failed: {save_all_result}")
        if save_all_result.get("saved_all_open_scenes") is not True:
            raise AssertionError(f"Expected save-all branch to report saved_all_open_scenes=true: {save_all_result}")
        if save_all_result.get("saved_scene_count", 0) < 2:
            raise AssertionError(f"Expected at least two open scenes to be saved by save-all: {save_all_result}")

        first_saved_text = TEMP_SCENE_FILE.read_text(encoding="utf-8")
        second_saved_text = SECOND_TEMP_SCENE_FILE.read_text(encoding="utf-8")
        if "ReloadedSceneRoot" not in first_saved_text or "ReloadedChild" not in first_saved_text or "FirstSavedChild" not in first_saved_text:
            raise AssertionError("save_all_open_scenes did not persist the first modified open scene to disk")
        if "temp_editor_scene_second" not in second_saved_text or "SecondChild" not in second_saved_text:
            raise AssertionError("save_all_open_scenes did not persist the second modified open scene to disk")

        save_as_child = tool_call(
            "create_node",
            {"parent_path": reloaded_first_root_path, "node_type": "Node", "node_name": "SaveAsChild"},
            request_id=135,
        )
        if save_as_child.get("status") != "success":
            raise AssertionError(f"create save-as child node failed: {save_as_child}")

        save_as_result = tool_call(
            "save_scene",
            {
                "file_path": SAVE_AS_TEMP_SCENE_PATH,
                "use_editor_save_as": True,
            },
            request_id=136,
        )
        if save_as_result.get("status") != "success":
            raise AssertionError(f"save_scene(use_editor_save_as=true) failed: {save_as_result}")
        if save_as_result.get("saved_path") != SAVE_AS_TEMP_SCENE_PATH:
            raise AssertionError(f"Expected save-as branch to echo the new saved path: {save_as_result}")
        if save_as_result.get("saved_all_open_scenes") is not False or save_as_result.get("saved_scene_count") != 1:
            raise AssertionError(f"Expected save-as branch to report a single-scene save: {save_as_result}")
        if not SAVE_AS_TEMP_SCENE_FILE.exists() or SAVE_AS_TEMP_SCENE_FILE.stat().st_size <= 0:
            raise AssertionError("Expected save-as branch to create a new scene file on disk")

        saved_as_scene = tool_call("get_current_scene", {}, request_id=137)
        if saved_as_scene.get("scene_path") != SAVE_AS_TEMP_SCENE_PATH:
            raise AssertionError(f"Expected current scene path to switch to the save-as destination: {saved_as_scene}")
        saved_as_text = SAVE_AS_TEMP_SCENE_FILE.read_text(encoding="utf-8")
        if "SaveAsChild" not in saved_as_text or "ReloadedChild" not in saved_as_text:
            raise AssertionError("save_scene(use_editor_save_as=true) did not persist the active scene into the new destination file")

        open_scenes_before = tool_call("list_open_scenes", {}, request_id=13)
        scene_paths_before = {scene["scene_path"] for scene in open_scenes_before["open_scenes"]}
        if TEMP_SCENE_PATH in scene_paths_before:
            raise AssertionError(f"Expected original path to be replaced after save-as: {open_scenes_before}")
        if SECOND_TEMP_SCENE_PATH not in scene_paths_before or SAVE_AS_TEMP_SCENE_PATH not in scene_paths_before:
            raise AssertionError(f"Temporary scene was not listed as open: {open_scenes_before}")

        open_scenes_after = tool_call("list_open_scenes", {}, request_id=15)
        scene_paths_after = {scene["scene_path"] for scene in open_scenes_after["open_scenes"]}
        if SECOND_TEMP_SCENE_PATH not in scene_paths_after or SAVE_AS_TEMP_SCENE_PATH not in scene_paths_after:
            raise AssertionError(f"Expected both surviving open scenes to remain listed before close cleanup: {open_scenes_after}")

        close_second_result = tool_call(
            "close_scene_tab",
            {"scene_path": SECOND_TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=16,
        )
        if close_second_result.get("status") != "success":
            raise AssertionError(f"close second scene tab failed: {close_second_result}")

        close_saved_as_result = tool_call(
            "close_scene_tab",
            {"scene_path": SAVE_AS_TEMP_SCENE_PATH, "allow_ui_focus": True},
            request_id=17,
        )
        if close_saved_as_result.get("status") != "success":
            raise AssertionError(f"close saved-as scene tab failed: {close_saved_as_result}")

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
