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
TEMP_DIR = REPO_ROOT / ".tmp_project_diagnostics"
BROKEN_SCRIPT_PATH = "res://.tmp_project_diagnostics/broken_script.gd"
BROKEN_SCRIPT_FILE = TEMP_DIR / "broken_script.gd"
MISSING_SCENE_PATH = "res://.tmp_project_diagnostics/missing_dependency_scene.tscn"
MISSING_SCENE_FILE = TEMP_DIR / "missing_dependency_scene.tscn"

BROKEN_SCRIPT_TEXT = """
extends Node

func broken_func(
    return 123
""".strip() + "\n"

MISSING_SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_project_diagnostics/does_not_exist.gd" id="1_missing"]

[node name="BrokenScene" type="Node"]
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


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    BROKEN_SCRIPT_FILE.write_text(BROKEN_SCRIPT_TEXT, encoding="utf-8")
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

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "detect_broken_scripts",
            "audit_project_health",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected diagnostics tools: {missing_tools}")

        broken_scripts = tool_call(
            "detect_broken_scripts",
            {"search_path": "res://.tmp_project_diagnostics", "include_warnings": True, "max_results": 20},
            request_id=2,
        )
        if broken_scripts.get("broken_count", 0) < 1:
            raise AssertionError(f"Expected at least one broken script: {broken_scripts}")
        if not any(issue.get("script_path") == BROKEN_SCRIPT_PATH for issue in broken_scripts["issues"]):
            raise AssertionError(f"Broken script was not reported: {broken_scripts}")

        audit = tool_call(
            "audit_project_health",
            {"search_path": "res://.tmp_project_diagnostics", "include_warnings": True, "max_results": 20},
            request_id=3,
        )
        if audit.get("status") != "failing":
            raise AssertionError(f"Expected failing project health status: {audit}")
        if audit["summary"].get("broken_scripts", 0) < 1:
            raise AssertionError(f"Expected broken script summary count: {audit}")
        if audit["summary"].get("missing_dependencies", 0) < 1:
            raise AssertionError(f"Expected missing dependency summary count: {audit}")
        if not any(entry.get("owner_path") == MISSING_SCENE_PATH for entry in audit["missing_dependencies"]):
            raise AssertionError(f"Missing dependency scene was not reported: {audit}")

        print("project diagnostics flow verified")
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
