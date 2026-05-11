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
            "debug_continue",
            "debug_step_into",
            "debug_step_over",
            "debug_step_out",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected debug execution control tools: {missing_tools}")

        install_fake_plugin = tool_call(
            "execute_editor_script",
            {
                "code": "var bridge_script := GDScript.new()\nbridge_script.source_code = \"extends RefCounted\\nvar commands: Array = []\\nfunc send_debugger_message(message: String, data: Array = [], session_id: int = -1) -> Dictionary:\\n\\tcommands.append({\\\"message\\\": message, \\\"data\\\": data.duplicate(true), \\\"session_id\\\": session_id})\\n\\treturn {\\\"status\\\": \\\"success\\\", \\\"sessions_updated\\\": 1}\\n\"\nbridge_script.reload()\nvar plugin_script := GDScript.new()\nplugin_script.source_code = \"extends RefCounted\\nvar _bridge: RefCounted\\nfunc _init(bridge: RefCounted) -> void:\\n\\t_bridge = bridge\\nfunc get_debugger_bridge() -> RefCounted:\\n\\treturn _bridge\\n\"\nplugin_script.reload()\nvar fake_bridge = bridge_script.new()\nvar fake_plugin = plugin_script.new(fake_bridge)\nEngine.set_meta(\"GodotMCPPlugin\", fake_plugin)\n_custom_print(JSON.stringify({\"installed\": true}))\n",
            },
            request_id=2,
        )
        if install_fake_plugin.get("success") is not True:
            raise AssertionError(f"Failed to install fake debugger plugin: {install_fake_plugin}")

        tool_call("debug_step_into", {}, request_id=3)
        tool_call("debug_step_over", {}, request_id=4)
        tool_call("debug_step_out", {"session_id": 7}, request_id=5)
        tool_call("debug_continue", {"session_id": 9}, request_id=6)

        inspect_commands = tool_call(
            "execute_editor_script",
            {
                "code": "var plugin = Engine.get_meta(\"GodotMCPPlugin\")\nvar bridge = plugin.get_debugger_bridge()\n_custom_print(JSON.stringify({\"commands\": bridge.commands}))\n",
            },
            request_id=7,
        )
        if inspect_commands.get("success") is not True or not inspect_commands.get("output"):
            raise AssertionError(f"Failed to inspect fake debugger bridge commands: {inspect_commands}")
        captured = json.loads(inspect_commands["output"][-1])
        commands = captured.get("commands", [])
        expected = [
            {"message": "step", "data": [], "session_id": -1},
            {"message": "next", "data": [], "session_id": -1},
            {"message": "out", "data": [], "session_id": 7},
            {"message": "continue", "data": [], "session_id": 9},
        ]
        if commands != expected:
            raise AssertionError(f"Unexpected debugger command sequence: {commands}")

        print("debug execution control flow verified")
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
