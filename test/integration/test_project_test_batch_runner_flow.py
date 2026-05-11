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
TEMP_DIR = REPO_ROOT / "test" / "integration" / ".tmp_project_test_batch_runner"
PASS_TEST_PATH = "res://test/integration/.tmp_project_test_batch_runner/temp_pass_test.py"
FAIL_TEST_PATH = "res://test/integration/.tmp_project_test_batch_runner/temp_fail_test.py"
PASS_TEST_FILE = TEMP_DIR / "temp_pass_test.py"
FAIL_TEST_FILE = TEMP_DIR / "temp_fail_test.py"

PASS_TEST_SCRIPT = """
print("temporary pass test running")
raise SystemExit(0)
""".strip() + "\n"

FAIL_TEST_SCRIPT = """
print("temporary fail test running")
raise SystemExit(3)
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
    PASS_TEST_FILE.write_text(PASS_TEST_SCRIPT, encoding="utf-8")
    FAIL_TEST_FILE.write_text(FAIL_TEST_SCRIPT, encoding="utf-8")

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
        expected_tools = {"run_project_tests"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected project batch test runner tools: {missing_tools}")

        run_result = tool_call(
            "run_project_tests",
            {"search_path": "res://test/integration/.tmp_project_test_batch_runner", "framework": "python"},
            request_id=2,
        )
        if run_result.get("status") != "failed":
            raise AssertionError(f"Expected aggregate batch status to be failed when one test fails: {run_result}")
        if run_result.get("total_count") != 2:
            raise AssertionError(f"Expected two discovered tests in batch run: {run_result}")
        if run_result.get("passed_count") != 1 or run_result.get("failed_count") != 1:
            raise AssertionError(f"Expected one passing and one failing batch result: {run_result}")
        results = {entry["test_path"]: entry for entry in run_result.get("results", [])}
        if PASS_TEST_PATH not in results or FAIL_TEST_PATH not in results:
            raise AssertionError(f"Expected both temporary tests in batch results: {run_result}")
        if results[PASS_TEST_PATH].get("status") != "passed":
            raise AssertionError(f"Expected pass test to pass in batch runner: {results[PASS_TEST_PATH]}")
        if results[FAIL_TEST_PATH].get("status") != "failed" or results[FAIL_TEST_PATH].get("exit_code") != 3:
            raise AssertionError(f"Expected fail test to fail with exit code 3 in batch runner: {results[FAIL_TEST_PATH]}")

        print("project test batch runner flow verified")
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
