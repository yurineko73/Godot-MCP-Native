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
SCENE_FILE = TEMP_DIR / "runtime_joypad_scene.tscn"
SCRIPT_FILE = TEMP_DIR / "runtime_joypad_capture.gd"

SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_runtime_joypad_input/runtime_joypad_capture.gd" id="1_script"]

[node name="JoypadRoot" type="Node"]
script = ExtResource("1_script")
""".strip() + "\n"

SCRIPT_TEXT = """
extends Node

var recorded_events: Array = []

func _input(event: InputEvent) -> void:
\tif event is InputEventJoypadButton:
\t\trecorded_events.append({
\t\t\t"type": "joypad_button",
\t\t\t"device": event.device,
\t\t\t"button_index": event.button_index,
\t\t\t"pressed": event.pressed,
\t\t\t"pressure": event.pressure
\t\t})
\telif event is InputEventJoypadMotion:
\t\trecorded_events.append({
\t\t\t"type": "joypad_motion",
\t\t\t"device": event.device,
\t\t\t"axis": event.axis,
\t\t\t"axis_value": event.axis_value
\t\t})
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


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    SCENE_FILE.write_text(SCENE_TEXT, encoding="utf-8")
    SCRIPT_FILE.write_text(SCRIPT_TEXT, encoding="utf-8")

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
        expected_tools = {"simulate_runtime_input_event", "evaluate_runtime_expression"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime joypad input tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") != "success":
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_result = tool_call("run_project", {"scene_path": SCENE_PATH}, request_id=4)
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")

        runtime_tool_call(
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
            request_id=5,
        )
        runtime_tool_call(
            "simulate_runtime_input_event",
            {
                "event": {
                    "type": "joypad_motion",
                    "device": 2,
                    "axis": 3,
                    "axis_value": -0.5,
                }
            },
            request_id=6,
        )

        events_result = runtime_tool_call(
            "evaluate_runtime_expression",
            {"expression": "recorded_events"},
            request_id=7,
        )
        events = events_result.get("value", [])
        if len(events) < 2:
            raise AssertionError(f"Expected runtime script to record joypad events: {events_result}")
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

        print("runtime joypad input flow verified")
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
