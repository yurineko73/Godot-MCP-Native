import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"
TEMP_DIR = REPO_ROOT / "test" / "integration" / "temp_project_test_runner"
TEMP_TEST_PATH = "res://test/integration/temp_project_test_runner/temp_integration_test.py"
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
    child_env = os.environ.copy()
    python_dir = str(Path(sys.executable).resolve().parent)
    path_parts = child_env.get("PATH", "").split(os.pathsep) if child_env.get("PATH") else []
    if python_dir not in path_parts:
        path_parts.insert(0, python_dir)
    child_env["PATH"] = os.pathsep.join(path_parts)
    process = subprocess.Popen(
        args,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=REPO_ROOT,
        env=child_env,
    )

    try:
        wait_for_server()

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {"list_project_tests", "list_project_test_runners", "inspect_project_test", "run_project_test"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected project test runner tools: {missing_tools}")

        runners = tool_call(
            "list_project_test_runners",
            {},
            request_id=15,
        )
        if runners.get("count") != 2:
            raise AssertionError(f"Expected python and gut runner availability entries: {runners}")
        runners_by_framework = {entry["framework"]: entry for entry in runners["runners"]}
        if sorted(runners_by_framework.keys()) != ["gut", "python"]:
            raise AssertionError(f"Unexpected runner availability frameworks: {runners}")
        if runners_by_framework["python"].get("available") is not True:
            raise AssertionError(f"Expected python runner to be available after PATH injection: {runners}")

        resources_response = rpc_call("resources/list", request_id=16)
        resource_uris = {resource["uri"] for resource in resources_response["result"]["resources"]}
        if "godot://project/test_runners" not in resource_uris:
            raise AssertionError(f"Expected godot://project/test_runners resource to be registered: {resources_response}")
        if "godot://project/tests" not in resource_uris:
            raise AssertionError(f"Expected godot://project/tests resource to be registered: {resources_response}")

        resource_read = rpc_call(
            "resources/read",
            {"uri": "godot://project/test_runners"},
            request_id=17,
        )
        resource_payload = json.loads(resource_read["result"]["contents"][0]["text"])
        if resource_payload.get("count") != runners.get("count"):
            raise AssertionError(f"Expected project test runner resource count to match tool result: {resource_payload} vs {runners}")
        if sorted(entry["framework"] for entry in resource_payload.get("runners", [])) != ["gut", "python"]:
            raise AssertionError(f"Unexpected frameworks in project test runner resource: {resource_payload}")
        resource_runners = {entry["framework"]: entry for entry in resource_payload["runners"]}
        if resource_runners["python"].get("available") != runners_by_framework["python"].get("available"):
            raise AssertionError(f"Expected python runner availability to match between tool and resource: {resource_payload} vs {runners}")
        if resource_runners["gut"].get("available") != runners_by_framework["gut"].get("available"):
            raise AssertionError(f"Expected gut runner availability to match between tool and resource: {resource_payload} vs {runners}")

        listed = tool_call(
            "list_project_tests",
            {"search_path": "res://test/integration/temp_project_test_runner"},
            request_id=2,
        )
        if listed.get("count") != 1:
            raise AssertionError(f"Expected one discovered temporary project test: {listed}")
        test_entry = listed["tests"][0]
        if test_entry.get("test_path") != TEMP_TEST_PATH:
            raise AssertionError(f"Unexpected discovered test path: {test_entry}")
        if test_entry.get("framework") != "python":
            raise AssertionError(f"Expected python integration test entry: {test_entry}")
        if test_entry.get("runnable") != runners_by_framework["python"].get("available"):
            raise AssertionError(f"Expected discovered python test to mirror python runner availability: {test_entry}")
        tests_resource = rpc_call(
            "resources/read",
            {"uri": "godot://project/tests"},
            request_id=18,
        )
        tests_resource_payload = json.loads(tests_resource["result"]["contents"][0]["text"])
        if tests_resource_payload.get("search_path") != "res://test/":
            raise AssertionError(f"Expected default search_path in project tests resource: {tests_resource_payload}")
        resource_test_entry = next(
            (entry for entry in tests_resource_payload.get("tests", []) if entry.get("test_path") == TEMP_TEST_PATH),
            None,
        )
        if resource_test_entry is None:
            raise AssertionError(f"Expected temporary project test in project tests resource: {tests_resource_payload}")
        if resource_test_entry.get("framework") != test_entry.get("framework"):
            raise AssertionError(f"Expected resource test framework to match tool entry: {resource_test_entry} vs {test_entry}")
        if resource_test_entry.get("runnable") != test_entry.get("runnable"):
            raise AssertionError(f"Expected resource test runnable to match tool entry: {resource_test_entry} vs {test_entry}")
        if resource_test_entry.get("available_runner") != test_entry.get("available_runner"):
            raise AssertionError(f"Expected resource test available_runner to match tool entry: {resource_test_entry} vs {test_entry}")

        inspected = tool_call(
            "inspect_project_test",
            {"test_path": TEMP_TEST_PATH},
            request_id=21,
        )
        if inspected.get("test_path") != TEMP_TEST_PATH:
            raise AssertionError(f"Expected inspect_project_test to echo path: {inspected}")
        if inspected.get("exists") is not True:
            raise AssertionError(f"Expected inspect_project_test to report exists=true: {inspected}")
        if inspected.get("framework") != test_entry.get("framework"):
            raise AssertionError(f"Expected inspect_project_test framework to match list entry: {inspected}")
        if inspected.get("kind") != test_entry.get("kind"):
            raise AssertionError(f"Expected inspect_project_test kind to match list entry: {inspected}")
        if inspected.get("runnable") != test_entry.get("runnable"):
            raise AssertionError(f"Expected inspect_project_test runnable to match list entry: {inspected}")
        if inspected.get("available_runner") != test_entry.get("available_runner"):
            raise AssertionError(f"Expected inspect_project_test available_runner to match list entry: {inspected}")
        if inspected.get("name") != test_entry.get("name"):
            raise AssertionError(f"Expected inspect_project_test name to match list entry: {inspected}")

        gut_inspected = tool_call(
            "inspect_project_test",
            {"test_path": "res://test/unit/test_mcp_tool_classifier.gd"},
            request_id=22,
        )
        if gut_inspected.get("framework") != "gut":
            raise AssertionError(f"Expected known unit test to inspect as gut: {gut_inspected}")
        if gut_inspected.get("available_runner") != runners_by_framework["gut"].get("available"):
            raise AssertionError(f"Expected gut inspection to mirror gut runner availability: {gut_inspected}")
        if gut_inspected.get("runnable") != runners_by_framework["gut"].get("available"):
            raise AssertionError(f"Expected gut runnable truth to mirror gut runner availability: {gut_inspected}")

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
