import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"


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

        first_page = tool_call(
            "get_editor_logs",
            {"source": "mcp", "count": 1, "offset": 0, "order": "asc"},
            request_id=100,
        )
        if first_page.get("count") != 1 or first_page.get("total_available", 0) < 1:
            raise AssertionError(f"Unexpected first get_editor_logs page sizing: {first_page}")
        if first_page.get("truncated") is not True or first_page.get("has_more") is not True:
            raise AssertionError(f"Expected paged get_editor_logs metadata on first page: {first_page}")
        next_cursor = first_page.get("next_cursor")
        if not isinstance(next_cursor, int):
            raise AssertionError(f"Expected integer next_cursor from first get_editor_logs page: {first_page}")

        second_page = tool_call(
            "get_editor_logs",
            {"source": "mcp", "count": 1, "offset": next_cursor, "order": "asc"},
            request_id=101,
        )
        if second_page.get("count") != 1:
            raise AssertionError(f"Expected second get_editor_logs page to contain one log: {second_page}")
        if second_page.get("logs") == first_page.get("logs"):
            raise AssertionError(f"Expected second get_editor_logs page to advance beyond the first window: {second_page}")

        print("debug log pagination flow verified")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main())
