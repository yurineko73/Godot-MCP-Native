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
TEMP_DIR = REPO_ROOT / ".tmp_scene_persistence_audit"
TEMP_SCENE_PATH = "res://.tmp_scene_persistence_audit/temp_persistence_scene.tscn"


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
            "audit_scene_node_persistence",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected scene persistence audit tools: {missing_tools}")

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

        persistent_child = tool_call(
            "create_node",
            {"parent_path": "/root", "node_type": "Node2D", "node_name": "PersistentChild"},
            request_id=4,
        )
        if persistent_child.get("status") != "success":
            raise AssertionError(f"create_node failed: {persistent_child}")

        orphan_setup = tool_call(
            "execute_editor_script",
            {
                "code": """
var root = edited_scene
var orphan = Node2D.new()
orphan.name = "OrphanPreview"
root.add_child(orphan)
orphan.owner = null
_custom_print(str(orphan.get_path()))
""",
            },
            request_id=5,
        )
        if orphan_setup.get("success") is not True:
            raise AssertionError(f"execute_editor_script failed: {orphan_setup}")

        audit = tool_call("audit_scene_node_persistence", {}, request_id=6)
        if audit.get("scene_path") != TEMP_SCENE_PATH:
            raise AssertionError(f"Unexpected scene path in audit: {audit}")
        if audit.get("total_nodes") != 3:
            raise AssertionError(f"Expected three scene nodes in audit: {audit}")
        if audit.get("issue_count") != 1:
            raise AssertionError(f"Expected exactly one persistence issue: {audit}")

        issue = audit["issues"][0]
        if issue.get("node_path") != "/root/temp_persistence_scene/OrphanPreview":
            raise AssertionError(f"Unexpected issue node path: {issue}")
        if issue.get("issue_code") != "missing_owner":
            raise AssertionError(f"Unexpected issue code: {issue}")

        nodes_by_path = {entry["node_path"]: entry for entry in audit.get("nodes", [])}
        persistent_entry = nodes_by_path.get("/root/temp_persistence_scene/PersistentChild")
        orphan_entry = nodes_by_path.get("/root/temp_persistence_scene/OrphanPreview")
        if persistent_entry is None or orphan_entry is None:
            raise AssertionError(f"Missing expected node entries: {audit}")
        if persistent_entry.get("owner_path") != "/root/temp_persistence_scene":
            raise AssertionError(f"Persistent child should be owned by scene root: {persistent_entry}")
        if persistent_entry.get("is_persistent") is not True:
            raise AssertionError(f"Persistent child should be marked persistent: {persistent_entry}")
        if orphan_entry.get("owner_path") != "":
            raise AssertionError(f"Ownerless child should have empty owner path: {orphan_entry}")
        if orphan_entry.get("is_persistent") is not False:
            raise AssertionError(f"Ownerless child should not be marked persistent: {orphan_entry}")

        print("scene node persistence audit flow verified")
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
