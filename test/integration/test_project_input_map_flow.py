import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
MCP_URL = "http://127.0.0.1:9080/mcp"
ACTION_NAME = "mcp_temp_project_input_action"
SETTING_NAME = "mcp/integration/temp_string_setting"


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

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "list_project_input_actions",
            "inspect_project_input_action",
            "upsert_project_input_action",
            "remove_project_input_action",
            "set_project_setting",
            "inspect_project_setting",
            "clear_project_setting",
            "execute_editor_script",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected project input tools: {missing_tools}")

        tool_call("remove_project_input_action", {"action_name": ACTION_NAME}, request_id=2)

        upsert_result = tool_call(
            "upsert_project_input_action",
            {
                "action_name": ACTION_NAME,
                "deadzone": 0.33,
                "erase_existing": True,
                "events": [
                    {"type": "key", "keycode": 65, "pressed": True},
                    {"type": "mouse_button", "button_index": 1, "pressed": True},
                ],
            },
            request_id=3,
        )
        if upsert_result.get("action_name") != ACTION_NAME:
            raise AssertionError(f"Unexpected upsert action payload: {upsert_result}")
        if abs(upsert_result.get("deadzone", 0.0) - 0.33) > 1e-6:
            raise AssertionError(f"Unexpected project action deadzone: {upsert_result}")
        if upsert_result.get("event_count") != 2:
            raise AssertionError(f"Expected two stored project action events: {upsert_result}")

        list_result = tool_call(
            "list_project_input_actions",
            {"action_name": ACTION_NAME},
            request_id=4,
        )
        if list_result.get("count") != 1:
            raise AssertionError(f"Expected one filtered project input action: {list_result}")
        action_entry = list_result["actions"][0]
        if action_entry.get("setting_name") != f"input/{ACTION_NAME}":
            raise AssertionError(f"Unexpected project input setting name: {action_entry}")
        event_types = sorted(event.get("type") for event in action_entry.get("events", []))
        if event_types != ["key", "mouse_button"]:
            raise AssertionError(f"Unexpected project input events: {action_entry}")

        inspected_action = tool_call(
            "inspect_project_input_action",
            {"action_name": ACTION_NAME},
            request_id=41,
        )
        if inspected_action.get("exists") is not True:
            raise AssertionError(f"Expected project input action inspection to report exists=true: {inspected_action}")
        if abs(inspected_action.get("deadzone", 0.0) - 0.33) > 1e-6:
            raise AssertionError(f"Expected project input action inspection to report deadzone: {inspected_action}")
        if inspected_action.get("event_count") != 2:
            raise AssertionError(f"Expected project input action inspection to report event count: {inspected_action}")
        inspected_event_types = sorted(event.get("type") for event in inspected_action.get("events", []))
        if inspected_event_types != ["key", "mouse_button"]:
            raise AssertionError(f"Expected project input action inspection to serialize events: {inspected_action}")

        settings_check = tool_call(
            "execute_editor_script",
            {
                "code": f"""
var value = ProjectSettings.get_setting("input/{ACTION_NAME}", {{}})
var result = {{
    "exists": ProjectSettings.has_setting("input/{ACTION_NAME}"),
    "deadzone": float(value.get("deadzone", 0.0)),
    "event_count": value.get("events", []).size()
}}
_custom_print(JSON.stringify(result))
""",
            },
            request_id=5,
        )
        if settings_check.get("success") is not True or not settings_check.get("output"):
            raise AssertionError(f"execute_editor_script failed: {settings_check}")
        setting_payload = json.loads(settings_check["output"][-1])
        if setting_payload != {"exists": True, "deadzone": 0.33, "event_count": 2}:
            raise AssertionError(f"Unexpected project settings payload: {setting_payload}")

        set_setting_result = tool_call(
            "set_project_setting",
            {
                "setting_name": SETTING_NAME,
                "setting_value": "integration-value",
            },
            request_id=6,
        )
        if set_setting_result.get("status") != "success":
            raise AssertionError(f"Expected successful project setting write: {set_setting_result}")
        if set_setting_result.get("persisted_value") != "integration-value":
            raise AssertionError(f"Expected persisted project setting value echo: {set_setting_result}")

        inspected_setting = tool_call(
            "inspect_project_setting",
            {
                "setting_name": SETTING_NAME,
            },
            request_id=61,
        )
        if inspected_setting.get("exists") is not True:
            raise AssertionError(f"Expected project setting inspection to report exists=true: {inspected_setting}")
        if inspected_setting.get("value_type") != "String":
            raise AssertionError(f"Expected project setting inspection to report String type: {inspected_setting}")
        if inspected_setting.get("persisted_value") != "integration-value":
            raise AssertionError(f"Expected project setting inspection to echo persisted value: {inspected_setting}")

        settings_list = tool_call(
            "get_project_settings",
            {"filter": "mcp/integration/"},
            request_id=7,
        )
        if settings_list.get("count") != 1:
            raise AssertionError(f"Expected one filtered custom project setting: {settings_list}")
        if settings_list.get("settings", {}).get(SETTING_NAME) != "integration-value":
            raise AssertionError(f"Expected MCP settings readback for custom project setting: {settings_list}")

        custom_setting_check = tool_call(
            "execute_editor_script",
            {
                "code": f"""
var result = {{
    "exists": ProjectSettings.has_setting("{SETTING_NAME}"),
    "value": str(ProjectSettings.get_setting("{SETTING_NAME}", ""))
}}
_custom_print(JSON.stringify(result))
""",
            },
            request_id=8,
        )
        if custom_setting_check.get("success") is not True or not custom_setting_check.get("output"):
            raise AssertionError(f"execute_editor_script failed for custom setting check: {custom_setting_check}")
        custom_setting_payload = json.loads(custom_setting_check["output"][-1])
        if custom_setting_payload != {"exists": True, "value": "integration-value"}:
            raise AssertionError(f"Unexpected custom project setting payload: {custom_setting_payload}")

        clear_setting_result = tool_call(
            "clear_project_setting",
            {
                "setting_name": SETTING_NAME,
            },
            request_id=9,
        )
        if clear_setting_result.get("status") != "success":
            raise AssertionError(f"Expected successful project setting clear: {clear_setting_result}")
        if clear_setting_result.get("removed") is not True:
            raise AssertionError(f"Expected removed=true after project setting clear: {clear_setting_result}")
        if clear_setting_result.get("previous_value") != "integration-value":
            raise AssertionError(f"Expected previous_value echo during project setting clear: {clear_setting_result}")

        post_clear_settings = tool_call(
            "get_project_settings",
            {"filter": "mcp/integration/"},
            request_id=10,
        )
        if post_clear_settings.get("count") != 0:
            raise AssertionError(f"Expected cleared custom project setting to disappear from filtered readback: {post_clear_settings}")

        inspected_cleared_setting = tool_call(
            "inspect_project_setting",
            {
                "setting_name": SETTING_NAME,
            },
            request_id=62,
        )
        if inspected_cleared_setting.get("exists") is not False:
            raise AssertionError(f"Expected cleared project setting inspection to report exists=false: {inspected_cleared_setting}")

        post_clear_check = tool_call(
            "execute_editor_script",
            {
                "code": f"""
var result = {{
    "exists": ProjectSettings.has_setting("{SETTING_NAME}")
}}
_custom_print(JSON.stringify(result))
""",
            },
            request_id=11,
        )
        if post_clear_check.get("success") is not True or not post_clear_check.get("output"):
            raise AssertionError(f"execute_editor_script failed for post-clear check: {post_clear_check}")
        post_clear_payload = json.loads(post_clear_check["output"][-1])
        if post_clear_payload != {"exists": False}:
            raise AssertionError(f"Expected custom project setting to be absent after clear: {post_clear_payload}")

        remove_result = tool_call(
            "remove_project_input_action",
            {"action_name": ACTION_NAME},
            request_id=12,
        )
        if remove_result.get("removed") is not True or remove_result.get("event_count") != 2:
            raise AssertionError(f"Expected project input action removal to succeed: {remove_result}")

        post_remove = tool_call(
            "list_project_input_actions",
            {"action_name": ACTION_NAME},
            request_id=13,
        )
        if post_remove.get("count") != 0:
            raise AssertionError(f"Expected project input action to be removed: {post_remove}")

        inspected_removed_action = tool_call(
            "inspect_project_input_action",
            {"action_name": ACTION_NAME},
            request_id=42,
        )
        if inspected_removed_action.get("exists") is not False:
            raise AssertionError(f"Expected removed project input action inspection to report exists=false: {inspected_removed_action}")

        print("project input map flow verified")
        return 0
    finally:
        try:
            tool_call("remove_project_input_action", {"action_name": ACTION_NAME}, request_id=99)
        except Exception:
            pass
        try:
            tool_call(
                "execute_editor_script",
                {
                    "code": f"""
if ProjectSettings.has_setting("{SETTING_NAME}"):
    ProjectSettings.clear("{SETTING_NAME}")
    ProjectSettings.save()
_custom_print(JSON.stringify({{"cleared": true}}))
""",
                },
                request_id=100,
            )
        except Exception:
            pass
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main())
