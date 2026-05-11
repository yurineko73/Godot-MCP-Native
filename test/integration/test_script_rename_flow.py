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
TEMP_DIR = REPO_ROOT / ".tmp_script_rename"
GD_SCRIPT_PATH = "res://.tmp_script_rename/temp_rename_target.gd"
GD_USAGE_PATH = "res://.tmp_script_rename/temp_rename_usage.gd"
CS_USAGE_PATH = "res://.tmp_script_rename/temp_rename_usage.cs"
SCENE_USAGE_PATH = "res://.tmp_script_rename/temp_rename_scene.tscn"
GD_SCRIPT_FILE = TEMP_DIR / "temp_rename_target.gd"
GD_USAGE_FILE = TEMP_DIR / "temp_rename_usage.gd"
CS_USAGE_FILE = TEMP_DIR / "temp_rename_usage.cs"
SCENE_USAGE_FILE = TEMP_DIR / "temp_rename_scene.tscn"

GD_SCRIPT_TEXT = """
class_name TempRenameTarget
extends Node

const DEFAULT_SPEED := 12

var display_name: String = "runner"

func ready_up() -> void:
    pass
""".strip() + "\n"

GD_USAGE_TEXT = """
extends Node

func _ready() -> void:
    var node := TempRenameTarget.new()
    node.ready_up()
    print(node.display_name, TempRenameTarget.DEFAULT_SPEED)
""".strip() + "\n"

CS_USAGE_TEXT = """
using Godot;

public partial class TempRenameUsage : Node
{
    public override void _Ready()
    {
        var node = new TempRenameTarget();
    }
}
""".strip() + "\n"

SCENE_USAGE_TEXT = """
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://.tmp_script_rename/temp_rename_target.gd" id="1_script"]

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


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


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
        expected_tools = {"rename_script_symbol"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected script rename tools: {missing_tools}")

        preview = tool_call(
            "rename_script_symbol",
            {
                "symbol_name": "TempRenameTarget",
                "new_name": "TempRenameRenamed",
                "search_path": "res://.tmp_script_rename",
                "include_extensions": [".gd", ".cs"],
                "dry_run": True,
            },
            request_id=2,
        )
        if preview.get("dry_run") is not True:
            raise AssertionError(f"Expected dry_run preview result: {preview}")
        if preview.get("replacement_count") != 4:
            raise AssertionError(f"Expected four textual replacements in preview: {preview}")
        if "TempRenameRenamed" in read_text(GD_SCRIPT_FILE):
            raise AssertionError("Dry run should not modify files")

        apply_result = tool_call(
            "rename_script_symbol",
            {
                "symbol_name": "TempRenameTarget",
                "new_name": "TempRenameRenamed",
                "search_path": "res://.tmp_script_rename",
                "include_extensions": [".gd", ".cs"],
                "dry_run": False,
            },
            request_id=3,
        )
        if apply_result.get("dry_run") is not False:
            raise AssertionError(f"Expected apply result: {apply_result}")
        if apply_result.get("replacement_count") != 4:
            raise AssertionError(f"Expected four textual replacements during apply: {apply_result}")
        changed_paths = {entry["script_path"] for entry in apply_result.get("changed_files", [])}
        if changed_paths != {GD_SCRIPT_PATH, GD_USAGE_PATH, CS_USAGE_PATH}:
            raise AssertionError(f"Unexpected changed files: {apply_result}")

        gd_target_text = read_text(GD_SCRIPT_FILE)
        gd_usage_text = read_text(GD_USAGE_FILE)
        cs_usage_text = read_text(CS_USAGE_FILE)
        scene_text = read_text(SCENE_USAGE_FILE)
        if "TempRenameRenamed" not in gd_target_text:
            raise AssertionError("Expected target GDScript file to be renamed")
        if "TempRenameRenamed" not in gd_usage_text or "TempRenameRenamed" not in cs_usage_text:
            raise AssertionError("Expected usage files to be renamed")
        if "TempRenameRenamed" in scene_text:
            raise AssertionError("Scene file should remain unchanged when .tscn is excluded")

        print("script rename flow verified")
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
