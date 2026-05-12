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
TEMP_DIR = REPO_ROOT / ".tmp_resource_tools"
TEMP_RESOURCE_PATH = "res://.tmp_resource_tools/integration_resource.tres"
TEMP_RESOURCE_FILE = TEMP_DIR / "integration_resource.tres"
MISSING_SCENE_PATH = "res://.tmp_resource_tools/missing_dependency_scene.tscn"
MISSING_SCENE_FILE = TEMP_DIR / "missing_dependency_scene.tscn"
IMPORTED_ASSET_PATH = "res://addons/godot_mcp/icon.svg"

MISSING_SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_resource_tools/missing_script.gd" id="1_missing"]

[node name="MissingDependencyScene" type="Node"]
script = ExtResource("1_missing")
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


def wait_for_editor_scene_state_to_stabilize(delay_seconds: float = 3.0) -> None:
    time.sleep(delay_seconds)


def wait_for_reimport(resource_path: str, timeout_seconds: float = 45.0, start_request_id: int = 700) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call(
            "reimport_resources",
            {"resource_paths": [resource_path]},
            request_id=request_id,
        )
        if last_result.get("status") == "success":
            return last_result
        if last_result.get("status") != "busy":
            raise AssertionError(f"Unexpected reimport_resources result: {last_result}")
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Timed out waiting for reimport_resources to become available: {last_result}")


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    MISSING_SCENE_FILE.write_text(MISSING_SCENE_TEXT, encoding="utf-8")

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
        wait_for_editor_scene_state_to_stabilize()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "reimport_resources",
            "get_import_metadata",
            "get_resource_uid_info",
            "fix_resource_uid",
            "get_resource_dependencies",
            "scan_missing_resource_dependencies",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected resource pipeline tools: {missing_tools}")

        create_result = tool_call(
            "create_resource",
            {
                "resource_path": TEMP_RESOURCE_PATH,
                "resource_type": "Curve",
            },
            request_id=2,
        )
        if create_result.get("status") != "success":
            raise AssertionError(f"create_resource failed: {create_result}")
        if not TEMP_RESOURCE_FILE.exists():
            raise AssertionError(f"Expected temp resource file at {TEMP_RESOURCE_FILE}")

        uid_before = tool_call(
            "get_resource_uid_info",
            {"resource_path": TEMP_RESOURCE_PATH},
            request_id=3,
        )
        if uid_before.get("resource_path") != TEMP_RESOURCE_PATH:
            raise AssertionError(f"Unexpected UID info payload: {uid_before}")

        uid_fix = tool_call(
            "fix_resource_uid",
            {"resource_path": TEMP_RESOURCE_PATH},
            request_id=4,
        )
        if uid_fix.get("status") != "success":
            raise AssertionError(f"fix_resource_uid failed: {uid_fix}")
        if not str(uid_fix.get("uid", "")).startswith("uid://"):
            raise AssertionError(f"fix_resource_uid did not produce a uid:// mapping: {uid_fix}")

        uid_after = tool_call(
            "get_resource_uid_info",
            {"resource_path": TEMP_RESOURCE_PATH},
            request_id=5,
        )
        if not uid_after.get("has_uid_mapping"):
            raise AssertionError(f"Expected UID mapping after repair: {uid_after}")

        import_metadata = tool_call(
            "get_import_metadata",
            {"resource_path": IMPORTED_ASSET_PATH},
            request_id=6,
        )
        if not import_metadata.get("exists"):
            raise AssertionError(f"Expected import metadata for {IMPORTED_ASSET_PATH}: {import_metadata}")
        if not import_metadata.get("import_config_path", "").endswith(".import"):
            raise AssertionError(f"Unexpected import metadata path: {import_metadata}")

        reimport_result = wait_for_reimport(IMPORTED_ASSET_PATH, start_request_id=7)
        if reimport_result.get("status") != "success":
            raise AssertionError(f"reimport_resources failed: {reimport_result}")
        if reimport_result.get("reimported_count") != 1:
            raise AssertionError(f"Expected exactly one reimported path: {reimport_result}")

        dependency_result = tool_call(
            "get_resource_dependencies",
            {"resource_path": MISSING_SCENE_PATH},
            request_id=8,
        )
        if dependency_result.get("dependency_count", 0) < 1:
            raise AssertionError(f"Expected at least one dependency: {dependency_result}")
        if not any(dependency.get("missing") for dependency in dependency_result["dependencies"]):
            raise AssertionError(f"Expected a missing dependency in scene payload: {dependency_result}")

        missing_scan = tool_call(
            "scan_missing_resource_dependencies",
            {"search_path": "res://.tmp_resource_tools", "max_results": 20},
            request_id=9,
        )
        if missing_scan.get("issue_count", 0) < 1:
            raise AssertionError(f"Expected at least one missing dependency issue: {missing_scan}")
        if not any(issue.get("owner_path") == MISSING_SCENE_PATH for issue in missing_scan["issues"]):
            raise AssertionError(f"Missing scene was not reported as broken dependency owner: {missing_scan}")

        print("resource pipeline tools flow verified")
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
