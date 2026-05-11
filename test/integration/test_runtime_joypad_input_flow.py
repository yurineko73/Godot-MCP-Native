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
TEMP_DIR = REPO_ROOT / ".tmp_runtime_joypad_input"
SCENE_PATH = "res://.tmp_runtime_joypad_input/runtime_joypad_scene.tscn"
SCRIPT_PATH = "res://.tmp_runtime_joypad_input/runtime_joypad_capture.gd"
EVENTS_PATH = "res://.tmp_runtime_joypad_input/recorded_events.json"
SCENE_FILE = TEMP_DIR / "runtime_joypad_scene.tscn"
SCRIPT_FILE = TEMP_DIR / "runtime_joypad_capture.gd"
EVENTS_FILE = TEMP_DIR / "recorded_events.json"

SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_runtime_joypad_input/runtime_joypad_capture.gd" id="1_script"]

[node name="JoypadRoot" type="Node"]
script = ExtResource("1_script")
""".strip() + "\n"

SCRIPT_TEXT = """
extends Node

var recorded_events: Array = []

func _flush_events() -> void:
\tvar file := FileAccess.open("res://.tmp_runtime_joypad_input/recorded_events.json", FileAccess.WRITE)
\tif file:
\t\tfile.store_string(JSON.stringify(recorded_events))

func _input(event: InputEvent) -> void:
\tif event is InputEventJoypadButton:
\t\trecorded_events.append({
\t\t\t"type": "joypad_button",
\t\t\t"device": event.device,
\t\t\t"button_index": event.button_index,
\t\t\t"pressed": event.pressed,
\t\t\t"pressure": event.pressure
\t\t})
\t\t_flush_events()
\telif event is InputEventJoypadMotion:
\t\trecorded_events.append({
\t\t\t"type": "joypad_motion",
\t\t\t"device": event.device,
\t\t\t"axis": event.axis,
\t\t\t"axis_value": event.axis_value
\t\t})
\t\t_flush_events()
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


def runtime_tool_call(name: str, arguments: dict, request_id: int, timeout_seconds: float = 10.0) -> dict:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        result = tool_call(name, arguments, request_id=request_id)
        if result.get("status") not in {"pending", "no_active_sessions"}:
            return result
        time.sleep(0.5)
    raise TimeoutError(f"Timed out waiting for runtime tool {name}")


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


def wait_for_active_debugger_session(timeout_seconds: float = 15.0, start_request_id: int = 300) -> dict:
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


def prime_runtime_probe(timeout_seconds: float = 8.0, start_request_id: int = 30) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call("get_runtime_info", {"timeout_ms": 2000}, request_id=request_id)
        if last_result.get("status") in {"success", "stale"} and last_result.get("current_scene"):
            return last_result
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Runtime probe never primed: {last_result}")


def wait_for_recorded_events(expected_count: int, timeout_seconds: float = 10.0) -> list:
    deadline = time.time() + timeout_seconds
    last_contents = None
    while time.time() < deadline:
        if EVENTS_FILE.exists():
            last_contents = EVENTS_FILE.read_text(encoding="utf-8")
            events = json.loads(last_contents)
            if len(events) >= expected_count:
                return events
        time.sleep(0.5)
    raise AssertionError(f"Expected runtime script to record at least {expected_count} events, last contents: {last_contents}")


def run_project_until_debugger_active(scene_path: str, attempts: int = 2, start_request_id: int = 4) -> None:
    last_error = None
    request_id = start_request_id
    for _attempt in range(attempts):
        run_result = tool_call("run_project", {"scene_path": scene_path}, request_id=request_id)
        if run_result.get("status") != "success":
            last_error = AssertionError(f"run_project failed: {run_result}")
        else:
            try:
                wait_for_active_debugger_session(start_request_id=request_id + 1)
                prime_runtime_probe(start_request_id=request_id + 21)
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


def run_once() -> None:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    SCENE_FILE.write_text(SCENE_TEXT, encoding="utf-8")
    SCRIPT_FILE.write_text(SCRIPT_TEXT, encoding="utf-8")
    if EVENTS_FILE.exists():
        EVENTS_FILE.unlink()

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
        expected_tools = {"simulate_runtime_input_event"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime joypad input tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")
        wait_for_current_scene(SCENE_PATH)

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_project_until_debugger_active(SCENE_PATH)

        first_input_result = tool_call(
            "simulate_runtime_input_event",
            {
                "event": {
                    "type": "joypad_button",
                    "device": 2,
                    "button_index": 1,
                    "pressed": True,
                    "pressure": 0.75,
                }
            },
            request_id=40,
        )
        second_input_result = tool_call(
            "simulate_runtime_input_event",
            {
                "event": {
                    "type": "joypad_motion",
                    "device": 2,
                    "axis": 3,
                    "axis_value": -0.5,
                }
            },
            request_id=41,
        )

        if first_input_result.get("status") not in {"success", "pending"}:
            raise AssertionError(f"Unexpected runtime input dispatch result: {first_input_result}")
        if second_input_result.get("status") not in {"success", "pending"}:
            raise AssertionError(f"Unexpected runtime input dispatch result: {second_input_result}")

        events = wait_for_recorded_events(2)
        button_event = events[-2]
        motion_event = events[-1]
        if button_event.get("type") != "joypad_button" or button_event.get("device") != 2 or button_event.get("button_index") != 1:
            raise AssertionError(f"Unexpected recorded joypad button event: {button_event}")
        if abs(float(button_event.get("pressure", 0.0)) - 0.75) > 1e-6:
            raise AssertionError(f"Unexpected recorded joypad button pressure: {button_event}")
        if motion_event.get("type") != "joypad_motion" or motion_event.get("device") != 2 or motion_event.get("axis") != 3:
            raise AssertionError(f"Unexpected recorded joypad motion event: {motion_event}")
        if abs(float(motion_event.get("axis_value", 0.0)) - (-0.5)) > 1e-6:
            raise AssertionError(f"Unexpected recorded joypad motion axis value: {motion_event}")

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


def main() -> int:
    last_error: Exception | None = None
    for _attempt in range(2):
        try:
            run_once()
            print("runtime joypad input flow verified")
            return 0
        except (AssertionError, TimeoutError, urllib.error.URLError, ConnectionError) as exc:
            last_error = exc
            time.sleep(1.0)
    if last_error:
        raise last_error
    raise AssertionError("runtime joypad input flow failed without an explicit error")


if __name__ == "__main__":
    sys.exit(main())
