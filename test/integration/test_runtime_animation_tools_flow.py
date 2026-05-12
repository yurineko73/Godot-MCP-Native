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
TEMP_DIR = REPO_ROOT / ".tmp_runtime_animation_tools"
SCENE_PATH = "res://.tmp_runtime_animation_tools/runtime_animation_scene.tscn"
SCRIPT_PATH = "res://.tmp_runtime_animation_tools/runtime_animation_setup.gd"
SCENE_FILE = TEMP_DIR / "runtime_animation_scene.tscn"
SCRIPT_FILE = TEMP_DIR / "runtime_animation_setup.gd"

SCENE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_runtime_animation_tools/runtime_animation_setup.gd" id="1_script"]

[node name="AnimationRoot" type="Node2D"]
script = ExtResource("1_script")
""".strip() + "\n"

SCRIPT_TEXT = """
extends Node2D

func _ready() -> void:
\tvar player := AnimationPlayer.new()
\tplayer.name = "Animator"
\tadd_child(player)

\tvar library := AnimationLibrary.new()
\tvar idle_animation := Animation.new()
\tidle_animation.length = 1.0
\tvar run_animation := Animation.new()
\trun_animation.length = 5.0
\tlibrary.add_animation("idle", idle_animation)
\tlibrary.add_animation("run", run_animation)
\tplayer.add_animation_library("", library)

\tvar tree := AnimationTree.new()
\ttree.name = "AnimTree"
\tadd_child(tree)
\ttree.anim_player = NodePath("../Animator")

\tvar state_machine := AnimationNodeStateMachine.new()
\tvar idle_node := AnimationNodeAnimation.new()
\tidle_node.animation = "idle"
\tvar run_node := AnimationNodeAnimation.new()
\trun_node.animation = "run"
\tstate_machine.add_node("Idle", idle_node, Vector2.ZERO)
\tstate_machine.add_node("Run", run_node, Vector2(200, 0))
\tstate_machine.add_transition("Idle", "Run", AnimationNodeStateMachineTransition.new())
\tstate_machine.add_transition("Run", "Idle", AnimationNodeStateMachineTransition.new())
\ttree.tree_root = state_machine
\ttree.active = false
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


def get_latest_debugger_sequence(request_id: int = 5100) -> int:
    messages = get_debugger_messages(count=1, request_id=request_id).get("messages", [])
    if not messages:
        return 0
    return int(messages[0].get("sequence", 0))


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
                prime_runtime_probe(start_request_id=request_id + 21, minimum_node_count=5)
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


def dispatch_runtime_tool(name: str, arguments: dict, request_id: int) -> dict:
    result = tool_call(name, arguments, request_id=request_id)
    if result.get("status") not in {"success", "pending"}:
        raise AssertionError(f"{name} did not dispatch cleanly: {result}")
    return result


