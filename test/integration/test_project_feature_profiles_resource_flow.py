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


def resource_list(request_id: int = 200) -> list[dict]:
    response = rpc_call("resources/list", request_id=request_id)
    return response["result"]["resources"]


def resource_read(uri: str, request_id: int = 201) -> dict:
    response = rpc_call("resources/read", {"uri": uri}, request_id=request_id)
    contents = response["result"]["contents"]
    if len(contents) != 1:
        raise AssertionError(f"Expected one content item for {uri}: {contents}")
    return json.loads(contents[0]["text"])


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

        resources = resource_list()
        resource_uris = {resource["uri"] for resource in resources}
        if "godot://project/feature_profiles" not in resource_uris:
            raise AssertionError(
                f"Missing godot://project/feature_profiles in resources/list: {sorted(resource_uris)}"
            )

        tool_profiles = tool_call("list_project_feature_profiles", {}, request_id=2)
        resource_profiles = resource_read("godot://project/feature_profiles", request_id=3)

        if resource_profiles.get("count") != tool_profiles.get("count"):
            raise AssertionError(
                f"Resource count drifted from tool truth: {resource_profiles} vs {tool_profiles}"
            )
        if resource_profiles.get("current_profile") != tool_profiles.get("current_profile"):
            raise AssertionError(
                f"Resource current_profile drifted from tool truth: {resource_profiles} vs {tool_profiles}"
            )
        if resource_profiles.get("profiles") != tool_profiles.get("profiles"):
            raise AssertionError(
                f"Resource feature profile inventory drifted from tool truth: {resource_profiles} vs {tool_profiles}"
            )
        if not isinstance(resource_profiles.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in project feature profiles resource: {resource_profiles}")

        print("project feature profiles resource flow verified")
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
