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


def wait_for_server(timeout_seconds: float = 30.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            rpc_call("tools/list")
            return
        except Exception:
            time.sleep(0.5)
    raise TimeoutError("Timed out waiting for MCP server on port 9080")


def wait_for_runtime(timeout_seconds: float = 15.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        info = tool_call("get_runtime_info", request_id=50)
        if info.get("status") == "success":
            return
        time.sleep(0.5)
    raise TimeoutError("Timed out waiting for runtime probe")


def runtime_tool_call(name: str, arguments: dict, request_id: int, timeout_seconds: float = 8.0) -> dict:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        result = tool_call(name, arguments, request_id=request_id)
        if result.get("status") != "pending":
            return result
        time.sleep(0.5)
    raise TimeoutError(f"Timed out waiting for runtime tool {name}")


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

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") != "success":
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_result = tool_call("run_project", {"scene_path": SCENE_PATH}, request_id=4)
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")

        wait_for_runtime()

        initial_color = runtime_tool_call(
            "get_runtime_theme_item",
            {"node_path": button_path, "item_type": "color", "item_name": "font_color"},
            request_id=5,
        )
        if initial_color.get("has_item") is not True:
            raise AssertionError(f"Expected runtime theme color to resolve: {initial_color}")
        if initial_color.get("has_override") is not False:
            raise AssertionError(f"Color override should be absent before set: {initial_color}")

        updated_color = runtime_tool_call(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "color",
                "item_name": "font_color",
                "value": {"r": 0.25, "g": 0.5, "b": 0.75, "a": 1.0},
            },
            request_id=6,
        )
        if updated_color.get("has_override") is not True:
            raise AssertionError(f"Expected color override after update: {updated_color}")

        font_size = runtime_tool_call(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "font_size",
                "item_name": "font_size",
                "value": 22,
            },
            request_id=7,
        )
        if font_size.get("value") != 22:
            raise AssertionError(f"Expected font size override to apply: {font_size}")

        separation = runtime_tool_call(
            "set_runtime_theme_override",
            {
                "node_path": button_path,
                "item_type": "constant",
                "item_name": "h_separation",
                "value": 13,
            },
            request_id=8,
        )
        if separation.get("value") != 13:
            raise AssertionError(f"Expected constant override to apply: {separation}")

        stylebox = runtime_tool_call(
            "get_runtime_theme_item",
            {"node_path": button_path, "item_type": "stylebox", "item_name": "normal"},
            request_id=9,
        )
        if stylebox.get("has_item") is not True:
            raise AssertionError(f"Expected stylebox item to resolve: {stylebox}")
        if stylebox.get("value", {}).get("resource_class") == "":
            raise AssertionError(f"Expected stylebox resource metadata: {stylebox}")

        cleared_color = runtime_tool_call(
            "clear_runtime_theme_override",
            {"node_path": button_path, "item_type": "color", "item_name": "font_color"},
            request_id=10,
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
