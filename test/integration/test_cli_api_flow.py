import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")
BASE_URL = os.environ.get("GDMCP_TEST_URL", "http://127.0.0.1:9080")
API_HEADERS = {"X-GDMCP-API-Version": "1"}

def request_json(method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    data = None
    headers = dict(API_HEADERS)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read().decode("utf-8"))

def wait_for_cli(timeout_seconds: float = 30.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            status, payload = request_json("GET", "/cli/v1/doctor")
            if status == 200 and payload.get("api_version") == 1:
                return
        except Exception:
            pass
        time.sleep(0.5)
    raise TimeoutError("Timed out waiting for the gdmcp CLI API")

def assert_success(status: int, payload: dict) -> dict:
    if status != 200 or not payload.get("ok", True):
        raise AssertionError(f"Unexpected API response: status={status}, payload={payload}")
    return payload

def main() -> int:
    godot_exe = Path(os.environ.get("GODOT_EXE", str(DEFAULT_GODOT_EXE)))
    if not godot_exe.exists():
        raise FileNotFoundError(f"Godot executable not found: {godot_exe}")
    process = subprocess.Popen([
        str(godot_exe), "--editor", "--headless", "--path", str(REPO_ROOT), "--", "--mcp-server"
    ], cwd=REPO_ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        wait_for_cli()
        status, doctor = request_json("GET", "/cli/v1/doctor")
        if status != 200 or doctor["api_version"] != 1:
            raise AssertionError(f"Invalid doctor response: {doctor}")
        if "token" in json.dumps(doctor).lower():
            raise AssertionError("Doctor response must not expose tokens")
        status, catalog = request_json("GET", "/cli/v1/catalog")
        if status != 200 or not catalog.get("tools"):
            raise AssertionError(f"Invalid catalog response: {catalog}")
        if any("input_schema" in entry for entry in catalog["tools"]):
            raise AssertionError("Compact catalog unexpectedly contains full schemas")
        names = {entry["name"] for entry in catalog["tools"]}
        if "get_project_info" not in names or "get_scene_structure" not in names:
            raise AssertionError("Catalog must include core and supplementary CLI tools")
        query = urllib.parse.quote("project info")
        status, search = request_json("GET", f"/cli/v1/tools/search?q={query}&limit=5")
        search = assert_success(status, search)
        if search["data"]["tools"][0]["name"] != "get_project_info":
            raise AssertionError(f"Unexpected search ranking: {search}")
        status, schema = request_json("GET", "/cli/v1/tools/get_project_info")
        schema = assert_success(status, schema)
        if schema["data"]["input_schema"]["type"] != "object":
            raise AssertionError(f"Invalid schema response: {schema}")
        status, project = request_json("POST", "/cli/v1/tools/get_project_info/execute", {"arguments": {}})
        project = assert_success(status, project)
        if "project_path" not in project["data"]:
            raise AssertionError(f"Invalid project result: {project}")
        status, preview = request_json("POST", "/cli/v1/tools/delete_node/execute", {"arguments": {"node_path": "/root/DoesNotMatter"}, "dry_run": True})
        preview = assert_success(status, preview)
        if not preview["data"].get("preview"):
            raise AssertionError(f"Destructive dry-run did not return preview: {preview}")
        status, invalid = request_json("POST", "/cli/v1/tools/get_project_info/execute", {"arguments": []})
        if status != 400 or invalid["error"]["code"] != "INVALID_ARGUMENTS":
            raise AssertionError(f"Invalid argument shape was not rejected: {invalid}")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

if __name__ == "__main__":
    raise SystemExit(main())
