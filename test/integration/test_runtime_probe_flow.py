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


def get_debugger_messages(count: int = 100, request_id: int = 5000) -> dict:
    return tool_call(
        "get_debugger_messages",
        {"count": count, "order": "desc"},
        request_id=request_id,
    )


def poll_tool(
    name: str,
    arguments: dict,
    predicate,
    timeout_seconds: float = 10.0,
    start_request_id: int = 1000,
    poll_interval_seconds: float = 0.5,
) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call(name, arguments, request_id=request_id)
        if predicate(last_result):
            return last_result
        time.sleep(poll_interval_seconds)
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


def wait_for_editor_scene_state_to_stabilize(delay_seconds: float = 3.0) -> None:
    time.sleep(delay_seconds)


def wait_for_current_scene(scene_path: str, timeout_seconds: float = 10.0, start_request_id: int = 200) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call("get_current_scene", {}, request_id=request_id)
        if last_result.get("scene_path") == scene_path:
            return last_result
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Scene did not become active: expected {scene_path}, last result: {last_result}")


def dispatch_runtime_tool(name: str, arguments: dict, request_id: int) -> dict:
    result = tool_call(name, arguments, request_id=request_id)
    if result.get("status") not in {"success", "pending", "stale"}:
        raise AssertionError(f"{name} did not dispatch cleanly: {result}")
    return result


def run_project_until_debugger_active(scene_path: str, attempts: int = 3, start_request_id: int = 4) -> None:
    last_error = None
    request_id = start_request_id
    for _attempt in range(attempts):
        run_result = tool_call("run_project", {"scene_path": scene_path}, request_id=request_id)
        if run_result.get("status") != "success":
            last_error = AssertionError(f"run_project failed: {run_result}")
        else:
            try:
                time.sleep(1.0)
                deadline = time.time() + 15.0
                while time.time() < deadline:
                    sessions = tool_call("get_debugger_sessions", {}, request_id=request_id + 1)
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
                    start_request_id=request_id + 20,
                )
                if runtime_info["node_count"] <= 0:
                    raise AssertionError(f"Unexpected runtime_info payload: {runtime_info}")
                return
            except AssertionError as exc:
                last_error = exc
        try:
            tool_call("stop_project", {}, request_id=request_id + 40)
        except Exception:
            pass
        time.sleep(1.0)
        request_id += 100
    if last_error:
        raise last_error
    raise AssertionError("Failed to start project with an active debugger session")


def wait_for_debugger_message(
    message_name: str,
    predicate,
    minimum_sequence: int = 0,
    timeout_seconds: float = 8.0,
    start_request_id: int = 5200,
) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_messages = []
    while time.time() < deadline:
        response = get_debugger_messages(count=50, request_id=request_id)
        last_messages = response.get("messages", [])
        for entry in last_messages:
            if int(entry.get("sequence", 0)) <= minimum_sequence:
                continue
            if entry.get("message") != message_name:
                continue
            payloads = entry.get("data", [])
            payload = payloads[0] if payloads else None
            if predicate(payload):
                return payload
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(
        f"Timed out waiting for debugger message {message_name} after sequence {minimum_sequence}. "
        f"Last messages: {last_messages}"
    )


def dispatch_runtime_tool_until_message(
    tool_name: str,
    arguments: dict,
    message_name: str,
    predicate,
    attempts: int,
    start_request_id: int,
    wait_timeout_seconds: float = 6.0,
) -> dict:
    last_error: Exception | None = None
    request_id = start_request_id
    for _attempt in range(attempts):
        dispatch_runtime_tool(tool_name, arguments, request_id=request_id + 1)
        try:
            return wait_for_debugger_message(
                message_name,
                predicate,
                minimum_sequence=0,
                timeout_seconds=wait_timeout_seconds,
                start_request_id=request_id + 2,
            )
        except AssertionError as exc:
            last_error = exc
            time.sleep(1.0)
            request_id += 100
    if last_error:
        raise last_error
    raise AssertionError(f"Failed to observe debugger message for {tool_name}")


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
        wait_for_editor_scene_state_to_stabilize()
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
        wait_for_current_scene(main_scene)

        install_result = tool_call(
            "install_runtime_probe",
            {"node_name": "MCPRuntimeProbe", "persistent": True},
            request_id=4,
        )
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_project_until_debugger_active(main_scene, start_request_id=5)

        runtime_info = poll_tool(
            "get_runtime_info",
            {"timeout_ms": 2000},
            lambda result: result.get("status") in {"success", "stale"} and "node_count" in result,
            timeout_seconds=12.0,
            start_request_id=105,
        )
        if runtime_info["node_count"] <= 0:
            raise AssertionError(f"Unexpected runtime_info payload: {runtime_info}")
        current_scene_path = runtime_info["current_scene"]

        scene_tree = dispatch_runtime_tool_until_message(
            "get_runtime_scene_tree",
            {"max_depth": 2, "timeout_ms": 2000},
            "mcp:scene_tree",
            lambda payload: payload and "child_count" in payload,
            attempts=3,
            start_request_id=900,
        )
        if scene_tree.get("child_count", -1) < 0:
            raise AssertionError(f"Invalid scene tree response: {scene_tree}")

        inspect_result = dispatch_runtime_tool_until_message(
            "inspect_runtime_node",
            {"node_path": current_scene_path, "timeout_ms": 2000},
            "mcp:node",
            lambda payload: payload and payload.get("path") == current_scene_path,
            attempts=3,
            start_request_id=1000,
        )

        update_result = dispatch_runtime_tool_until_message(
            "update_runtime_node_property",
            {
                "node_path": current_scene_path,
                "property_name": "process_priority",
                "property_value": 7,
                "timeout_ms": 2000,
            },
            "mcp:node_property_updated",
            lambda payload: payload
            and payload.get("node_path") == current_scene_path
            and payload.get("property_name") == "process_priority"
            and payload.get("new_value") == 7,
            attempts=3,
            start_request_id=1100,
        )

        eval_result = dispatch_runtime_tool_until_message(
            "evaluate_runtime_expression",
            {
                "expression": "process_priority",
                "node_path": current_scene_path,
                "timeout_ms": 2000,
            },
            "mcp:expression_result",
            lambda payload: payload and payload.get("expression") == "process_priority" and payload.get("value") == 7,
            attempts=3,
            start_request_id=1200,
        )

        call_result = dispatch_runtime_tool_until_message(
            "call_runtime_node_method",
            {
                "node_path": current_scene_path,
                "method_name": "get_child_count",
                "arguments": [],
                "timeout_ms": 2000,
            },
            "mcp:node_method_result",
            lambda payload: payload
            and payload.get("node_path") == current_scene_path
            and payload.get("method_name") == "get_child_count"
            and payload.get("result", -1) >= 0,
            attempts=3,
            start_request_id=1300,
        )

        assert_result = dispatch_runtime_tool_until_message(
            "assert_runtime_condition",
            {
                "expression": "process_priority == 7",
                "node_path": current_scene_path,
                "timeout_ms": 1000,
                "poll_interval_ms": 100,
                "description": "current scene process_priority should update to 7",
            },
            "mcp:expression_result",
            lambda payload: payload
            and payload.get("expression") == "process_priority == 7"
            and payload.get("value") is True,
            attempts=3,
            start_request_id=1400,
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
