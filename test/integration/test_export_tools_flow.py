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
EXPORT_PRESETS_PATH = REPO_ROOT / "export_presets.cfg"
EXPORT_DIR = REPO_ROOT / ".tmp_export"
EXPORT_PACK_PATH = EXPORT_DIR / "integration_test_export.pck"

EXPORT_PRESETS_TEXT = """
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="res://.tmp_export/integration_test_export.exe"
script_export_mode=1

[preset.0.options]
custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
codesign/enable=false
application/modify_resources=false
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
    EXPORT_DIR.mkdir(exist_ok=True)
    previous_export_presets = EXPORT_PRESETS_PATH.read_text(encoding="utf-8") if EXPORT_PRESETS_PATH.exists() else None
    EXPORT_PRESETS_PATH.write_text(EXPORT_PRESETS_TEXT, encoding="utf-8")
    if EXPORT_PACK_PATH.exists():
        EXPORT_PACK_PATH.unlink()

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
            "list_export_presets",
            "validate_export_preset",
            "inspect_export_templates",
            "run_export",
        }
        missing = sorted(expected_tools - tool_names)
        if missing:
            raise AssertionError(f"Missing expected export tools: {missing}")

        presets_result = tool_call("list_export_presets", {}, request_id=2)
        if presets_result["count"] < 1:
            raise AssertionError(f"Expected at least one export preset, got: {presets_result}")
        preset_names = {preset["name"] for preset in presets_result["presets"]}
        if "Windows Desktop" not in preset_names:
            raise AssertionError(f"Expected Windows Desktop preset, got: {preset_names}")

        validate_result = tool_call(
            "validate_export_preset",
            {"preset": "Windows Desktop"},
            request_id=3,
        )
        if "valid" not in validate_result:
            raise AssertionError(f"validate_export_preset returned unexpected payload: {validate_result}")
        if validate_result["errors"]:
            raise AssertionError(f"validate_export_preset reported hard errors: {validate_result}")

        templates_result = tool_call("inspect_export_templates", {}, request_id=4)
        if "templates_root" not in templates_result:
            raise AssertionError(f"inspect_export_templates returned unexpected payload: {templates_result}")

        export_result = tool_call(
            "run_export",
            {
                "preset": "Windows Desktop",
                "output_path": str(EXPORT_PACK_PATH),
                "mode": "pack",
            },
            request_id=5,
        )
        if templates_result.get("matching_version_installed"):
            if not export_result["success"]:
                raise AssertionError(f"run_export failed even though templates are installed: {export_result}")
            if not EXPORT_PACK_PATH.exists():
                raise AssertionError(f"Expected export artifact at {EXPORT_PACK_PATH}")
            if EXPORT_PACK_PATH.stat().st_size <= 0:
                raise AssertionError(f"Export artifact is empty: {EXPORT_PACK_PATH}")
        else:
            if export_result["success"] and EXPORT_PACK_PATH.exists():
                if EXPORT_PACK_PATH.stat().st_size <= 0:
                    raise AssertionError(f"Export artifact is empty: {EXPORT_PACK_PATH}")
            elif not export_result["errors"]:
                raise AssertionError(
                    "run_export should either succeed or return structured export errors when templates are missing: "
                    f"{export_result}"
                )

        print("export tools flow verified")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)

        if previous_export_presets is None:
            if EXPORT_PRESETS_PATH.exists():
                EXPORT_PRESETS_PATH.unlink()
        else:
            EXPORT_PRESETS_PATH.write_text(previous_export_presets, encoding="utf-8")

        if EXPORT_DIR.exists():
            shutil.rmtree(EXPORT_DIR, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
