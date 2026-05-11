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
TEMP_DIR = REPO_ROOT / ".tmp_runtime_memory_trend"
SCENE_PATH = "res://.tmp_runtime_memory_trend/runtime_memory_scene.tscn"
SCENE_FILE = TEMP_DIR / "runtime_memory_scene.tscn"

SCENE_TEXT = """
[gd_scene format=3]

[node name="MemoryRoot" type="Node2D"]

[node name="MemoryChild" type="Node2D" parent="."]
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
        expected_tools = {"get_runtime_memory_trend"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected runtime memory trend tools: {missing_tools}")

        open_result = tool_call("open_scene", {"scene_path": SCENE_PATH}, request_id=2)
        if open_result.get("status") != "success":
            raise AssertionError(f"open_scene failed: {open_result}")

        install_result = tool_call("install_runtime_probe", {}, request_id=3)
        if install_result.get("status") != "success":
            raise AssertionError(f"install_runtime_probe failed: {install_result}")

        run_result = tool_call("run_project", {"scene_path": SCENE_PATH}, request_id=4)
        if run_result.get("status") != "success":
            raise AssertionError(f"run_project failed: {run_result}")

        trend = runtime_tool_call(
            "get_runtime_memory_trend",
            {"sample_count": 3, "sample_interval_ms": 100, "timeout_ms": 4000},
            request_id=5,
        )
        if trend.get("sample_count") != 3:
            raise AssertionError(f"Expected exactly three samples in memory trend: {trend}")
        samples = trend.get("samples", [])
        if len(samples) != 3:
            raise AssertionError(f"Expected three memory trend samples: {trend}")
        for index, sample in enumerate(samples):
            for field in ("sample_index", "timestamp_ms", "memory_static_bytes", "memory_static_mb", "object_count", "resource_count"):
                if field not in sample:
                    raise AssertionError(f"Missing memory trend sample field {field}: {trend}")
            if sample["sample_index"] != index:
                raise AssertionError(f"Expected sequential sample indexes: {trend}")
            if not isinstance(sample["memory_static_bytes"], int):
                raise AssertionError(f"Expected integer memory bytes: {sample}")
        if trend.get("current_scene") != "/root/MemoryRoot":
            raise AssertionError(f"Unexpected runtime scene path in memory trend: {trend}")
        if trend.get("memory_static_delta_bytes") is None:
            raise AssertionError(f"Expected memory delta field in trend result: {trend}")

        print("runtime memory trend flow verified")
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
