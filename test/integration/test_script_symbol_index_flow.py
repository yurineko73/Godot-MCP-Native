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
TEMP_DIR = REPO_ROOT / ".tmp_script_symbol_index"
GD_SCRIPT_PATH = "res://.tmp_script_symbol_index/temp_symbol_target.gd"
CS_SCRIPT_PATH = "res://.tmp_script_symbol_index/temp_symbol_target.cs"
GD_SCRIPT_FILE = TEMP_DIR / "temp_symbol_target.gd"
CS_SCRIPT_FILE = TEMP_DIR / "temp_symbol_target.cs"

GD_SCRIPT_TEXT = """
class_name TempSymbolTarget
extends Node

signal spawned(node_path: NodePath)

const DEFAULT_SPEED := 12

var display_name: String = "runner"
var _hidden_state: int = 0

func ready_up() -> void:
    pass

func process_step(delta: float) -> void:
    pass
""".strip() + "\n"

CS_SCRIPT_TEXT = """
using Godot;

public partial class TempSymbolSharp : Node
{
    public const int DefaultLives = 3;
    public float Speed { get; set; } = 4.5f;

    [Signal]
    public delegate void SpawnedEventHandler(NodePath nodePath);

    public void ReadyUp()
    {
    }
}
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
    GD_SCRIPT_FILE.write_text(GD_SCRIPT_TEXT, encoding="utf-8")
    CS_SCRIPT_FILE.write_text(CS_SCRIPT_TEXT, encoding="utf-8")

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
        expected_tools = {"list_project_script_symbols"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected script symbol tools: {missing_tools}")

        result = tool_call(
            "list_project_script_symbols",
            {
                "search_path": "res://.tmp_script_symbol_index",
                "include_extensions": [".gd", ".cs"],
            },
            request_id=2,
        )

        if result.get("count") != 2:
            raise AssertionError(f"Expected exactly two indexed scripts: {result}")

        scripts = {entry["script_path"]: entry for entry in result["scripts"]}
        gd_entry = scripts.get(GD_SCRIPT_PATH)
        cs_entry = scripts.get(CS_SCRIPT_PATH)
        if gd_entry is None or cs_entry is None:
            raise AssertionError(f"Missing expected script entries: {result}")

        if gd_entry.get("class_name") != "TempSymbolTarget":
            raise AssertionError(f"Unexpected GDScript class metadata: {gd_entry}")
        if gd_entry.get("extends_from") != "Node":
            raise AssertionError(f"Unexpected GDScript extends metadata: {gd_entry}")
        if "ready_up" not in gd_entry.get("functions", []):
            raise AssertionError(f"Expected ready_up function in GDScript entry: {gd_entry}")
        if "spawned" not in gd_entry.get("signals", []):
            raise AssertionError(f"Expected spawned signal in GDScript entry: {gd_entry}")
        if "display_name" not in gd_entry.get("properties", []):
            raise AssertionError(f"Expected display_name property in GDScript entry: {gd_entry}")
        if "DEFAULT_SPEED" not in gd_entry.get("constants", []):
            raise AssertionError(f"Expected DEFAULT_SPEED constant in GDScript entry: {gd_entry}")

        if cs_entry.get("class_name") != "TempSymbolSharp":
            raise AssertionError(f"Unexpected C# class metadata: {cs_entry}")
        if cs_entry.get("extends_from") != "Node":
            raise AssertionError(f"Unexpected C# extends metadata: {cs_entry}")
        if "ReadyUp" not in cs_entry.get("functions", []):
            raise AssertionError(f"Expected ReadyUp function in C# entry: {cs_entry}")
        if "Spawned" not in cs_entry.get("signals", []):
            raise AssertionError(f"Expected Spawned signal in C# entry: {cs_entry}")
        if "Speed" not in cs_entry.get("properties", []):
            raise AssertionError(f"Expected Speed property in C# entry: {cs_entry}")
        if "DefaultLives" not in cs_entry.get("constants", []):
            raise AssertionError(f"Expected DefaultLives constant in C# entry: {cs_entry}")

        filtered_result = tool_call(
            "list_project_script_symbols",
            {
                "search_path": "res://.tmp_script_symbol_index",
                "include_extensions": [".gd", ".cs"],
                "name_filter": "ready",
                "symbol_kinds": ["function"],
            },
            request_id=3,
        )
        if filtered_result.get("count") != 2:
            raise AssertionError(f"Expected both scripts to match filtered function search: {filtered_result}")

        print("script symbol index flow verified")
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
