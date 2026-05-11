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
TEMP_DIR = REPO_ROOT / ".tmp_tileset_inspection"
TEMP_TILESET_PATH = "res://.tmp_tileset_inspection/sample_tileset.tres"
TEMP_TILE_SCENE_PATH = "res://.tmp_tileset_inspection/tile_scene.tscn"


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
        expected_tools = {"inspect_tileset_resource", "execute_editor_script"}
        missing_tools = sorted(expected_tools - tool_names)
        if missing_tools:
            raise AssertionError(f"Missing expected TileSet inspection tools: {missing_tools}")

        script_code = "\n".join(
            [
                'var temp_dir := "res://.tmp_tileset_inspection"',
                'DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))',
                "",
                "var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)",
                "image.fill(Color(1.0, 0.0, 0.0, 1.0))",
                "for x in range(16, 32):",
                "\tfor y in range(16):",
                "\t\timage.set_pixel(x, y, Color(0.0, 1.0, 0.0, 1.0))",
                "var atlas_texture := ImageTexture.create_from_image(image)",
                "",
                "var tile_scene_root := Node2D.new()",
                'tile_scene_root.name = "SceneTileRoot"',
                "var packed_scene := PackedScene.new()",
                "packed_scene.pack(tile_scene_root)",
                f'ResourceSaver.save(packed_scene, "{TEMP_TILE_SCENE_PATH}")',
                "",
                "var tile_set := TileSet.new()",
                "tile_set.tile_size = Vector2i(16, 16)",
                "",
                "var atlas_source := TileSetAtlasSource.new()",
                "atlas_source.texture = atlas_texture",
                "atlas_source.texture_region_size = Vector2i(16, 16)",
                "atlas_source.create_tile(Vector2i(0, 0))",
                "atlas_source.create_tile(Vector2i(1, 0))",
                "atlas_source.create_alternative_tile(Vector2i(0, 0))",
                "tile_set.add_source(atlas_source, 10)",
                "",
                "var scene_source := TileSetScenesCollectionSource.new()",
                f'var scene_tile := load("{TEMP_TILE_SCENE_PATH}")',
                "scene_source.create_scene_tile(scene_tile)",
                "tile_set.add_source(scene_source, 20)",
                "",
                f'ResourceSaver.save(tile_set, "{TEMP_TILESET_PATH}")',
                "",
                f'_custom_print("{TEMP_TILESET_PATH}")',
            ]
        )

        setup_result = tool_call(
            "execute_editor_script",
            {"code": script_code},
            request_id=2,
        )
        if setup_result.get("success") is not True:
            raise AssertionError(f"execute_editor_script failed: {setup_result}")

        inspect_result = tool_call(
            "inspect_tileset_resource",
            {"resource_path": TEMP_TILESET_PATH},
            request_id=3,
        )
        if inspect_result.get("resource_path") != TEMP_TILESET_PATH:
            raise AssertionError(f"Unexpected TileSet path: {inspect_result}")
        if inspect_result.get("source_count") != 2:
            raise AssertionError(f"Expected two TileSet sources: {inspect_result}")
        if inspect_result.get("tile_size") != {"x": 16, "y": 16}:
            raise AssertionError(f"Unexpected TileSet tile_size: {inspect_result}")

        sources_by_id = {entry["source_id"]: entry for entry in inspect_result.get("sources", [])}
        atlas_source = sources_by_id.get(10)
        scene_source = sources_by_id.get(20)
        if atlas_source is None or scene_source is None:
            raise AssertionError(f"Missing expected TileSet sources: {inspect_result}")

        if atlas_source.get("source_type") != "atlas":
            raise AssertionError(f"Unexpected atlas source payload: {atlas_source}")
        if atlas_source.get("tile_count") != 2:
            raise AssertionError(f"Unexpected atlas tile count: {atlas_source}")
        if atlas_source.get("texture_region_size") != {"x": 16, "y": 16}:
            raise AssertionError(f"Unexpected atlas texture region size: {atlas_source}")
        if atlas_source.get("atlas_grid_size") != {"x": 2, "y": 1}:
            raise AssertionError(f"Unexpected atlas grid size: {atlas_source}")

        atlas_tiles = {tuple(tile["atlas_coords"].values()): tile for tile in atlas_source.get("tiles", [])}
        first_tile = atlas_tiles.get((0, 0))
        second_tile = atlas_tiles.get((1, 0))
        if first_tile is None or second_tile is None:
            raise AssertionError(f"Missing expected atlas tile entries: {atlas_source}")
        if first_tile.get("alternative_count") != 2:
            raise AssertionError(f"Expected alternative tile on first atlas slot: {first_tile}")
        if second_tile.get("alternative_count") != 1:
            raise AssertionError(f"Expected one base alternative on second atlas slot: {second_tile}")

        if scene_source.get("source_type") != "scenes_collection":
            raise AssertionError(f"Unexpected scene TileSet source payload: {scene_source}")
        if scene_source.get("scene_tile_count") != 1:
            raise AssertionError(f"Expected one scene tile: {scene_source}")
        scene_tiles = scene_source.get("scene_tiles", [])
        if len(scene_tiles) != 1 or scene_tiles[0].get("scene_path") != TEMP_TILE_SCENE_PATH:
            raise AssertionError(f"Unexpected scene tile payload: {scene_source}")

        print("tileset inspection flow verified")
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
