import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"


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
    with urllib.request.urlopen(request, timeout=15) as response:
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


def poll_tool(name: str, arguments: dict, predicate, timeout_seconds: float = 10.0, start_request_id: int = 1000) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call(name, arguments, request_id=request_id)
        if predicate(last_result):
            return last_result
        time.sleep(0.25)
        request_id += 1
    raise AssertionError(f"{name} did not reach expected state. Last result: {last_result}")


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
            "get_runtime_info",
            "get_runtime_scene_tree",
            "inspect_runtime_node",
            "list_runtime_tilemap_layers",
            "get_runtime_tilemap_cell",
            "set_runtime_tilemap_cell",
            "update_runtime_node_property",
            "call_runtime_node_method",
            "evaluate_runtime_expression",
            "await_runtime_condition",
            "assert_runtime_condition",
        }
        missing = sorted(expected_tools - tool_names)
        if missing:
            raise AssertionError(f"Missing expected runtime tools: {missing}")

        project_info = tool_call("get_project_info", request_id=2)
        main_scene = project_info["main_scene"]
        if not main_scene:
            raise AssertionError("Project has no main scene configured")

        open_scene_result = tool_call("open_scene", {"scene_path": main_scene}, request_id=3)
        if open_scene_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_scene_result}")

        install_result = tool_call(
            "install_runtime_probe",
            {"node_name": "MCPRuntimeProbe", "persistent": True},
            request_id=4,
        )
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_result = tool_call("run_project", {}, request_id=5)
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")

        deadline = time.time() + 15.0
        while time.time() < deadline:
            sessions = tool_call("get_debugger_sessions", {}, request_id=6)
            if sessions["count"] > 0 and any(session.get("active") for session in sessions["sessions"]):
                break
            time.sleep(0.5)
        else:
            raise AssertionError("Debugger session never became active")

        runtime_info = poll_tool(
            "get_runtime_info",
            {"timeout_ms": 2000},
            lambda result: result.get("status") in {"success", "stale"} and "node_count" in result,
            timeout_seconds=12.0,
            start_request_id=7,
        )
        if runtime_info["node_count"] <= 0:
            raise AssertionError(f"Unexpected runtime_info payload: {runtime_info}")

        scene_tree = poll_tool(
            "get_runtime_scene_tree",
            {"max_depth": 2, "timeout_ms": 2000},
            lambda result: result.get("status") == "success" and "child_count" in result,
            timeout_seconds=8.0,
            start_request_id=8,
        )
        if scene_tree.get("child_count", -1) < 0:
            raise AssertionError(f"Invalid scene tree response: {scene_tree}")

        current_scene_path = runtime_info["current_scene"]
        inspect_result = poll_tool(
            "inspect_runtime_node",
            {"node_path": current_scene_path, "timeout_ms": 2000},
            lambda result: result.get("status") == "success" and result.get("path") == current_scene_path,
            timeout_seconds=8.0,
            start_request_id=9,
        )

        update_result = poll_tool(
            "update_runtime_node_property",
            {
                "node_path": current_scene_path,
                "property_name": "process_priority",
                "property_value": 7,
                "timeout_ms": 2000,
            },
            lambda result: result.get("status") == "success" and result.get("new_value") == 7,
            timeout_seconds=8.0,
            start_request_id=10,
        )

        eval_result = poll_tool(
            "evaluate_runtime_expression",
            {
                "expression": "process_priority",
                "node_path": current_scene_path,
                "timeout_ms": 2000,
            },
            lambda result: result.get("status") == "success" and result.get("value") == 7,
            timeout_seconds=8.0,
            start_request_id=11,
        )

        call_result = poll_tool(
            "call_runtime_node_method",
            {
                "node_path": current_scene_path,
                "method_name": "get_child_count",
                "arguments": [],
                "timeout_ms": 2000,
            },
            lambda result: result.get("status") == "success" and result.get("result", -1) >= 0,
            timeout_seconds=8.0,
            start_request_id=12,
        )

        assert_result = poll_tool(
            "assert_runtime_condition",
            {
                "expression": "process_priority == 7",
                "node_path": current_scene_path,
                "timeout_ms": 1000,
                "poll_interval_ms": 100,
                "description": "current scene process_priority should update to 7",
            },
            lambda result: result.get("status") == "success",
            timeout_seconds=8.0,
            start_request_id=13,
        )

        stop_result = tool_call("stop_project", {}, request_id=14)
        if stop_result.get("status") != "success":
            raise AssertionError(f"stop_project failed: {stop_result}")

        remove_result = tool_call(
            "remove_runtime_probe",
            {"node_name": "MCPRuntimeProbe"},
            request_id=15,
        )
        if remove_result.get("status") not in {"success", "not_installed"}:
            raise AssertionError(f"remove_runtime_probe failed: {remove_result}")

        save_cleanup = tool_call("save_scene", {}, request_id=16)
        if save_cleanup.get("status") != "success":
            raise AssertionError(f"cleanup save_scene failed: {save_cleanup}")

        print("runtime probe flow verified")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main())
