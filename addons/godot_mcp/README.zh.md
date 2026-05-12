# Godot MCP Native (模型上下文协议)

[English Version](README.md)

![Godot 版本](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![许可证](https://img.shields.io/badge/License-MIT-green)
![版本](https://img.shields.io/badge/Version-1.0.0-orange)

一个强大的 Godot 引擎插件，通过模型上下文协议 (MCP) 集成 AI 助手（如 Claude 等）。让 AI 可以直接通过自然语言读取和修改您的 Godot 项目——场景、脚本、节点和资源。

## 🚀 功能特性

- **完整项目访问**：AI 助手可以读取和修改脚本、场景、节点和资源
- **原生实现**：无需 Node.js 依赖——完全在 Godot 中运行
- **实时编辑**：直接在编辑器中应用 AI 建议
- **全面的工具集**（146 个工具）：
  - **节点工具**（20 个）：创建、修改、批量编辑、审计、复制、移动、重命名、信号连接和组管理
  - **脚本工具**（14 个）：读取、编辑、分析、创建、附加、验证、搜索、符号跳转、引用查找和符号重命名
  - **场景工具**（8 个）：列出、打开、检查、保存和关闭场景或场景标签页
  - **编辑器工具**（15 个）：查看编辑器状态、运行/停止项目、选择节点/文件、检查信号和 Inspector 属性、截图、重载和导出
  - **调试工具**（63 个）：日志、脚本执行、调试会话、断点、DAP 风格线程/栈/变量、运行时探针、截图、输入、动画、音频、TileMap、材质、主题和运行时断言
  - **项目工具**（26 个）：项目设置、资源、依赖、UID/import、输入映射、Autoload、全局类、测试、健康检查和 C# 支持检测

## 📦 安装

### 方法 1：资源库（推荐）
1. 打开您的 Godot 项目
2. 进入编辑器中的 **AssetLib** 标签页
3. 搜索 "Godot MCP Native"
4. 点击 **下载** 然后 **安装**

### 方法 2：手动安装
1. 下载或克隆此仓库
2. 将 `addons/godot_mcp` 文件夹复制到项目的 `addons/` 目录
3. 在 Godot 中打开项目
4. 进入 **项目 > 项目设置 > 插件**
5. 启用 "Godot MCP Native" 插件

## 🔧 使用

### 启用插件
1. 打开 **项目 > 项目设置 > 插件**
2. 在列表中找到 "Godot MCP Native"
3. 将状态设置为 **启用**

### 配置 MCP 服务器
插件提供两种传输模式：

默认启用 **Vibe Coding / 免打扰模式**。在此模式下，MCP 服务会后台响应请求，但会阻止会抢占编辑器焦点、切换场景标签、选择节点/文件或打开运行窗口的工具。需要 AI 配合人工调试时，可以在 MCP 面板中关闭该模式，或在单次工具调用中显式传入 `allow_ui_focus=true` / `allow_window=true`。

#### HTTP 模式（用于远程访问）
- 适用场景：基于网络的 AI 集成
- 配置：在插件设置中设置 `transport_mode = "http"` 并配置 `http_port`（默认：9080）
- 可选：启用 `auth_enabled` 并设置 `auth_token` 以保障安全

### 连接 Claude Desktop

#### HTTP 模式配置
编辑 Claude Desktop 配置文件（`claude_desktop_config.json`）：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

带身份验证：
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

## 💬 示例提示

连接后，您可以通过 Claude 与 Godot 项目交互：

```
@mcp godot-mcp read godot://script/current

我需要帮助优化我的玩家移动代码。能提出改进建议吗？
```

```
@mcp godot-mcp get_scene_tree

在场景中间添加一个立方体，并创建一个相机看向它。
```

```
创建一个主菜单，包含开始、选项和退出按钮
```

```
实现一个带有动态光照的昼夜循环系统
```

## 📚 可用命令

工具名使用下划线，与 MCP `tools/list` 返回值一致。常用示例包括：

- 节点：`get_scene_tree`、`create_node`、`batch_scene_node_edits`、`audit_scene_inheritance`
- 脚本：`read_script`、`modify_script`、`list_project_script_symbols`、`find_script_symbol_references`、`rename_script_symbol`
- 场景：`list_project_scenes`、`open_scene`、`get_scene_structure`、`close_scene_tab`
- 编辑器：`get_editor_state`、`run_project`、`select_node`、`get_inspector_properties`、`run_export`
- 调试/运行时：`get_editor_logs`、`get_debug_threads`、`get_debug_stack_frames`、`install_runtime_probe`、`get_runtime_scene_tree`、`simulate_runtime_input_event`、`assert_runtime_condition`
- 项目：`get_project_info`、`audit_project_health`、`get_resource_dependencies`、`list_project_tests`、`run_project_tests`

完整 146 个工具清单见 [当前工具清单](../../docs/current/tool-inventory.md)，实时 JSON Schema 以 MCP `tools/list` 返回为准。

## 🔒 安全建议

- ✅ **生产环境**：始终启用身份验证（`auth_enabled = true`）
- ✅ **令牌**：使用强令牌（≥16 个字符，包含字母、数字、特殊字符）
- ✅ **存储**：不要将令牌提交到版本控制
- ⚠️ **远程访问**：使用 HTTPS（TLS/SSL）进行网络访问

## 📋 要求

- Godot Engine 4.x（推荐 4.5 或更高版本）
- 无额外依赖（原生实现）

## 📖 文档

详细文档请查看 `docs/current/` 文件夹：
- [快速开始指南](../../docs/current/quickstart.md)
- [架构设计](../../docs/current/architecture.md)
- [工具参考](../../docs/current/tools-reference.md)
- [当前工具清单](../../docs/current/tool-inventory.md)
- [测试指南](../../docs/current/testing-guide.md)

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 👤 作者

**yurineko73**

## 🙏 致谢

- Godot 引擎团队带来的出色游戏引擎
- 模型上下文协议 (MCP) 规范
- Anthropic 的 Claude AI 启发了此集成

---

**注意**：这是一个社区插件，与 Godot Engine 或 Anthropic 无官方关联。
