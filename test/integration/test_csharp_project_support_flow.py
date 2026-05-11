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
TEMP_DIR = REPO_ROOT / ".tmp_csharp_project_support"
CSPROJ_PATH = "res://.tmp_csharp_project_support/TempGame.csproj"
SLN_PATH = "res://.tmp_csharp_project_support/TempGame.sln"
CSPROJ_FILE = TEMP_DIR / "TempGame.csproj"
SLN_FILE = TEMP_DIR / "TempGame.sln"

CSPROJ_TEXT = """
<Project Sdk="Godot.NET.Sdk/4.6.2">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>TempGame</AssemblyName>
    <RootNamespace>TempGame</RootNamespace>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>
</Project>
""".strip() + "\n"

SLN_TEXT = """
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
Project("{FAKE-GUID}") = "TempGame", ".tmp_csharp_project_support\\TempGame.csproj", "{PROJECT-GUID}"
EndProject
Global
EndGlobal
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
    CSPROJ_FILE.write_text(CSPROJ_TEXT, encoding="utf-8")
    SLN_FILE.write_text(SLN_TEXT, encoding="utf-8")

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
        expected_tools = {"inspect_csharp_project_support"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected C# support tools: {missing_tools}")

        result = tool_call(
            "inspect_csharp_project_support",
            {"search_path": "res://.tmp_csharp_project_support"},
            request_id=2,
        )
        if result.get("project_count") != 1:
            raise AssertionError(f"Expected one .csproj file: {result}")
        if result.get("solution_count") != 1:
            raise AssertionError(f"Expected one .sln file: {result}")

        csproj = result["projects"][0]
        if csproj.get("path") != CSPROJ_PATH:
            raise AssertionError(f"Unexpected csproj path: {csproj}")
        if csproj.get("sdk") != "Godot.NET.Sdk/4.6.2":
            raise AssertionError(f"Unexpected csproj SDK: {csproj}")
        if csproj.get("target_frameworks") != ["net8.0"]:
            raise AssertionError(f"Unexpected target frameworks: {csproj}")
        if csproj.get("assembly_name") != "TempGame":
            raise AssertionError(f"Unexpected assembly name: {csproj}")
        if csproj.get("root_namespace") != "TempGame":
            raise AssertionError(f"Unexpected root namespace: {csproj}")
        if csproj.get("nullable") != "enable":
            raise AssertionError(f"Unexpected nullable setting: {csproj}")
        package_refs = csproj.get("package_references", [])
        if len(package_refs) != 1 or package_refs[0].get("include") != "Newtonsoft.Json":
            raise AssertionError(f"Unexpected package references: {csproj}")

        solution = result["solutions"][0]
        if solution.get("path") != SLN_PATH:
            raise AssertionError(f"Unexpected solution path: {solution}")
        if solution.get("project_count") != 1:
            raise AssertionError(f"Expected one solution project entry: {solution}")

        print("csharp project support flow verified")
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
