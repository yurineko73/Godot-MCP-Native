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
TEMP_DIR = REPO_ROOT / ".tmp_generated_scene_screenshot"
SCENE_PATH = "res://.tmp_generated_scene_screenshot/generated_capture_scene.tscn"
CAPTURE_PATH = "res://.tmp_generated_scene_screenshot/generated_capture.png"
SCENE_FILE = TEMP_DIR / "generated_capture_scene.tscn"
CAPTURE_FILE = TEMP_DIR / "generated_capture.png"
STDOUT_FILE = TEMP_DIR / "godot_stdout.log"
STDERR_FILE = TEMP_DIR / "godot_stderr.log"

SCENE_TEXT = """
[gd_scene format=3]

[node name="GeneratedCaptureRoot" type="Node2D"]

[node name="Quad" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, 0, 128, 0, 128, 72, 0, 72)
color = Color(0.9, 0.25, 0.35, 1)
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
    stdout_handle = STDOUT_FILE.open("w", encoding="utf-8")
    stderr_handle = STDERR_FILE.open("w", encoding="utf-8")
    process = subprocess.Popen(
        args,
        stdout=stdout_handle,
        stderr=stderr_handle,
        cwd=REPO_ROOT,
    )

    succeeded = False
    try:
        wait_for_server()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "open_scene",
            "get_current_scene",
            "get_scene_tree",
            "get_editor_screenshot",
            "compare_render_screenshots",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected screenshot tools: {missing_tools}")

        open_scene_result = tool_call(
            "open_scene",
            {"scene_path": SCENE_PATH, "allow_ui_focus": True},
            request_id=2,
        )
        if open_scene_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_scene_result}")

        current_scene = tool_call("get_current_scene", {}, request_id=3)
        if current_scene.get("scene_path") != SCENE_PATH:
            raise AssertionError(f"Generated scene did not become current: {current_scene}")
        if current_scene.get("scene_name") != "GeneratedCaptureRoot":
            raise AssertionError(f"Unexpected generated scene name: {current_scene}")
        if current_scene.get("root_node_type") != "Node2D":
            raise AssertionError(f"Unexpected generated scene root type: {current_scene}")
        if current_scene.get("node_count") != 2:
            raise AssertionError(f"Unexpected generated scene node count: {current_scene}")

        scene_tree = tool_call("get_scene_tree", {"max_depth": 2}, request_id=4)
        if scene_tree.get("scene_name") != "GeneratedCaptureRoot":
            raise AssertionError(f"Unexpected scene tree payload: {scene_tree}")
        if scene_tree.get("total_nodes") != 2:
            raise AssertionError(f"Unexpected scene tree total_nodes: {scene_tree}")
        tree_root = scene_tree.get("tree", {})
        if tree_root.get("path") != "/root/GeneratedCaptureRoot":
            raise AssertionError(f"Unexpected scene tree root path: {scene_tree}")
        children = tree_root.get("children", [])
        if len(children) != 1 or children[0].get("name") != "Quad" or children[0].get("type") != "Polygon2D":
            raise AssertionError(f"Unexpected generated scene tree child structure: {scene_tree}")

        capture = tool_call(
            "get_editor_screenshot",
            {
                "scene_path": SCENE_PATH,
                "save_path": CAPTURE_PATH,
                "viewport_width": 128,
                "viewport_height": 72,
                "format": "png",
            },
            request_id=5,
        )
        if capture.get("status") != "success":
            raise AssertionError(f"Screenshot capture failed: {capture}")
        if capture.get("scene_path") != SCENE_PATH:
            raise AssertionError(f"Unexpected scene_path in capture payload: {capture}")
        if not CAPTURE_FILE.exists() or CAPTURE_FILE.stat().st_size <= 0:
            raise AssertionError("Expected generated scene screenshot file to exist and be non-empty")

        compare = tool_call(
            "compare_render_screenshots",
            {
                "baseline_path": CAPTURE_PATH,
                "candidate_path": CAPTURE_PATH,
                "max_diff_pixels": 0,
            },
            request_id=6,
        )
        if compare.get("matches") is not True:
            raise AssertionError(f"Expected screenshot to match itself: {compare}")
        if compare.get("width") != 128 or compare.get("height") != 72:
            raise AssertionError(f"Unexpected captured dimensions: {compare}")
        if compare.get("diff_pixel_count") != 0:
            raise AssertionError(f"Expected zero diff pixels when comparing the same image: {compare}")

        print("generated scene screenshot flow verified")
        succeeded = True
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
        finally:
            stdout_handle.close()
            stderr_handle.close()

        if not succeeded:
            print("--- Godot stdout ---")
            print(STDOUT_FILE.read_text(encoding="utf-8"))
            print("--- Godot stderr ---")
            print(STDERR_FILE.read_text(encoding="utf-8"))

        if TEMP_DIR.exists():
            shutil.rmtree(TEMP_DIR, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
