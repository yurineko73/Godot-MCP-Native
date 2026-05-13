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
TEMP_DIR = REPO_ROOT / ".tmp_cyclic_resource_dependencies"
SCENE_A_PATH = "res://.tmp_cyclic_resource_dependencies/scene_a.tscn"
SCENE_B_PATH = "res://.tmp_cyclic_resource_dependencies/scene_b.tscn"
SCENE_A_FILE = TEMP_DIR / "scene_a.tscn"
SCENE_B_FILE = TEMP_DIR / "scene_b.tscn"

SCENE_A_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://.tmp_cyclic_resource_dependencies/scene_b.tscn" id="1_b"]

[node name="SceneA" type="Node"]

[node name="SceneBInstance" parent="." instance=ExtResource("1_b")]
""".strip() + "\n"

SCENE_B_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://.tmp_cyclic_resource_dependencies/scene_a.tscn" id="1_a"]

[node name="SceneB" type="Node"]

[node name="SceneAInstance" parent="." instance=ExtResource("1_a")]
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
    SCENE_A_FILE.write_text(SCENE_A_TEXT, encoding="utf-8")
    SCENE_B_FILE.write_text(SCENE_B_TEXT, encoding="utf-8")

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
            "scan_cyclic_resource_dependencies",
            "audit_project_health",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected cyclic dependency tools: {missing_tools}")

        cycle_scan = tool_call(
            "scan_cyclic_resource_dependencies",
            {"search_path": "res://.tmp_cyclic_resource_dependencies", "max_results": 10},
            request_id=2,
        )
        if cycle_scan.get("issue_count", 0) < 1:
            raise AssertionError(f"Expected at least one cyclic dependency issue: {cycle_scan}")
        first_issue = cycle_scan["issues"][0]
        cycle_path = first_issue.get("cycle_path", [])
        if SCENE_A_PATH not in cycle_path or SCENE_B_PATH not in cycle_path:
            raise AssertionError(f"Expected cycle to include both temporary scenes: {first_issue}")
        if cycle_path[0] != cycle_path[-1]:
            raise AssertionError(f"Expected cycle path to close back to the start: {first_issue}")
        if cycle_scan.get("truncated") is not False or cycle_scan.get("has_more") is not False:
            raise AssertionError(f"Expected complete cyclic scan metadata for single-cycle fixture: {cycle_scan}")
        if cycle_scan.get("max_results_applied") != 10 or "next_max_results" in cycle_scan:
            raise AssertionError(f"Expected stable rerun metadata for non-truncated cyclic scan: {cycle_scan}")

        exact_fit_cycle_scan = tool_call(
            "scan_cyclic_resource_dependencies",
            {"search_path": "res://.tmp_cyclic_resource_dependencies", "max_results": 1},
            request_id=21,
        )
        if exact_fit_cycle_scan.get("issue_count") != 1:
            raise AssertionError(f"Expected exact-fit cyclic dependency count of 1: {exact_fit_cycle_scan}")
        if exact_fit_cycle_scan.get("truncated") is not False or exact_fit_cycle_scan.get("has_more") is not False:
            raise AssertionError(f"Exact-fit cyclic scan should not report truncation: {exact_fit_cycle_scan}")
        if "next_max_results" in exact_fit_cycle_scan:
            raise AssertionError(f"Exact-fit cyclic scan should not advertise next_max_results: {exact_fit_cycle_scan}")

        audit = tool_call(
            "audit_project_health",
            {"search_path": "res://.tmp_cyclic_resource_dependencies", "include_warnings": True, "max_results": 10},
            request_id=3,
        )
        if audit.get("status") != "failing":
            raise AssertionError(f"Expected failing project health status due to cycle: {audit}")
        if audit["summary"].get("cyclic_dependencies", 0) < 1:
            raise AssertionError(f"Expected cyclic dependency summary count: {audit}")
        if not audit.get("cyclic_dependencies"):
            raise AssertionError(f"Expected cyclic dependency details in audit payload: {audit}")
        if audit.get("truncated") is not False or audit.get("has_more") is not False:
            raise AssertionError(f"Expected complete audit metadata for single-cycle fixture: {audit}")
        if audit.get("max_results_applied") != 10 or "next_max_results" in audit:
            raise AssertionError(f"Expected stable rerun metadata for non-truncated cyclic audit: {audit}")

        print("cyclic resource dependency flow verified")
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
