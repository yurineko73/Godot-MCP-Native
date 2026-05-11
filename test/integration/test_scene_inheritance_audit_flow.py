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
TEMP_DIR = REPO_ROOT / ".tmp_scene_inheritance_audit"
CHILD_SCENE_PATH = "res://.tmp_scene_inheritance_audit/child_scene.tscn"
PARENT_SCENE_PATH = "res://.tmp_scene_inheritance_audit/parent_scene.tscn"
CHILD_SCENE_FILE = TEMP_DIR / "child_scene.tscn"
PARENT_SCENE_FILE = TEMP_DIR / "parent_scene.tscn"

CHILD_SCENE_TEXT = """
[gd_scene format=3]

[node name="ChildScene" type="Node2D"]

[node name="BuiltInChild" type="Node2D" parent="."]
""".strip() + "\n"

PARENT_SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://.tmp_scene_inheritance_audit/child_scene.tscn" id="1_child"]

[node name="ParentScene" type="Node2D"]

[node name="ChildInstance" parent="." instance=ExtResource("1_child")]
[node name="LocalRootChild" type="Node2D" parent="."]
[node name="AddedUnderInstance" type="Node2D" parent="ChildInstance" owner="."]
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
    CHILD_SCENE_FILE.write_text(CHILD_SCENE_TEXT, encoding="utf-8")
    PARENT_SCENE_FILE.write_text(PARENT_SCENE_TEXT, encoding="utf-8")

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
        expected_tools = {"open_scene", "audit_scene_inheritance"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected inheritance audit tools: {missing_tools}")

        open_scene = tool_call("open_scene", {"scene_path": PARENT_SCENE_PATH}, request_id=2)
        if open_scene.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_scene}")

        audit = tool_call("audit_scene_inheritance", {}, request_id=3)
        if audit.get("scene_path") != PARENT_SCENE_PATH:
            raise AssertionError(f"Expected parent scene path in audit: {audit}")
        if audit.get("instance_root_count") != 1:
            raise AssertionError(f"Expected exactly one instance root: {audit}")

        nodes_by_path = {entry["node_path"]: entry for entry in audit.get("nodes", [])}
        child_instance = nodes_by_path.get("/root/ParentScene/ChildInstance")
        if not child_instance:
            raise AssertionError(f"Expected ChildInstance entry in inheritance audit: {audit}")
        if child_instance.get("relationship") != "instance_root":
            raise AssertionError(f"Expected ChildInstance to be an instance root: {child_instance}")
        if child_instance.get("source_scene_path") != CHILD_SCENE_PATH:
            raise AssertionError(f"Expected ChildInstance source scene path to match child scene: {child_instance}")

        built_in_child = nodes_by_path.get("/root/ParentScene/ChildInstance/BuiltInChild")
        if not built_in_child:
            raise AssertionError(f"Expected BuiltInChild entry in inheritance audit: {audit}")
        if built_in_child.get("relationship") != "inherited_content":
            raise AssertionError(f"Expected BuiltInChild to be inherited content: {built_in_child}")
        if built_in_child.get("instance_root_path") != "/root/ParentScene/ChildInstance":
            raise AssertionError(f"Expected BuiltInChild instance root path to point at ChildInstance: {built_in_child}")

        added_under_instance = nodes_by_path.get("/root/ParentScene/ChildInstance/AddedUnderInstance")
        if not added_under_instance:
            raise AssertionError(f"Expected AddedUnderInstance entry in inheritance audit: {audit}")
        if added_under_instance.get("relationship") != "local_override":
            raise AssertionError(f"Expected AddedUnderInstance to be a local override/addition: {added_under_instance}")

        local_root_child = nodes_by_path.get("/root/ParentScene/LocalRootChild")
        if not local_root_child:
            raise AssertionError(f"Expected LocalRootChild entry in inheritance audit: {audit}")
        if local_root_child.get("relationship") != "local":
            raise AssertionError(f"Expected LocalRootChild to be local scene content: {local_root_child}")

        print("scene inheritance audit flow verified")
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
