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
TEMP_DIR = REPO_ROOT / ".tmp_project_class_metadata"
AUTOLOAD_NAME = "MCPTempAutoload"
GLOBAL_CLASS_NAME = "ProjectToolsNative"
GLOBAL_CLASS_SCRIPT_PATH = "res://addons/godot_mcp/tools/project_tools_native.gd"
AUTOLOAD_SCRIPT_PATH = "res://.tmp_project_class_metadata/temp_autoload.gd"
AUTOLOAD_SCRIPT_FILE = TEMP_DIR / "temp_autoload.gd"

AUTOLOAD_SCRIPT_TEXT = """
extends Node
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


def execute_editor_script(code: str, request_id: int) -> dict:
    return tool_call("execute_editor_script", {"code": code}, request_id=request_id)


def refresh_editor_filesystem(request_id: int) -> None:
    result = execute_editor_script(
        """
var fs = EditorInterface.get_resource_filesystem()
if fs:
	fs.scan()
	fs.scan_sources()
_custom_print(JSON.stringify({"ok": true}))
""",
        request_id=request_id,
    )
    if result.get("success") is not True:
        raise AssertionError(f"Filesystem refresh failed: {result}")


def set_temporary_autoload(request_id: int) -> None:
    result = execute_editor_script(
        f"""
ProjectSettings.set_setting("autoload/{AUTOLOAD_NAME}", "*{AUTOLOAD_SCRIPT_PATH}")
ProjectSettings.save()
_custom_print(JSON.stringify({{"ok": true, "exists": ProjectSettings.has_setting("autoload/{AUTOLOAD_NAME}")}}))
""",
        request_id=request_id,
    )
    if result.get("success") is not True or not result.get("output"):
        raise AssertionError(f"Failed to create temporary autoload: {result}")
    payload = json.loads(result["output"][-1])
    if payload.get("exists") is not True:
        raise AssertionError(f"Temporary autoload was not created: {payload}")


def remove_temporary_autoload(request_id: int) -> None:
    try:
        result = execute_editor_script(
            f"""
if ProjectSettings.has_setting("autoload/{AUTOLOAD_NAME}"):
	ProjectSettings.set_setting("autoload/{AUTOLOAD_NAME}", null)
	ProjectSettings.save()
_custom_print(JSON.stringify({{"exists": ProjectSettings.has_setting("autoload/{AUTOLOAD_NAME}")}}))
""",
            request_id=request_id,
        )
        if result.get("success") is True and result.get("output"):
            payload = json.loads(result["output"][-1])
            if payload.get("exists") is True:
                raise AssertionError(f"Temporary autoload still exists after cleanup: {payload}")
    except Exception:
        pass


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    AUTOLOAD_SCRIPT_FILE.write_text(AUTOLOAD_SCRIPT_TEXT, encoding="utf-8")

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
            "list_project_autoloads",
            "list_project_global_classes",
            "get_class_api_metadata",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected class metadata tools: {missing_tools}")

        refresh_editor_filesystem(request_id=2)
        set_temporary_autoload(request_id=3)

        autoload_result = tool_call("list_project_autoloads", {"filter": AUTOLOAD_NAME}, request_id=4)
        if autoload_result.get("count") != 1:
            raise AssertionError(f"Expected one filtered autoload entry: {autoload_result}")
        autoload_entry = autoload_result["autoloads"][0]
        if autoload_entry.get("name") != AUTOLOAD_NAME:
            raise AssertionError(f"Unexpected autoload entry name: {autoload_entry}")
        if autoload_entry.get("path") != AUTOLOAD_SCRIPT_PATH:
            raise AssertionError(f"Unexpected autoload entry path: {autoload_entry}")
        if autoload_entry.get("is_singleton") is not True:
            raise AssertionError(f"Expected temporary autoload to be singleton: {autoload_entry}")

        global_classes = tool_call("list_project_global_classes", {"filter": GLOBAL_CLASS_NAME}, request_id=5)
        if global_classes.get("count", 0) < 1:
            raise AssertionError(f"Expected {GLOBAL_CLASS_NAME} global class entry: {global_classes}")
        class_entry = next((entry for entry in global_classes.get("classes", []) if entry.get("name") == GLOBAL_CLASS_NAME), None)
        if class_entry is None:
            raise AssertionError(f"{GLOBAL_CLASS_NAME} not present in filtered global class list: {global_classes}")
        if class_entry.get("path") != GLOBAL_CLASS_SCRIPT_PATH:
            raise AssertionError(f"Unexpected global class path: {class_entry}")
        if class_entry.get("base") != "RefCounted":
            raise AssertionError(f"Unexpected global class base type: {class_entry}")
        if class_entry.get("language") != "GDScript":
            raise AssertionError(f"Unexpected global class language: {class_entry}")

        class_api = tool_call(
            "get_class_api_metadata",
            {"class_name": GLOBAL_CLASS_NAME, "include_base_api": True},
            request_id=20,
        )
        if class_api.get("source") != "global_class":
            raise AssertionError(f"Expected global class API metadata source: {class_api}")
        if class_api.get("script_path") != GLOBAL_CLASS_SCRIPT_PATH:
            raise AssertionError(f"Unexpected global class script path: {class_api}")
        method_names = {entry.get("name") for entry in class_api.get("methods", [])}
        if "initialize" not in method_names:
            raise AssertionError(f"Expected initialize in ProjectToolsNative methods: {class_api}")
        if class_api.get("base_api", {}).get("class_name") != "RefCounted":
            raise AssertionError(f"Expected base API metadata for RefCounted: {class_api}")

        node_api = tool_call(
            "get_class_api_metadata",
            {"class_name": "Node", "filter": "process"},
            request_id=21,
        )
        if node_api.get("source") != "classdb":
            raise AssertionError(f"Expected classdb metadata source for Node: {node_api}")
        if not node_api.get("methods"):
            raise AssertionError(f"Expected filtered Node methods to be present: {node_api}")
        if not all("process" in str(entry.get("name", "")).lower() for entry in node_api.get("methods", [])):
            raise AssertionError(f"Expected Node method filter to apply: {node_api}")

        print("project class metadata flow verified")
        return 0
    finally:
        remove_temporary_autoload(request_id=99)
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
