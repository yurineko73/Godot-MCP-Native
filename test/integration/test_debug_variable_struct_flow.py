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

        tools_response = rpc_call("tools/list")
        tool_names = {tool["name"] for tool in tools_response["result"]["tools"]}
        expected_tools = {
            "execute_editor_script",
            "get_debug_variables",
        }
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected debug variable tools: {missing_tools}")

        install_bridge = tool_call(
            "execute_editor_script",
            {
                "code": (
                    'var bridge := MCPDebuggerBridge.new()\n'
                    'bridge._latest_evaluations["vec2i_value"] = {"type": "Vector2i", "value": Vector2i(3, 4)}\n'
                    'bridge._latest_evaluations["rect2i_value"] = {"type": "Rect2i", "value": Rect2i(Vector2i(1, 2), Vector2i(5, 6))}\n'
                    'bridge._latest_evaluations["transform2d_value"] = {"type": "Transform2D", "value": Transform2D(0.25, Vector2(10, 20))}\n'
                    'bridge._latest_evaluations["vector3i_value"] = {"type": "Vector3i", "value": Vector3i(7, 8, 9)}\n'
                    'bridge._latest_evaluations["plane_value"] = {"type": "Plane", "value": Plane(Vector3(0, 1, 0), 2.5)}\n'
                    'bridge._latest_evaluations["aabb_value"] = {"type": "AABB", "value": AABB(Vector3(1, 2, 3), Vector3(4, 5, 6))}\n'
                    'bridge._latest_evaluations["basis_value"] = {"type": "Basis", "value": Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9))}\n'
                    'bridge._latest_evaluations["quaternion_value"] = {"type": "Quaternion", "value": Quaternion(0.1, 0.2, 0.3, 0.9)}\n'
                    'bridge._latest_evaluations["transform3d_value"] = {"type": "Transform3D", "value": Transform3D(Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9)), Vector3(10, 11, 12))}\n'
                    'var object_script := GDScript.new()\n'
                    'object_script.source_code = "extends RefCounted\\nvar display_name := \\"Probe\\"\\nvar hit_points := 42\\nvar grid := Vector2i(2, 3)\\n"\n'
                    'object_script.reload()\n'
                    'bridge._latest_evaluations["object_value"] = {"type": "Object", "value": object_script.new()}\n'
                    'var plugin_script := GDScript.new()\n'
                    'plugin_script.source_code = "extends RefCounted\\nvar _bridge: RefCounted\\nfunc _init(bridge: RefCounted) -> void:\\n\\t_bridge = bridge\\nfunc get_debugger_bridge() -> RefCounted:\\n\\treturn _bridge\\n"\n'
                    'plugin_script.reload()\n'
                    'var fake_plugin = plugin_script.new(bridge)\n'
                    'Engine.set_meta("GodotMCPPlugin", fake_plugin)\n'
                    '_custom_print(JSON.stringify({\n'
                    '\t"vec2i_reference": bridge.get_evaluation_variables_reference("vec2i_value"),\n'
                    '\t"rect2i_reference": bridge.get_evaluation_variables_reference("rect2i_value"),\n'
                    '\t"transform2d_reference": bridge.get_evaluation_variables_reference("transform2d_value"),\n'
                    '\t"vector3i_reference": bridge.get_evaluation_variables_reference("vector3i_value"),\n'
                    '\t"plane_reference": bridge.get_evaluation_variables_reference("plane_value"),\n'
                    '\t"aabb_reference": bridge.get_evaluation_variables_reference("aabb_value"),\n'
                    '\t"basis_reference": bridge.get_evaluation_variables_reference("basis_value"),\n'
                    '\t"quaternion_reference": bridge.get_evaluation_variables_reference("quaternion_value"),\n'
                    '\t"transform3d_reference": bridge.get_evaluation_variables_reference("transform3d_value"),\n'
                    '\t"object_reference": bridge.get_evaluation_variables_reference("object_value")\n'
                    '}))\n'
                ),
            },
            request_id=2,
        )
        if install_bridge.get("success") is not True or not install_bridge.get("output"):
            raise AssertionError(f"Failed to install real debugger bridge: {install_bridge}")
        references = json.loads(install_bridge["output"][-1])
        for key in (
            "vec2i_reference",
            "rect2i_reference",
            "transform2d_reference",
            "vector3i_reference",
            "plane_reference",
            "aabb_reference",
            "basis_reference",
            "quaternion_reference",
            "transform3d_reference",
            "object_reference",
        ):
            if references.get(key, 0) <= 0:
                raise AssertionError(f"Expected non-zero variables reference for {key}: {references}")

        vec2i_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["vec2i_reference"]},
            request_id=3,
        )
        vec2i_children = {entry["name"]: entry for entry in vec2i_variables.get("variables", [])}
        if sorted(vec2i_children) != ["x", "y"]:
            raise AssertionError(f"Unexpected Vector2i children: {vec2i_variables}")
        if vec2i_children["x"]["value"] != 3 or vec2i_children["y"]["value"] != 4:
            raise AssertionError(f"Unexpected Vector2i values: {vec2i_variables}")

        rect2i_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["rect2i_reference"]},
            request_id=4,
        )
        rect2i_children = {entry["name"]: entry for entry in rect2i_variables.get("variables", [])}
        if sorted(rect2i_children) != ["end", "position", "size"]:
            raise AssertionError(f"Unexpected Rect2i children: {rect2i_variables}")
        if rect2i_children["position"]["variables_reference"] <= 0 or rect2i_children["size"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected Rect2i nested children to be expandable: {rect2i_variables}")

        position_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": rect2i_children["position"]["variables_reference"]},
            request_id=5,
        )
        position_children = {entry["name"]: entry for entry in position_variables.get("variables", [])}
        if position_children.get("x", {}).get("value") != 1 or position_children.get("y", {}).get("value") != 2:
            raise AssertionError(f"Unexpected Rect2i.position values: {position_variables}")

        transform_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["transform2d_reference"]},
            request_id=6,
        )
        transform_children = {entry["name"]: entry for entry in transform_variables.get("variables", [])}
        if sorted(transform_children) != ["origin", "x", "y"]:
            raise AssertionError(f"Unexpected Transform2D children: {transform_variables}")
        if transform_children["origin"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected Transform2D.origin to be expandable: {transform_variables}")

        vector3i_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["vector3i_reference"]},
            request_id=7,
        )
        vector3i_children = {entry["name"]: entry for entry in vector3i_variables.get("variables", [])}
        if sorted(vector3i_children) != ["x", "y", "z"]:
            raise AssertionError(f"Unexpected Vector3i children: {vector3i_variables}")
        if (
            vector3i_children["x"]["value"] != 7
            or vector3i_children["y"]["value"] != 8
            or vector3i_children["z"]["value"] != 9
        ):
            raise AssertionError(f"Unexpected Vector3i values: {vector3i_variables}")

        plane_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["plane_reference"]},
            request_id=8,
        )
        plane_children = {entry["name"]: entry for entry in plane_variables.get("variables", [])}
        if sorted(plane_children) != ["d", "normal"]:
            raise AssertionError(f"Unexpected Plane children: {plane_variables}")
        if plane_children["normal"]["variables_reference"] <= 0 or plane_children["d"]["value"] != 2.5:
            raise AssertionError(f"Unexpected Plane values: {plane_variables}")

        aabb_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["aabb_reference"]},
            request_id=9,
        )
        aabb_children = {entry["name"]: entry for entry in aabb_variables.get("variables", [])}
        if sorted(aabb_children) != ["end", "position", "size"]:
            raise AssertionError(f"Unexpected AABB children: {aabb_variables}")
        if aabb_children["position"]["variables_reference"] <= 0 or aabb_children["size"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected AABB nested children to be expandable: {aabb_variables}")

        basis_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["basis_reference"]},
            request_id=10,
        )
        basis_children = {entry["name"]: entry for entry in basis_variables.get("variables", [])}
        if sorted(basis_children) != ["x", "y", "z"]:
            raise AssertionError(f"Unexpected Basis children: {basis_variables}")
        if basis_children["x"]["variables_reference"] <= 0 or basis_children["z"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected Basis axes to be expandable: {basis_variables}")

        quaternion_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["quaternion_reference"]},
            request_id=11,
        )
        quaternion_children = {entry["name"]: entry for entry in quaternion_variables.get("variables", [])}
        if sorted(quaternion_children) != ["w", "x", "y", "z"]:
            raise AssertionError(f"Unexpected Quaternion children: {quaternion_variables}")

        transform3d_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["transform3d_reference"]},
            request_id=12,
        )
        transform3d_children = {entry["name"]: entry for entry in transform3d_variables.get("variables", [])}
        if sorted(transform3d_children) != ["basis", "origin"]:
            raise AssertionError(f"Unexpected Transform3D children: {transform3d_variables}")
        if transform3d_children["basis"]["variables_reference"] <= 0 or transform3d_children["origin"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected Transform3D nested children to be expandable: {transform3d_variables}")

        object_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": references["object_reference"]},
            request_id=13,
        )
        object_children = {entry["name"]: entry for entry in object_variables.get("variables", [])}
        for required_name in ("display_name", "grid", "hit_points"):
            if required_name not in object_children:
                raise AssertionError(f"Missing expected object child {required_name}: {object_variables}")
        if object_children["display_name"]["value"] != "Probe" or object_children["hit_points"]["value"] != 42:
            raise AssertionError(f"Unexpected object scalar values: {object_variables}")
        if object_children["grid"]["variables_reference"] <= 0:
            raise AssertionError(f"Expected object grid property to be expandable: {object_variables}")

        object_grid_variables = tool_call(
            "get_debug_variables",
            {"variables_reference": object_children["grid"]["variables_reference"]},
            request_id=14,
        )
        object_grid_children = {entry["name"]: entry for entry in object_grid_variables.get("variables", [])}
        if object_grid_children.get("x", {}).get("value") != 2 or object_grid_children.get("y", {}).get("value") != 3:
            raise AssertionError(f"Unexpected object grid values: {object_grid_variables}")

        inspect_helpers = tool_call(
            "execute_editor_script",
            {
                "code": (
                    'var tools := DebugToolsNative.new()\n'
                    'var result := {\n'
                    '\t"vector2i_named_count": tools._debug_named_variable_count(Vector2i(8, 9)),\n'
                    '\t"basis_named_count": tools._debug_named_variable_count(Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9))),\n'
                    '\t"rect2i_has_children": tools._debug_value_has_children(Rect2i(Vector2i(1, 2), Vector2i(5, 6))),\n'
                    '\t"transform3d_has_children": tools._debug_value_has_children(Transform3D(Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9)), Vector3(10, 11, 12))),\n'
                    '\t"transform2d_serialized": tools._serialize_runtime_value(Transform2D(0.25, Vector2(10, 20))),\n'
                    '\t"transform3d_serialized": tools._serialize_runtime_value(Transform3D(Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9)), Vector3(10, 11, 12))),\n'
                    '\t"rect2i_entries": tools._expand_debug_struct_fields(Rect2i(Vector2i(1, 2), Vector2i(5, 6)), ["rect2i_value"]),\n'
                    '\t"plane_entries": tools._expand_debug_struct_fields(Plane(Vector3(0, 1, 0), 2.5), ["plane_value"]),\n'
                    '\t"object_script_source": "extends RefCounted\\nvar display_name := \\"Probe\\"\\nvar hit_points := 42\\nvar grid := Vector2i(2, 3)\\n"\n'
                    '}\n'
                    '_custom_print(JSON.stringify(result))\n'
                ),
            },
            request_id=15,
        )
        if inspect_helpers.get("success") is not True or not inspect_helpers.get("output"):
            raise AssertionError(f"Failed to inspect debug tool helpers: {inspect_helpers}")
        helper_result = json.loads(inspect_helpers["output"][-1])
        if helper_result.get("vector2i_named_count") != 2:
            raise AssertionError(f"Expected Vector2i named count 2: {helper_result}")
        if helper_result.get("basis_named_count") != 3:
            raise AssertionError(f"Expected Basis named count 3: {helper_result}")
        if helper_result.get("rect2i_has_children") is not True:
            raise AssertionError(f"Expected Rect2i to report children: {helper_result}")
        if helper_result.get("transform3d_has_children") is not True:
            raise AssertionError(f"Expected Transform3D to report children: {helper_result}")
        serialized_transform = helper_result.get("transform2d_serialized", {})
        if sorted(serialized_transform) != ["origin", "x", "y"]:
            raise AssertionError(f"Unexpected Transform2D serialization: {helper_result}")
        serialized_transform3d = helper_result.get("transform3d_serialized", {})
        if sorted(serialized_transform3d) != ["basis", "origin"]:
            raise AssertionError(f"Unexpected Transform3D serialization: {helper_result}")
        rect2i_entries = helper_result.get("rect2i_entries", [])
        if [entry.get("name") for entry in rect2i_entries] != ["position", "size", "end"]:
            raise AssertionError(f"Unexpected Rect2i helper entries: {helper_result}")
        plane_entries = helper_result.get("plane_entries", [])
        if [entry.get("name") for entry in plane_entries] != ["normal", "d"]:
            raise AssertionError(f"Unexpected Plane helper entries: {helper_result}")

        print("debug variable struct flow verified")
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
