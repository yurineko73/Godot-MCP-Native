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
TEMP_DIR = REPO_ROOT / ".tmp_render_regression_compare"
BASELINE_PATH = "res://.tmp_render_regression_compare/baseline.png"
CANDIDATE_PATH = "res://.tmp_render_regression_compare/candidate.png"
BASELINE_FILE = TEMP_DIR / "baseline.png"
CANDIDATE_FILE = TEMP_DIR / "candidate.png"


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
        expected_tools = {"compare_render_screenshots", "execute_editor_script"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected render compare tools: {missing_tools}")

        script = f"""
var baseline := Image.create(2, 2, false, Image.FORMAT_RGBA8)
baseline.fill(Color(1, 0, 0, 1))
baseline.save_png("{BASELINE_PATH}")

var candidate := Image.create(2, 2, false, Image.FORMAT_RGBA8)
candidate.fill(Color(1, 0, 0, 1))
candidate.set_pixel(1, 1, Color(0, 1, 0, 1))
candidate.save_png("{CANDIDATE_PATH}")
_custom_print("images_written")
"""
        setup = tool_call("execute_editor_script", {"code": script}, request_id=2)
        if setup.get("success") is not True:
            raise AssertionError(f"execute_editor_script failed: {setup}")
        if not BASELINE_FILE.exists() or not CANDIDATE_FILE.exists():
            raise AssertionError("Expected baseline and candidate images to be created")

        compare = tool_call(
            "compare_render_screenshots",
            {
                "baseline_path": BASELINE_PATH,
                "candidate_path": CANDIDATE_PATH,
                "max_diff_pixels": 0,
            },
            request_id=3,
        )
        if compare.get("baseline_path") != BASELINE_PATH or compare.get("candidate_path") != CANDIDATE_PATH:
            raise AssertionError(f"Unexpected compare payload: {compare}")
        if compare.get("width") != 2 or compare.get("height") != 2:
            raise AssertionError(f"Unexpected image dimensions: {compare}")
        if compare.get("diff_pixel_count") != 1:
            raise AssertionError(f"Expected exactly one differing pixel: {compare}")
        if compare.get("matches") is not False:
            raise AssertionError(f"Expected compare to fail strict pixel threshold: {compare}")
        if compare.get("max_channel_delta", 0.0) <= 0.0:
            raise AssertionError(f"Expected non-zero max delta: {compare}")

        print("render regression compare flow verified")
        return 0
    finally:
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
