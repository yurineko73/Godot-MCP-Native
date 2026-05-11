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
TEMP_DIR = REPO_ROOT / ".tmp_runtime_viewport_capture"
SCENE_PATH = "res://.tmp_runtime_viewport_capture/runtime_viewport_scene.tscn"
SCRIPT_PATH = "res://.tmp_runtime_viewport_capture/runtime_viewport_setup.gd"
CAPTURE_PATH = "res://.tmp_runtime_viewport_capture/subviewport_capture.png"
SCENE_FILE = TEMP_DIR / "runtime_viewport_scene.tscn"
SCRIPT_FILE = TEMP_DIR / "runtime_viewport_setup.gd"

SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_runtime_viewport_capture/runtime_viewport_setup.gd" id="1_script"]

[node name="ViewportRoot" type="Node2D"]
script = ExtResource("1_script")
""".strip() + "\n"

SCRIPT_TEXT = """
extends Node2D

func _ready() -> void:
\tvar viewport := SubViewport.new()
\tviewport.name = "CaptureViewport"
\tviewport.size = Vector2i(128, 72)
\tviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
\tadd_child(viewport)

\tvar viewport_root := Node2D.new()
\tviewport_root.name = "ViewportWorld"
\tviewport.add_child(viewport_root)

\tvar color_rect := ColorRect.new()
\tcolor_rect.name = "ColorFill"
\tcolor_rect.color = Color(1.0, 0.2, 0.3, 1.0)
\tcolor_rect.size = Vector2(128, 72)
\tviewport.add_child(color_rect)
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








def wait_for_editor_scene_state_to_stabilize(delay_seconds: float = 3.0) -> dict:
    time.sleep(delay_seconds)
    try:
        current_scene = tool_call("get_current_scene", {}, request_id=150)
    except AssertionError as exc:
        if "No scene is currently open" not in str(exc):
            raise
        current_scene = {"error": "No scene is currently open"}
    open_scenes = tool_call("list_open_scenes", {}, request_id=151)
    return {"current_scene": current_scene, "open_scenes": open_scenes}


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


def wait_for_runtime_ready(timeout_seconds: float = 12.0, start_request_id: int = 400) -> dict:
    deadline = time.time() + timeout_seconds
    request_id = start_request_id
    last_result = None
    while time.time() < deadline:
        last_result = tool_call("get_runtime_info", {"timeout_ms": 2000}, request_id=request_id)
        if last_result.get("status") in {"success", "stale"} and last_result.get("current_scene"):
            return last_result
        time.sleep(0.5)
        request_id += 1
    raise AssertionError(f"Runtime probe never became ready: {last_result}")


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
        wait_for_editor_scene_state_to_stabilize()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {"get_runtime_screenshot"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime screenshot tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")
        wait_for_current_scene(SCENE_PATH)

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_result = tool_call("run_project", {"scene_path": SCENE_PATH}, request_id=4)
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")
        wait_for_active_debugger_session()
        wait_for_runtime_ready()

        capture = runtime_tool_call(
            "get_runtime_screenshot",
            {
                "save_path": CAPTURE_PATH,
                "format": "png",
                "viewport_path": "/root/ViewportRoot/CaptureViewport",
            },
            request_id=5,
        )
        if capture.get("save_path") != CAPTURE_PATH:
            raise AssertionError(f"Unexpected viewport capture save path: {capture}")
        if capture.get("width") != 128 or capture.get("height") != 72:
            raise AssertionError(f"Expected SubViewport capture size 128x72: {capture}")
        if capture.get("viewport_path") != "/root/ViewportRoot/CaptureViewport":
            raise AssertionError(f"Expected viewport_path echo in capture result: {capture}")

        capture_file = TEMP_DIR / "subviewport_capture.png"
        if not capture_file.exists() or capture_file.stat().st_size <= 0:
            raise AssertionError(f"Expected runtime viewport capture image on disk: {capture_file}")

        print("runtime viewport capture flow verified")
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
