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
TEMP_DIR = REPO_ROOT / ".tmp_runtime_theme_tools"
SCENE_PATH = "res://.tmp_runtime_theme_tools/runtime_theme_scene.tscn"
SCENE_FILE = TEMP_DIR / "runtime_theme_scene.tscn"

SCENE_TEXT = """
[gd_scene format=3]

[node name="ThemeRoot" type="Control"]

[node name="ThemedButton" type="Button" parent="."]
text = "Theme Button"
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


def get_debugger_messages(count: int = 100, request_id: int = 5000) -> dict:
    return tool_call(
        "get_debugger_messages",
        {"count": count, "order": "desc"},
        request_id=request_id,
    )


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


def wait_for_active_debugger_session(timeout_seconds: float = 20.0, start_request_id: int = 300) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call("get_debugger_sessions", {}, request_id=request_id)
        sessions = last_result.get("sessions", [])
        if last_result.get("count", 0) > 0 and any(session.get("active") for session in sessions):
            return last_result
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Debugger session never became active: {last_result}")


def prime_runtime_probe(
    timeout_seconds: float = 8.0,
    start_request_id: int = 30,
    minimum_node_count: int = 0,
) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call("get_runtime_info", {"timeout_ms": 2000}, request_id=request_id)
        if (
            last_result.get("status") in {"success", "stale"}
            and last_result.get("current_scene")
            and int(last_result.get("node_count", 0)) >= minimum_node_count
        ):
            return last_result
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Runtime probe never primed: {last_result}")


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
                wait_for_active_debugger_session(start_request_id=request_id + 1)
                time.sleep(1.5)
                prime_runtime_probe(start_request_id=request_id + 21, minimum_node_count=2)
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


def dispatch_runtime_tool(name: str, arguments: dict, request_id: int) -> dict:
    result = tool_call(name, arguments, request_id=request_id)
    if result.get("status") not in {"success", "pending"}:
        raise AssertionError(f"{name} did not dispatch cleanly: {result}")
    return result


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
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    SCENE_FILE.write_text(SCENE_TEXT, encoding="utf-8")

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

    button_path = "/root/ThemeRoot/ThemedButton"

    try:
        wait_for_server()
        wait_for_editor_scene_state_to_stabilize()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "get_runtime_theme_item",
            "set_runtime_theme_override",
            "clear_runtime_theme_override",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime theme tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")
        wait_for_current_scene(SCENE_PATH)

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_project_until_debugger_active(SCENE_PATH)

        initial_color = dispatch_runtime_tool_until_message(
            "get_runtime_theme_item",
            {"node_path": button_path, "item_type": "color", "item_name": "font_color", "timeout_ms": 2000},
            "mcp:theme_item",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "color"
            and payload.get("item_name") == "font_color",
            attempts=3,
            start_request_id=1000,
        )
        if initial_color.get("has_item") is not True:
            raise AssertionError(f"Expected runtime theme color to resolve: {initial_color}")
        if initial_color.get("has_override") is not False:
            raise AssertionError(f"Color override should be absent before set: {initial_color}")

        updated_color = dispatch_runtime_tool_until_message(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "color",
                "item_name": "font_color",
                "value": {"r": 0.25, "g": 0.5, "b": 0.75, "a": 1.0},
                "timeout_ms": 2000,
            },
            "mcp:theme_override_updated",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "color"
            and payload.get("item_name") == "font_color"
            and payload.get("has_override") is True,
            attempts=3,
            start_request_id=1100,
        )
        if updated_color.get("has_override") is not True:
            raise AssertionError(f"Expected color override after update: {updated_color}")

        font_size = dispatch_runtime_tool_until_message(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "font_size",
                "item_name": "font_size",
                "value": 22,
                "timeout_ms": 2000,
            },
            "mcp:theme_override_updated",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "font_size"
            and payload.get("item_name") == "font_size"
            and payload.get("value") == 22,
            attempts=3,
            start_request_id=1200,
        )
        if font_size.get("value") != 22:
            raise AssertionError(f"Expected font size override to apply: {font_size}")

        separation = dispatch_runtime_tool_until_message(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "constant",
                "item_name": "h_separation",
                "value": 13,
                "timeout_ms": 2000,
            },
            "mcp:theme_override_updated",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "constant"
            and payload.get("item_name") == "h_separation"
            and payload.get("value") == 13,
            attempts=3,
            start_request_id=1300,
        )
        if separation.get("value") != 13:
            raise AssertionError(f"Expected constant override to apply: {separation}")

        stylebox = dispatch_runtime_tool_until_message(
            "get_runtime_theme_item",
            {"node_path": button_path, "item_type": "stylebox", "item_name": "normal", "timeout_ms": 2000},
            "mcp:theme_item",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "stylebox"
            and payload.get("item_name") == "normal",
            attempts=3,
            start_request_id=1400,
        )
        if stylebox.get("has_item") is not True:
            raise AssertionError(f"Expected stylebox item to resolve: {stylebox}")
        if stylebox.get("value", {}).get("resource_class") == "":
            raise AssertionError(f"Expected stylebox resource metadata: {stylebox}")

        cleared_color = dispatch_runtime_tool_until_message(
            "clear_runtime_theme_override",
            {"node_path": button_path, "item_type": "color", "item_name": "font_color", "timeout_ms": 2000},
            "mcp:theme_override_cleared",
            lambda payload: payload
            and payload.get("node_path") == button_path
            and payload.get("item_type") == "color"
            and payload.get("item_name") == "font_color"
            and payload.get("has_override") is False,
            attempts=3,
            start_request_id=1500,
        )
        if cleared_color.get("has_override") is not False:
            raise AssertionError(f"Expected color override to clear: {cleared_color}")

        print("runtime theme tools flow verified")
        return 0
    finally:
        try:
            tool_call("stop_project", {}, request_id=99)
        except Exception:
            pass

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
