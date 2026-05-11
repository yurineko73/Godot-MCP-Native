# Godot MCP Native (Model Context Protocol)

[中文版本](README.zh.md)
[Русская версия](README.zh.md)

![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

A powerful Godot Engine plugin that integrates AI assistants (Claude, etc.) via the Model Context Protocol (MCP). Enable AI to directly read and modify your Godot projects - scenes, scripts, nodes, and resources - all through natural language.

## 🚀 Features

- **Full Project Access**: AI assistants can read and modify scripts, scenes, nodes, and resources
- **Native Implementation**: No Node.js dependency required - runs entirely within Godot
- **Real-time Editing**: Apply AI suggestions directly in the editor
- **Comprehensive Tool Set** (50+ tools):
  - **Node Tools** (16): Create, modify, manage scene nodes, duplicate, move, rename, signal connections, group management
  - **Script Tools** (9): Edit, analyze, create, attach, validate GDScript files, search in files
  - **Scene Tools** (6): Manipulate scene structure and save scenes
  - **Editor Tools** (8): Control editor functionality, screenshot, signal inspection, filesystem reload
  - **Debug Tools** (6): Debugging, logging, log clearing, script execution
  - **Project Tools** (5): Access project settings and list resources

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
@mcp godot-mcp get-scene-tree

Add a cube in the middle of the scene and create a camera that looks at it.
```

```
Create a main menu with Play, Options, and Quit buttons
```

```
Implement a day/night cycle system with dynamic lighting
```

## 📚 Available Commands

### Node Tools (16)
- `get-scene-tree` - Get scene tree structure
- `get-node-properties` - Get properties of a specific node
- `create-node` - Create a new node
- `delete-node` - Delete a node
- `update-node-property` - Update node properties
- `list-nodes` - List nodes under a parent
- `duplicate-node` - Duplicate a node and its children
- `move-node` - Move a node to a new parent
- `rename-node` - Rename a node in the scene
- `add-resource` - Add a resource child node (collision shape, mesh, etc.)
- `set-anchor-preset` - Set anchor preset for Control nodes
- `connect-signal` - Connect a signal between nodes
- `disconnect-signal` - Disconnect a signal connection
- `get-node-groups` - Get groups a node belongs to
- `set-node-groups` - Set group memberships for a node
- `find-nodes-in-group` - Find all nodes in a specific group

### Script Tools (6)
- `list-project-scripts` - List all scripts
- `read-script` - Read a specific script
- `modify-script` - Update script content
- `create-script` - Create a new script
- `analyze-script` - Analyze script structure
- `get-current-script` - Get currently editing script

### Scene Tools (6)
- `list-project-scenes` - List all scenes
- `read-scene` - Read scene structure
- `create-scene` - Create a new scene
- `save-scene` - Save current scene
- `open-scene` - Open a scene
- `get-current-scene` - Get current scene info

### Project Tools (5)
- `get-project-info` - Get project information
- `get-project-settings` - Get project settings
- `list-project-resources` - List project resources
- `create-resource` - Create a new resource
- `get-project-structure` - Get project directory structure

### Editor Tools (5)
- `get-editor-state` - Get current editor state
- `run-project` - Run the project
- `stop-project` - Stop the running project
- `get-selected-nodes` - Get selected nodes
- `set-editor-setting` - Modify editor settings

### Debug Tools (5)
- `get-editor-logs` - Get editor/runtime logs
- `execute-script` - Execute GDScript expression
- `get-performance-metrics` - Get performance data
- `debug-print` - Print debug info
- `execute-editor-script` - Execute GDScript script

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
