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
TEMP_DIR = REPO_ROOT / "test" / "integration" / ".tmp_project_test_runner"
TEMP_TEST_PATH = "res://test/integration/.tmp_project_test_runner/temp_integration_test.py"
TEMP_TEST_FILE = TEMP_DIR / "temp_integration_test.py"

TEMP_TEST_SCRIPT = """
from pathlib import Path
import sys

print("temp integration runner script starting")
print(Path(__file__).name)
sys.exit(0)
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
    TEMP_TEST_FILE.write_text(TEMP_TEST_SCRIPT, encoding="utf-8")

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
        expected_tools = {"list_project_tests", "run_project_test"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected project test runner tools: {missing_tools}")

        listed = tool_call(
            "list_project_tests",
            {"search_path": "res://test/integration/.tmp_project_test_runner"},
            request_id=2,
        )
        if listed.get("count") != 1:
            raise AssertionError(f"Expected one discovered temporary project test: {listed}")
        test_entry = listed["tests"][0]
        if test_entry.get("test_path") != TEMP_TEST_PATH:
            raise AssertionError(f"Unexpected discovered test path: {test_entry}")
        if test_entry.get("framework") != "python":
            raise AssertionError(f"Expected python integration test entry: {test_entry}")
        if test_entry.get("runnable") is not True:
            raise AssertionError(f"Expected discovered python test to be runnable: {test_entry}")

        run_result = tool_call(
            "run_project_test",
            {"test_path": TEMP_TEST_PATH, "timeout_ms": 30000},
            request_id=3,
        )
        if run_result.get("status") != "passed":
            raise AssertionError(f"Expected temporary project test to pass: {run_result}")
        if run_result.get("framework") != "python":
            raise AssertionError(f"Expected python framework in run result: {run_result}")
        if run_result.get("exit_code") != 0:
            raise AssertionError(f"Expected zero exit code in run result: {run_result}")
        output = "\n".join(run_result.get("output", []))
        if "temp integration runner script starting" not in output:
            raise AssertionError(f"Expected temp script stdout in run result: {run_result}")

        print("project test runner flow verified")
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
