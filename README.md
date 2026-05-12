# Godot MCP Native (Model Context Protocol)

[中文版本](README.zh.md)

![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

A powerful Godot Engine plugin that integrates AI assistants (Claude, etc.) via the Model Context Protocol (MCP). Enable AI to directly read and modify your Godot projects - scenes, scripts, nodes, and resources - all through natural language.

## 🚀 Features

- **Full Project Access**: AI assistants can read and modify scripts, scenes, nodes, and resources
- **Native Implementation**: No Node.js dependency required - runs entirely within Godot
- **Real-time Editing**: Apply AI suggestions directly in the editor
- **Comprehensive Tool Set** (146 tools):
  - **Node Tools** (20): Create, modify, batch edit, audit, duplicate, move, rename, connect signals, and manage groups
  - **Script Tools** (14): Read, edit, analyze, create, attach, validate, search, jump to symbols, find references, and rename symbols
  - **Scene Tools** (8): List, open, inspect, save, and close scenes or scene tabs
  - **Editor Tools** (15): Inspect editor state, run/stop projects, select nodes/files, inspect signals and Inspector properties, screenshot, reload, and export
  - **Debug Tools** (63): Logs, script execution, debugger sessions, breakpoints, DAP-style threads/stack/variables, runtime probe, screenshots, input, animation, audio, TileMap, material, theme, and runtime assertions
  - **Project Tools** (26): Project settings, resources, dependencies, UIDs/imports, input maps, autoloads, global classes, tests, health checks, and C# support checks

## 📦 Installation

### Method 1: Asset Library (Recommended)
1. Open your Godot project
2. Go to **AssetLib** tab in the editor
3. Search for "Godot MCP Native"
4. Click **Download** and then **Install**

### Method 2: Manual Installation
1. Download or clone this repository
2. Copy the `addons/godot_mcp` folder to your project's `addons/` directory
3. Open your project in Godot
4. Go to **Project > Project Settings > Plugins**
5. Enable "Godot MCP Native" plugin

## 🔧 Usage

### Enabling the Plugin
1. Open **Project > Project Settings > Plugins**
2. Locate "Godot MCP Native" in the list
3. Set the status to **Enable**

### Configuring MCP Server
The plugin provides two transport modes:

**Vibe Coding / Do Not Disturb mode** is enabled by default. In this mode, the MCP server keeps responding in the background but blocks tools that would steal editor focus, switch scene tabs, select nodes/files, or open/control a runtime window. Turn it off in the MCP panel when pairing manual debugging with MCP, or explicitly pass `allow_ui_focus=true` / `allow_window=true` for a single tool call.

#### HTTP Mode (for remote access)
- Best for: Network-based AI integration
- Configuration: Set `transport_mode = "http"` and configure `http_port` (default: 9080)
- Optional: Enable `auth_enabled` and set `auth_token` for security

### Connecting with Claude Desktop

#### HTTP Mode Configuration
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

With authentication:
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

## 💬 Example Prompts

Once connected, you can interact with your Godot project through Claude:

```
@mcp godot-mcp read godot://script/current

I need help optimizing my player movement code. Can you suggest improvements?
```

```
@mcp godot-mcp get_scene_tree

Add a cube in the middle of the scene and create a camera that looks at it.
```

```
Create a main menu with Play, Options, and Quit buttons
```

```
Implement a day/night cycle system with dynamic lighting
```

## 📚 Available Commands

Tool names use underscores, matching the MCP `tools/list` response. Common examples include:

- Node: `get_scene_tree`, `create_node`, `batch_scene_node_edits`, `audit_scene_inheritance`
- Script: `read_script`, `modify_script`, `list_project_script_symbols`, `find_script_symbol_references`, `rename_script_symbol`
- Scene: `list_project_scenes`, `open_scene`, `get_scene_structure`, `close_scene_tab`
- Editor: `get_editor_state`, `run_project`, `select_node`, `get_inspector_properties`, `run_export`
- Debug/runtime: `get_editor_logs`, `get_debug_threads`, `get_debug_stack_frames`, `install_runtime_probe`, `get_runtime_scene_tree`, `simulate_runtime_input_event`, `assert_runtime_condition`
- Project: `get_project_info`, `audit_project_health`, `get_resource_dependencies`, `list_project_tests`, `run_project_tests`

See [Current Tool Inventory](docs/current/tool-inventory.md) for the complete 146-tool list, and use MCP `tools/list` for live JSON Schema details.

## 🔒 Security Recommendations

- ✅ **Production**: Always enable authentication (`auth_enabled = true`)
- ✅ **Token**: Use a strong token (≥16 characters with letters, numbers, special characters)
- ✅ **Storage**: Don't commit tokens to version control
- ⚠️ **Remote Access**: Use HTTPS (TLS/SSL) for network access

## 📋 Requirements

- Godot Engine 4.x (recommended 4.5 or higher)
- No additional dependencies (native implementation)

## 📖 Documentation

For detailed documentation, see the `docs/current/` folder:
- [Quick Start Guide](docs/current/quickstart.md)
- [Architecture Design](docs/current/architecture.md)
- [Tools Reference](docs/current/tools-reference.md)
- [Current Tool Inventory](docs/current/tool-inventory.md)
- [Testing Guide](docs/current/testing-guide.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**yurineko73**

## 🙏 Acknowledgments

- Godot Engine team for the amazing game engine
- Model Context Protocol (MCP) specification
- Claude AI by Anthropic for inspiring this integration

---

**Note**: This is a community plugin and is not officially affiliated with Godot Engine or Anthropic.
