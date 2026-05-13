import json
import subprocess
import sys
import time
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


def seed_debugger_bridge() -> None:
    result = tool_call(
        "execute_editor_script",
        {
            "code": """
var plugin = Engine.get_meta("GodotMCPPlugin")
var bridge = plugin.get_debugger_bridge()
bridge._captured_messages.clear()
bridge._captured_messages.append({"message": "alpha"})
bridge._captured_messages.append({"message": "beta"})
bridge._captured_messages.append({"message": "gamma"})
bridge._state_events.clear()
bridge._state_events.append({"state": "breaked", "reason": "pause"})
bridge._state_events.append({"state": "running", "reason": "continue"})
bridge._state_events.append({"state": "stopped", "reason": "quit"})
bridge._output_events.clear()
bridge._output_events.append({"category": "stdout", "text": "one"})
bridge._output_events.append({"category": "stderr", "text": "ignore"})
bridge._output_events.append({"category": "stdout", "text": "two"})
_custom_print(JSON.stringify({
	"ok": true,
	"captured_messages": bridge._captured_messages.size(),
	"state_events": bridge._state_events.size(),
	"output_events": bridge._output_events.size()
}))
""",
        },
        request_id=2,
    )
    if result.get("success") is not True:
        raise AssertionError(f"Failed to seed debugger bridge: {result}")


def assert_paginated_window(payload: dict, total: int, count: int, next_cursor: int | None) -> None:
    if payload.get("count") != count:
        raise AssertionError(f"Unexpected window count: {payload}")
    if payload.get("total_available") != total:
        raise AssertionError(f"Unexpected total_available: {payload}")
    if next_cursor is None:
        if payload.get("truncated") is not False or payload.get("has_more") is not False:
            raise AssertionError(f"Expected terminal pagination metadata: {payload}")
        if "next_cursor" in payload:
            raise AssertionError(f"Did not expect next_cursor on terminal page: {payload}")
    else:
        if payload.get("truncated") is not True or payload.get("has_more") is not True:
            raise AssertionError(f"Expected continuation metadata on paged window: {payload}")
        if payload.get("next_cursor") != next_cursor:
            raise AssertionError(f"Unexpected next_cursor: {payload}")


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
            "get_debugger_messages",
            "get_debug_state_events",
            "get_debug_output",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected debug pagination tools: {missing_tools}")

        seed_debugger_bridge()

        messages_page_1 = tool_call("get_debugger_messages", {"count": 2, "offset": 0, "order": "asc"}, request_id=10)
        assert_paginated_window(messages_page_1, total=3, count=2, next_cursor=2)
        messages_page_2 = tool_call("get_debugger_messages", {"count": 2, "offset": 2, "order": "asc"}, request_id=11)
        assert_paginated_window(messages_page_2, total=3, count=1, next_cursor=None)
        if messages_page_2.get("messages", [{}])[0].get("message") != "gamma":
            raise AssertionError(f"Expected continuation page to advance captured messages: {messages_page_2}")

        state_page_1 = tool_call("get_debug_state_events", {"count": 2, "offset": 0, "order": "asc"}, request_id=20)
        assert_paginated_window(state_page_1, total=3, count=2, next_cursor=2)
        state_page_2 = tool_call("get_debug_state_events", {"count": 2, "offset": 2, "order": "asc"}, request_id=21)
        assert_paginated_window(state_page_2, total=3, count=1, next_cursor=None)
        if state_page_2.get("events", [{}])[0].get("state") != "stopped":
            raise AssertionError(f"Expected continuation page to advance state events: {state_page_2}")

        output_page_1 = tool_call(
            "get_debug_output",
            {"count": 1, "offset": 0, "order": "asc", "category": "stdout"},
            request_id=30,
        )
        assert_paginated_window(output_page_1, total=2, count=1, next_cursor=1)
        output_page_2 = tool_call(
            "get_debug_output",
            {"count": 1, "offset": 1, "order": "asc", "category": "stdout"},
            request_id=31,
        )
        assert_paginated_window(output_page_2, total=2, count=1, next_cursor=None)
        if output_page_2.get("events", [{}])[0].get("text") != "two":
            raise AssertionError(f"Expected continuation page to advance filtered output events: {output_page_2}")

        print("debug event pagination flow verified")
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
