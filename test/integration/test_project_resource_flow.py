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
TEMP_DIR = REPO_ROOT / ".tmp_project_resource_flow"
TEMP_RESOURCE_PATH = "res://.tmp_project_resource_flow/detail_stylebox.tres"


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
        for tool_name in ("create_resource", "list_project_resources", "inspect_project_resource", "update_project_resource_properties", "duplicate_project_resource", "delete_project_resource", "move_project_resource"):
            if tool_name not in tool_names:
                raise AssertionError(f"Missing expected tool {tool_name} in MCP tool list")

        create_result = tool_call(
            "create_resource",
            {
                "resource_path": TEMP_RESOURCE_PATH,
                "resource_type": "StyleBoxFlat",
            },
            request_id=2,
        )
        if create_result.get("status") != "success":
            raise AssertionError(f"create_resource failed: {create_result}")

        detail_result = tool_call(
            "list_project_resources",
            {
                "search_path": "res://.tmp_project_resource_flow",
                "resource_types": [".tres"],
                "include_resource_details": True,
                "max_properties": 3,
            },
            request_id=3,
        )
        if detail_result.get("count") != 1:
            raise AssertionError(f"Expected one temp resource in listing: {detail_result}")
        if not detail_result.get("details_included"):
            raise AssertionError(f"Expected details_included=true: {detail_result}")
        details = detail_result.get("resource_details", [])
        if len(details) != 1:
            raise AssertionError(f"Expected one resource detail payload: {detail_result}")
        detail = details[0]
        if detail.get("resource_path") != TEMP_RESOURCE_PATH:
            raise AssertionError(f"Unexpected resource detail path: {detail}")
        if detail.get("class_name") != "StyleBoxFlat":
            raise AssertionError(f"Unexpected resource detail class: {detail}")
        if not detail.get("is_loadable"):
            raise AssertionError(f"Expected created resource to be loadable: {detail}")
        if detail.get("returned_property_count") != len(detail.get("properties", [])):
            raise AssertionError(f"Property count metadata mismatch: {detail}")
        if detail.get("returned_property_count", 0) > 3:
            raise AssertionError(f"Returned properties exceeded requested cap: {detail}")
        if detail.get("property_count", 0) > 3:
            if not detail.get("properties_truncated"):
                raise AssertionError(f"Expected truncation metadata for capped detail view: {detail}")
            if not detail.get("has_more_properties"):
                raise AssertionError(f"Expected has_more_properties metadata for capped detail view: {detail}")
            if detail.get("next_max_properties") != 6:
                raise AssertionError(f"Expected next_max_properties=6: {detail}")

        value_result = tool_call(
            "list_project_resources",
            {
                "search_path": "res://.tmp_project_resource_flow",
                "resource_types": [".tres"],
                "include_resource_details": True,
                "include_property_values": True,
                "property_filter": "bg_color",
                "max_properties": 5,
            },
            request_id=4,
        )
        value_detail = value_result.get("resource_details", [None])[0]
        if not value_detail:
            raise AssertionError(f"Expected filtered resource detail payload: {value_result}")
        properties = value_detail.get("properties", [])
        if len(properties) != 1:
            raise AssertionError(f"Expected exactly one bg_color property entry: {value_detail}")
        if properties[0].get("name") != "bg_color":
            raise AssertionError(f"Unexpected filtered property entry: {properties[0]}")
        color_value = properties[0].get("value")
        if not isinstance(color_value, dict) or "r" not in color_value or "a" not in color_value:
            raise AssertionError(f"Expected serialized Color payload for bg_color: {properties[0]}")

        inspect_result = tool_call(
            "inspect_project_resource",
            {
                "resource_path": TEMP_RESOURCE_PATH,
                "include_property_values": True,
                "property_filter": "bg_color",
                "max_properties": 2,
            },
            request_id=5,
        )
        if inspect_result.get("resource_path") != TEMP_RESOURCE_PATH:
            raise AssertionError(f"Unexpected inspect_project_resource path: {inspect_result}")
        if inspect_result.get("class_name") != "StyleBoxFlat":
            raise AssertionError(f"Unexpected inspect_project_resource class: {inspect_result}")
        if inspect_result.get("property_filter_applied") != "bg_color":
            raise AssertionError(f"Expected echoed property filter: {inspect_result}")
        if inspect_result.get("include_property_values") is not True:
            raise AssertionError(f"Expected include_property_values echo: {inspect_result}")
        if inspect_result.get("property_count") != 1 or inspect_result.get("returned_property_count") != 1:
            raise AssertionError(f"Expected a single filtered property in inspect_project_resource: {inspect_result}")
        inspect_properties = inspect_result.get("properties", [])
        if len(inspect_properties) != 1 or inspect_properties[0].get("name") != "bg_color":
            raise AssertionError(f"Expected one bg_color property entry: {inspect_result}")
        inspect_color = inspect_properties[0].get("value")
        if not isinstance(inspect_color, dict) or "r" not in inspect_color or "a" not in inspect_color:
            raise AssertionError(f"Expected serialized Color payload from inspect_project_resource: {inspect_result}")

        update_result = tool_call(
            "update_project_resource_properties",
            {
                "resource_path": TEMP_RESOURCE_PATH,
                "properties": {
                    "bg_color": {"r": 0.15, "g": 0.25, "b": 0.35, "a": 1.0},
                    "corner_radius_top_left": 11,
                },
            },
            request_id=6,
        )
        if update_result.get("status") != "success":
            raise AssertionError(f"Expected successful resource update: {update_result}")
        if update_result.get("updated_property_count") != 2:
            raise AssertionError(f"Expected exactly two updated properties: {update_result}")
        if update_result.get("updated_properties") != ["bg_color", "corner_radius_top_left"]:
            raise AssertionError(f"Expected sorted updated property echo: {update_result}")

        updated_inspect = tool_call(
            "inspect_project_resource",
            {
                "resource_path": TEMP_RESOURCE_PATH,
                "include_property_values": True,
                "property_filter": "bg_color",
                "max_properties": 5,
            },
            request_id=7,
        )
        updated_properties = updated_inspect.get("properties", [])
        if len(updated_properties) != 1 or updated_properties[0].get("name") != "bg_color":
            raise AssertionError(f"Expected one updated bg_color property entry: {updated_inspect}")
        updated_color = updated_properties[0].get("value")
        if not isinstance(updated_color, dict):
            raise AssertionError(f"Expected serialized bg_color payload after update: {updated_inspect}")
        if abs(updated_color.get("r", 0.0) - 0.15) > 0.0001:
            raise AssertionError(f"Expected persisted bg_color.r=0.15 after update: {updated_inspect}")

        duplicate_path = "res://.tmp_project_resource_flow/detail_stylebox_copy.tres"
        duplicate_result = tool_call(
            "duplicate_project_resource",
            {
                "source_path": TEMP_RESOURCE_PATH,
                "destination_path": duplicate_path,
            },
            request_id=8,
        )
        if duplicate_result.get("status") != "success":
            raise AssertionError(f"Expected successful resource duplication: {duplicate_result}")
        if duplicate_result.get("destination_path") != duplicate_path:
            raise AssertionError(f"Expected echoed duplicate destination path: {duplicate_result}")

        duplicate_inspect = tool_call(
            "inspect_project_resource",
            {
                "resource_path": duplicate_path,
                "include_property_values": True,
                "property_filter": "bg_color",
                "max_properties": 5,
            },
            request_id=9,
        )
        duplicate_properties = duplicate_inspect.get("properties", [])
        if len(duplicate_properties) != 1 or duplicate_properties[0].get("name") != "bg_color":
            raise AssertionError(f"Expected one bg_color property entry on duplicated resource: {duplicate_inspect}")
        duplicate_color = duplicate_properties[0].get("value")
        if not isinstance(duplicate_color, dict):
            raise AssertionError(f"Expected serialized bg_color payload from duplicated resource: {duplicate_inspect}")
        if abs(duplicate_color.get("r", 0.0) - 0.15) > 0.0001:
            raise AssertionError(f"Expected duplicated resource to preserve updated bg_color.r=0.15: {duplicate_inspect}")

        delete_result = tool_call(
            "delete_project_resource",
            {
                "resource_path": duplicate_path,
            },
            request_id=10,
        )
        if delete_result.get("status") != "success":
            raise AssertionError(f"Expected successful resource deletion: {delete_result}")
        if delete_result.get("removed") is not True:
            raise AssertionError(f"Expected removed=true after resource deletion: {delete_result}")

        deleted_response = rpc_call(
            "tools/call",
            {
                "name": "inspect_project_resource",
                "arguments": {
                    "resource_path": duplicate_path,
                    "include_property_values": True,
                    "property_filter": "bg_color",
                    "max_properties": 5,
                },
            },
            request_id=11,
        )
        deleted_result = deleted_response["result"]
        if not deleted_result.get("isError"):
            raise AssertionError(f"Expected deleted resource inspection to fail: {deleted_result}")
        deleted_payload = {}
        if deleted_result.get("content"):
            deleted_payload = json.loads(deleted_result["content"][0]["text"])
        if deleted_payload.get("error") != f"File not found: {duplicate_path}":
            raise AssertionError(f"Expected deleted resource to become unreadable through inspect_project_resource: {deleted_result}")

        moved_path = "res://.tmp_project_resource_flow/moved/detail_stylebox_renamed.tres"
        move_result = tool_call(
            "move_project_resource",
            {
                "source_path": TEMP_RESOURCE_PATH,
                "destination_path": moved_path,
            },
            request_id=12,
        )
        if move_result.get("status") != "success":
            raise AssertionError(f"Expected successful resource move: {move_result}")
        if move_result.get("moved") is not True:
            raise AssertionError(f"Expected moved=true after resource move: {move_result}")
        if move_result.get("destination_path") != moved_path:
            raise AssertionError(f"Expected echoed move destination path: {move_result}")

        moved_inspect = tool_call(
            "inspect_project_resource",
            {
                "resource_path": moved_path,
                "include_property_values": True,
                "property_filter": "bg_color",
                "max_properties": 5,
            },
            request_id=13,
        )
        moved_properties = moved_inspect.get("properties", [])
        if len(moved_properties) != 1 or moved_properties[0].get("name") != "bg_color":
            raise AssertionError(f"Expected one bg_color property entry on moved resource: {moved_inspect}")
        moved_color = moved_properties[0].get("value")
        if not isinstance(moved_color, dict):
            raise AssertionError(f"Expected serialized bg_color payload from moved resource: {moved_inspect}")
        if abs(moved_color.get("r", 0.0) - 0.15) > 0.0001:
            raise AssertionError(f"Expected moved resource to preserve updated bg_color.r=0.15: {moved_inspect}")

        moved_source_response = rpc_call(
            "tools/call",
            {
                "name": "inspect_project_resource",
                "arguments": {
                    "resource_path": TEMP_RESOURCE_PATH,
                    "include_property_values": True,
                    "property_filter": "bg_color",
                    "max_properties": 5,
                },
            },
            request_id=14,
        )
        moved_source_result = moved_source_response["result"]
        if not moved_source_result.get("isError"):
            raise AssertionError(f"Expected moved source inspection to fail: {moved_source_result}")
        moved_source_payload = {}
        if moved_source_result.get("content"):
            moved_source_payload = json.loads(moved_source_result["content"][0]["text"])
        if moved_source_payload.get("error") != f"File not found: {TEMP_RESOURCE_PATH}":
            raise AssertionError(f"Expected moved source to become unreadable through inspect_project_resource: {moved_source_result}")

        print("project resource inspection flow verified")
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