def wait_for_debugger_message(
    message_name: str,
    predicate,
    minimum_sequence: int = 0,
    timeout_seconds: float = 10.0,
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


def run_once() -> None:
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

    animator_path = "/root/AnimationRoot/Animator"
    tree_path = "/root/AnimationRoot/AnimTree"

    try:
        wait_for_server()
        wait_for_editor_scene_state_to_stabilize()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "list_runtime_animations",
            "play_runtime_animation",
            "stop_runtime_animation",
            "get_runtime_animation_state",
            "get_runtime_animation_tree_state",
            "set_runtime_animation_tree_active",
            "travel_runtime_animation_tree",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime animation tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")
        wait_for_current_scene(SCENE_PATH)

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") not in {"success", "already_installed"}:
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_project_until_debugger_active(SCENE_PATH)

        animations = dispatch_runtime_tool_until_message(
            "list_runtime_animations",
            {"node_path": animator_path, "timeout_ms": 2000},
            "mcp:animation_list",
            lambda payload: payload
            and payload.get("node_path") == animator_path
            and payload.get("count", 0) >= 2
            and any(anim.get("name") == "run" for anim in payload.get("animations", [])),
            attempts=3,
            start_request_id=1000,
        )
        if not any(anim.get("name") == "run" and abs(float(anim.get("length", 0.0)) - 5.0) < 1e-6 for anim in animations.get("animations", [])):
            raise AssertionError(f"Expected runtime animation list to include run length 5.0: {animations}")

        started = dispatch_runtime_tool_until_message(
            "play_runtime_animation",
            {
                "node_path": animator_path,
                "animation_name": "run",
                "custom_speed": 1.5,
                "timeout_ms": 2000,
            },
            "mcp:animation_started",
            lambda payload: payload
            and payload.get("node_path") == animator_path
            and payload.get("current_animation") == "run"
            and payload.get("is_playing") is True,
            attempts=3,
            start_request_id=1100,
        )
        if abs(float(started.get("playing_speed", 0.0)) - 1.5) > 1e-6:
            raise AssertionError(f"Expected runtime animation to play at speed 1.5: {started}")

        state = dispatch_runtime_tool_until_message(
            "get_runtime_animation_state",
            {"node_path": animator_path, "timeout_ms": 2000},
            "mcp:animation_state",
            lambda payload: payload
            and payload.get("node_path") == animator_path
            and payload.get("current_animation") == "run"
            and payload.get("is_playing") is True,
            attempts=3,
            start_request_id=1200,
        )
        if abs(float(state.get("current_length", 0.0)) - 5.0) > 1e-6:
            raise AssertionError(f"Expected runtime animation state length 5.0: {state}")

        tree_state = dispatch_runtime_tool_until_message(
            "get_runtime_animation_tree_state",
            {"node_path": tree_path, "timeout_ms": 2000},
            "mcp:animation_tree_state",
            lambda payload: payload
            and payload.get("node_path") == tree_path
            and payload.get("tree_root_type") == "AnimationNodeStateMachine",
            attempts=3,
            start_request_id=1300,
        )
        if tree_state.get("active") is not False:
            raise AssertionError(f"Expected AnimationTree to start inactive: {tree_state}")

        active_state = dispatch_runtime_tool_until_message(
            "set_runtime_animation_tree_active",
            {"node_path": tree_path, "active": True, "timeout_ms": 2000},
            "mcp:animation_tree_active_updated",
            lambda payload: payload
            and payload.get("node_path") == tree_path
            and payload.get("active") is True,
            attempts=3,
            start_request_id=1400,
        )
        if active_state.get("tree_root_type") != "AnimationNodeStateMachine":
            raise AssertionError(f"Expected AnimationTree root type after activation: {active_state}")

        travelled = dispatch_runtime_tool_until_message(
            "travel_runtime_animation_tree",
            {"node_path": tree_path, "state_name": "Run", "timeout_ms": 2000},
            "mcp:animation_tree_travelled",
            lambda payload: payload
            and payload.get("node_path") == tree_path
            and payload.get("current_node") == "Run",
            attempts=3,
            start_request_id=1500,
        )
        if travelled.get("current_node") != "Run":
            raise AssertionError(f"Expected AnimationTree current node Run after travel: {travelled}")

        stopped = dispatch_runtime_tool_until_message(
            "stop_runtime_animation",
            {"node_path": animator_path, "timeout_ms": 2000},
            "mcp:animation_stopped",
            lambda payload: payload
            and payload.get("node_path") == animator_path
            and payload.get("is_playing") is False,
            attempts=3,
            start_request_id=1600,
        )
        if stopped.get("is_playing") is not False:
            raise AssertionError(f"Expected runtime animation to stop: {stopped}")
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
            print("runtime animation tools flow verified")
            return 0
        except (AssertionError, TimeoutError, urllib.error.URLError, ConnectionError) as exc:
            last_error = exc
            time.sleep(1.0)
    if last_error:
        raise last_error
    raise AssertionError("runtime animation tools flow failed without an explicit error")


if __name__ == "__main__":
    sys.exit(main())
