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
TEMP_DIR = REPO_ROOT / ".tmp_script_references"
GD_SCRIPT_PATH = "res://.tmp_script_references/temp_reference_target.gd"
GD_USAGE_PATH = "res://.tmp_script_references/temp_reference_usage.gd"
CS_USAGE_PATH = "res://.tmp_script_references/temp_reference_usage.cs"
SCENE_USAGE_PATH = "res://.tmp_script_references/temp_reference_scene.tscn"
GD_SCRIPT_FILE = TEMP_DIR / "temp_reference_target.gd"
GD_USAGE_FILE = TEMP_DIR / "temp_reference_usage.gd"
CS_USAGE_FILE = TEMP_DIR / "temp_reference_usage.cs"
SCENE_USAGE_FILE = TEMP_DIR / "temp_reference_scene.tscn"

GD_SCRIPT_TEXT = """
class_name TempReferenceTarget
extends Node

signal spawned(node_path: NodePath)

const DEFAULT_SPEED := 12

var display_name: String = "runner"

func ready_up() -> void:
    pass
""".strip() + "\n"

GD_USAGE_TEXT = """
extends Node

func _ready() -> void:
    var node := TempReferenceTarget.new()
    node.ready_up()
    print(node.display_name, TempReferenceTarget.DEFAULT_SPEED)
    node.spawned.connect(_on_spawned)

func _on_spawned(node_path: NodePath) -> void:
    pass
""".strip() + "\n"

CS_USAGE_TEXT = """
using Godot;

public partial class TempReferenceUsage : Node
{
    public override void _Ready()
    {
        var node = new TempReferenceTarget();
        node.ReadyUp();
    }
}
""".strip() + "\n"

SCENE_USAGE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_script_references/temp_reference_target.gd" id="1_script"]

[node name="RefScene" type="Node"]
script = ExtResource("1_script")
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


def collect_paths(result: dict) -> set[str]:
    return {entry["script_path"] for entry in result.get("references", [])}


def main() -> int:
    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    GD_SCRIPT_FILE.write_text(GD_SCRIPT_TEXT, encoding="utf-8")
    GD_USAGE_FILE.write_text(GD_USAGE_TEXT, encoding="utf-8")
    CS_USAGE_FILE.write_text(CS_USAGE_TEXT, encoding="utf-8")
    SCENE_USAGE_FILE.write_text(SCENE_USAGE_TEXT, encoding="utf-8")

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
        expected_tools = {"find_script_symbol_references"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected script reference tools: {missing_tools}")

        class_refs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "TempReferenceTarget",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd", ".cs", ".tscn"],
            },
            request_id=2,
        )
        class_ref_paths = collect_paths(class_refs)
        expected_class_paths = {GD_USAGE_PATH, CS_USAGE_PATH}
        if class_ref_paths != expected_class_paths:
            raise AssertionError(f"Unexpected class reference paths: {class_refs}")

        method_refs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "ready_up",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd"],
            },
            request_id=3,
        )
        if collect_paths(method_refs) != {GD_USAGE_PATH}:
            raise AssertionError(f"Unexpected method reference paths: {method_refs}")

        property_refs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "display_name",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd"],
            },
            request_id=4,
        )
        if collect_paths(property_refs) != {GD_USAGE_PATH}:
            raise AssertionError(f"Unexpected property reference paths: {property_refs}")

        signal_refs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "spawned",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd"],
            },
            request_id=5,
        )
        if collect_paths(signal_refs) != {GD_USAGE_PATH}:
            raise AssertionError(f"Unexpected signal reference paths: {signal_refs}")

        include_defs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "TempReferenceTarget",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd", ".cs", ".tscn"],
                "include_definitions": True,
            },
            request_id=6,
        )
        if GD_SCRIPT_PATH not in collect_paths(include_defs):
            raise AssertionError(f"Expected definitions to be included when requested: {include_defs}")

        paged_refs = tool_call(
            "find_script_symbol_references",
            {
                "symbol_name": "TempReferenceTarget",
                "search_path": "res://.tmp_script_references",
                "include_extensions": [".gd", ".cs", ".tscn"],
                "max_results": 1,
            },
            request_id=7,
        )
        if paged_refs.get("count") != 1 or paged_refs.get("truncated") is not True:
            raise AssertionError(f"Expected truncated paged reference result: {paged_refs}")
        if paged_refs.get("has_more") is not True or paged_refs.get("max_results_applied") != 1:
            raise AssertionError(f"Expected rerun metadata on paged reference result: {paged_refs}")
        if paged_refs.get("next_max_results") != 2:
            raise AssertionError(f"Expected next_max_results=2 on paged reference result: {paged_refs}")

        print("script references flow verified")
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
