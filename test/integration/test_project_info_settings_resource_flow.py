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

        resource_uris = {resource["uri"] for resource in resource_list()}
        expected_uris = {"godot://project/info", "godot://project/settings"}
        missing = sorted(expected_uris - resource_uris)
        if missing:
            raise AssertionError(f"Missing project info/settings resources: {missing}")

        tool_info = tool_call("get_project_info", {}, request_id=2)
        resource_info = resource_read("godot://project/info", request_id=3)

        if resource_info.get("name") != tool_info.get("project_name"):
            raise AssertionError(f"Project info name drifted from tool truth: {resource_info} vs {tool_info}")
        if resource_info.get("version") != tool_info.get("project_version"):
            raise AssertionError(f"Project info version drifted from tool truth: {resource_info} vs {tool_info}")
        if resource_info.get("description") != tool_info.get("project_description"):
            raise AssertionError(f"Project info description drifted from tool truth: {resource_info} vs {tool_info}")
        if resource_info.get("main_scene") != tool_info.get("main_scene"):
            raise AssertionError(f"Project info main_scene drifted from tool truth: {resource_info} vs {tool_info}")
        if resource_info.get("project_path") != tool_info.get("project_path"):
            raise AssertionError(f"Project info project_path drifted from tool truth: {resource_info} vs {tool_info}")
        if resource_info.get("godot_version") != tool_info.get("godot_version"):
            raise AssertionError(f"Project info godot_version drifted from tool truth: {resource_info} vs {tool_info}")
        if not isinstance(resource_info.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in project info resource: {resource_info}")

        tool_application = tool_call("get_project_settings", {"filter": "application/"}, request_id=4)
        tool_display = tool_call("get_project_settings", {"filter": "display/"}, request_id=5)
        tool_rendering = tool_call("get_project_settings", {"filter": "rendering/"}, request_id=6)
        resource_settings = resource_read("godot://project/settings", request_id=7)

        tool_settings: dict[str, str] = {}
        for tool_result in (tool_application, tool_display, tool_rendering):
            tool_settings.update(tool_result.get("settings", {}))
        resource_settings_normalized = {
            key: str(value) for key, value in resource_settings.get("settings", {}).items()
        }

        if resource_settings.get("count") != len(tool_settings):
            raise AssertionError(
                f"Project settings resource count drifted from tool truth: {resource_settings} vs {tool_settings}"
            )
        if resource_settings_normalized != tool_settings:
            raise AssertionError(
                f"Project settings resource payload drifted from tool truth: {resource_settings_normalized} vs {tool_settings}"
            )
        if not isinstance(resource_settings.get("timestamp"), (int, float)):
            raise AssertionError(f"Expected timestamp in project settings resource: {resource_settings}")

        print("project info/settings resource flow verified")
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
