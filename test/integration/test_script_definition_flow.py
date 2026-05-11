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
TEMP_DIR = REPO_ROOT / ".tmp_script_definition"
GD_SCRIPT_PATH = "res://.tmp_script_definition/temp_definition_target.gd"
CS_SCRIPT_PATH = "res://.tmp_script_definition/temp_definition_target.cs"
GD_SCRIPT_FILE = TEMP_DIR / "temp_definition_target.gd"
CS_SCRIPT_FILE = TEMP_DIR / "temp_definition_target.cs"

GD_SCRIPT_TEXT = """
class_name TempDefinitionTarget
extends Node

signal spawned(node_path: NodePath)

const DEFAULT_SPEED := 12

var display_name: String = "runner"

func ready_up() -> void:
    pass
""".strip() + "\n"

CS_SCRIPT_TEXT = """
using Godot;

public partial class TempDefinitionSharp : Node
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


def expect_single_definition(result: dict, script_path: str, symbol_name: str, symbol_kind: str, line: int) -> None:
    if result.get("count") != 1:
        raise AssertionError(f"Expected exactly one definition for {symbol_name}: {result}")
    definition = result["definitions"][0]
    if definition.get("script_path") != script_path:
        raise AssertionError(f"Unexpected script path for {symbol_name}: {definition}")
    if definition.get("symbol_name") != symbol_name:
        raise AssertionError(f"Unexpected symbol name for {symbol_name}: {definition}")
    if definition.get("symbol_kind") != symbol_kind:
        raise AssertionError(f"Unexpected symbol kind for {symbol_name}: {definition}")
    if definition.get("line") != line:
        raise AssertionError(f"Unexpected line for {symbol_name}: {definition}")


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
        expected_tools = {"find_script_symbol_definition"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected script definition tools: {missing_tools}")

        expect_single_definition(
            tool_call(
                "find_script_symbol_definition",
                {"symbol_name": "ready_up", "search_path": "res://.tmp_script_definition"},
                request_id=2,
            ),
            GD_SCRIPT_PATH,
            "ready_up",
            "function",
            10,
        )

        expect_single_definition(
            tool_call(
                "find_script_symbol_definition",
                {"symbol_name": "DEFAULT_SPEED", "search_path": "res://.tmp_script_definition", "symbol_kinds": ["constant"]},
                request_id=3,
            ),
            GD_SCRIPT_PATH,
            "DEFAULT_SPEED",
            "constant",
            6,
        )

        expect_single_definition(
            tool_call(
                "find_script_symbol_definition",
                {"symbol_name": "ReadyUp", "search_path": "res://.tmp_script_definition", "include_extensions": [".cs"]},
                request_id=4,
            ),
            CS_SCRIPT_PATH,
            "ReadyUp",
            "function",
            11,
        )

        filtered_result = tool_call(
            "find_script_symbol_definition",
            {
                "symbol_name": "spawned",
                "search_path": "res://.tmp_script_definition",
                "symbol_kinds": ["signal"],
                "preferred_script_path": GD_SCRIPT_PATH,
            },
            request_id=5,
        )
        expect_single_definition(filtered_result, GD_SCRIPT_PATH, "spawned", "signal", 4)

        print("script definition flow verified")
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
