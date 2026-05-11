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
            "debug_continue_and_wait",
            "debug_step_into_and_wait",
            "debug_step_over_and_wait",
            "debug_step_out_and_wait",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected debug execution wait tools: {missing_tools}")

        install_fake_plugin = tool_call(
            "execute_editor_script",
            {
                "code": "var bridge_script := GDScript.new()\nbridge_script.source_code = \"extends RefCounted\\nvar commands: Array = []\\nvar sessions: Array = [{\\\"session_id\\\": 1, \\\"active\\\": true, \\\"breaked\\\": true}]\\nvar state_events: Array = []\\nfunc send_debugger_message(message: String, data: Array = [], session_id: int = -1) -> Dictionary:\\n\\tcommands.append({\\\"message\\\": message, \\\"data\\\": data.duplicate(true), \\\"session_id\\\": session_id})\\n\\tif message == \\\"continue\\\":\\n\\t\\tsessions = [{\\\"session_id\\\": 1, \\\"active\\\": true, \\\"breaked\\\": false}]\\n\\t\\tstate_events = [{\\\"state\\\": \\\"running\\\", \\\"reason\\\": \\\"continued\\\"}]\\n\\telse:\\n\\t\\tsessions = [{\\\"session_id\\\": 1, \\\"active\\\": true, \\\"breaked\\\": true}]\\n\\t\\tstate_events = [{\\\"state\\\": \\\"breaked\\\", \\\"reason\\\": message}]\\n\\treturn {\\\"status\\\": \\\"success\\\", \\\"sessions_updated\\\": 1}\\nfunc get_sessions_info() -> Array:\\n\\treturn sessions.duplicate(true)\\nfunc get_state_events(count: int = 100, offset: int = 0, order: String = \\\"desc\\\") -> Dictionary:\\n\\treturn {\\\"events\\\": state_events.duplicate(true), \\\"count\\\": state_events.size(), \\\"total_available\\\": state_events.size()}\\n\"\nbridge_script.reload()\nvar plugin_script := GDScript.new()\nplugin_script.source_code = \"extends RefCounted\\nvar _bridge: RefCounted\\nfunc _init(bridge: RefCounted) -> void:\\n\\t_bridge = bridge\\nfunc get_debugger_bridge() -> RefCounted:\\n\\treturn _bridge\\n\"\nplugin_script.reload()\nvar fake_bridge = bridge_script.new()\nvar fake_plugin = plugin_script.new(fake_bridge)\nEngine.set_meta(\"GodotMCPPlugin\", fake_plugin)\n_custom_print(JSON.stringify({\"installed\": true}))\n",
            },
            request_id=2,
        )
        if install_fake_plugin.get("success") is not True:
            raise AssertionError(f"Failed to install fake debugger plugin: {install_fake_plugin}")

        continue_result = tool_call("debug_continue_and_wait", {}, request_id=3)
        if continue_result.get("status") != "success" or continue_result.get("target_state") != "running":
            raise AssertionError(f"Expected continue-and-wait to reach running state: {continue_result}")
        if continue_result.get("matched_state", {}).get("state") != "running":
            raise AssertionError(f"Expected matched running state from continue-and-wait: {continue_result}")

        step_result = tool_call("debug_step_over_and_wait", {"session_id": 1}, request_id=4)
        if step_result.get("status") != "success" or step_result.get("target_state") != "breaked":
            raise AssertionError(f"Expected step-over-and-wait to reach breaked state: {step_result}")
        matched_state = step_result.get("matched_state", {})
        if matched_state.get("state") != "breaked" or matched_state.get("reason") != "next":
            raise AssertionError(f"Expected matched breaked state for step over: {step_result}")

        inspect_commands = tool_call(
            "execute_editor_script",
            {
                "code": "var plugin = Engine.get_meta(\"GodotMCPPlugin\")\nvar bridge = plugin.get_debugger_bridge()\n_custom_print(JSON.stringify({\"commands\": bridge.commands}))\n",
            },
            request_id=5,
        )
        if inspect_commands.get("success") is not True or not inspect_commands.get("output"):
            raise AssertionError(f"Failed to inspect fake debugger bridge commands: {inspect_commands}")
        commands = json.loads(inspect_commands["output"][-1]).get("commands", [])
        expected = [
            {"message": "continue", "data": [], "session_id": -1},
            {"message": "next", "data": [], "session_id": 1},
        ]
        if commands != expected:
            raise AssertionError(f"Unexpected debugger command sequence for wait tools: {commands}")

        print("debug execution wait flow verified")
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
