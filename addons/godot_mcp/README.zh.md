# Godot MCP Native（模型上下文协议）

[English Version](README.md)

![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

这是一个通过模型上下文协议（MCP）把 AI 助手（如 Claude）接入 Godot Engine 的原生插件。它允许 AI 直接读取和修改你的 Godot 项目，包括场景、脚本、节点和资源，并且全部在 Godot 内部完成。

## 🚀 功能特性

- **完整项目访问**：AI 助手可以读取和修改脚本、场景、节点和资源。
- **原生实现**：不依赖 Node.js，完全运行在 Godot 内部。
- **实时编辑**：可以直接在编辑器中应用 AI 建议。
- **完整工具集**（205 个工具：46 个 core + 159 个 supplementary）：
  - **节点工具**（16 core + 4 advanced）：创建、修改、管理场景节点，复制、移动、重命名、信号连接、分组管理、批量操作、场景审计。
  - **脚本工具**（9 core + 5 advanced）：编辑、分析、创建、挂载、校验 GDScript 文件，文件搜索，符号索引，定义与引用查找。
  - **场景工具**（6 core + 2 advanced）：操作场景结构，保存场景，列出/打开/关闭场景标签页。
  - **编辑器工具**（7 core + 38 advanced）：控制编辑器功能、截图、信号检查、文件系统重载、节点/文件选择、导出管理、Inspector 读取、编辑器元数据/状态摘要，以及相关只读编辑器 surface。
  - **调试工具**（3 core + 67 advanced）：日志、脚本执行、调试会话、断点、栈/变量检查、性能分析、runtime probe、动画/音频/shader/tilemap 的运行时控制，以及调试执行控制。
  - **项目工具**（5 core + 43 advanced）：读取项目设置、列出资源、运行测试、管理 InputMap、检查 autoload/global class、单项项目配置写入、资源生命周期操作、资源诊断和项目健康检查。

## 📦 安装

### 方法 1：Asset Library（推荐）
1. 打开你的 Godot 项目
2. 在编辑器中进入 **AssetLib**
3. 搜索 `Godot MCP Native`
4. 点击 **Download**，然后点击 **Install**

### 方法 2：手动安装
1. 下载或克隆本仓库
2. 将 `addons/godot_mcp` 目录复制到项目的 `addons/` 目录下
3. 用 Godot 打开项目
4. 进入 **Project > Project Settings > Plugins**
5. 启用 `Godot MCP Native` 插件

## 🔧 使用方法

### 启用插件
1. 打开 **Project > Project Settings > Plugins**
2. 在列表中找到 `Godot MCP Native`
3. 将状态切换为 **Enable**

### 配置 MCP Server
插件当前提供两种传输模式。

#### HTTP 模式（用于远程访问）
- 适用场景：基于网络的 AI 集成
- 配置方式：设置 `transport_mode = "http"`，并配置 `http_port`（默认 `9080`）
- 可选安全项：启用 `auth_enabled` 并设置 `auth_token`

### 与 Claude Desktop 连接

先安装 `mcp-remote`：

```bash
npm install mcp-remote
```

#### HTTP 模式配置

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:19080/mcp"
      ]
    }
  }
}
```

### 与 Cursor / Trae 连接

#### HTTP 模式配置

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

如需鉴权：

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

### 与 Cline 连接

#### HTTP 模式配置

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "type": "streamableHttp",
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 与 OpenCode 连接

#### HTTP 模式配置

```json
{
  "mcp": {
    "godot-mcp": {
      "type": "remote",
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

### 与 Codex 连接

#### HTTP 模式配置

```toml
[mcp_servers]

[mcp_servers.godot-mcp]
type = "streamableHttp"
url = "http://localhost:19080/mcp"
```

## 💬 示例提示词

连接成功后，你可以通过 Claude 或其他 MCP 客户端直接操作项目：

```text
@mcp godot-mcp read godot://script/current

I need help optimizing my player movement code. Can you suggest improvements?
```

```text
@mcp godot-mcp get-scene-tree

Add a cube in the middle of the scene and create a camera that looks at it.
```

```text
Create a main menu with Play, Options, and Quit buttons
```

```text
Implement a day/night cycle system with dynamic lighting
```

## 📚 可用命令

下面的列表只是代表性示例，不是权威的完整目录。请以 `docs/current/tools-reference.md` 或 MCP `tools/list` 返回的 live catalog 为准。
下面部分示例名称保留了历史缩写；实际调用 MCP 工具时，请优先使用 `tools-reference.md` 或 `tools/list` 中的 snake_case 工具 ID。

### 节点工具（示例列表）
- `get-scene-tree` - 获取场景树结构
- `get-node-properties` - 获取指定节点的属性
- `create-node` - 创建新节点
- `delete-node` - 删除节点
- `update-node-property` - 更新节点属性
- `list-nodes` - 列出父节点下的子节点
- `duplicate-node` - 复制节点及其子节点
- `move-node` - 将节点移动到新的父节点下
- `rename-node` - 重命名场景中的节点
- `add-resource` - 添加资源子节点（碰撞体、网格等）
- `set-anchor-preset` - 为 Control 节点设置锚点预设
- `connect-signal` - 连接节点信号
- `disconnect-signal` - 断开信号连接
- `get-node-groups` - 获取节点所属分组
- `set-node-groups` - 设置节点分组
- `find-nodes-in-group` - 查找指定分组中的所有节点

### 脚本工具（示例列表）
- `list-project-scripts` - 列出项目中的脚本
- `read-script` - 读取指定脚本
- `modify-script` - 更新脚本内容
- `create-script` - 创建脚本
- `analyze-script` - 分析脚本结构
- `get-current-script` - 获取当前编辑中的脚本
- `attach-script` - 为节点挂载已有脚本
- `validate-script` - 校验 GDScript 语法
- `search-in-files` - 在项目文件中搜索

### 场景工具（示例列表）
- `list-project-scenes` - 列出项目中的场景
- `read-scene` - 读取场景结构
- `create-scene` - 创建新场景
- `save-scene` - 保存当前场景
- `open-scene` - 打开场景
- `get-current-scene` - 获取当前场景信息

### 编辑器工具（示例列表）
- `get-editor-state` - 获取当前编辑器状态
- `run-project` - 运行项目
- `stop-project` - 停止正在运行的项目
- `get-selected-nodes` - 获取当前选中的节点
- `set-editor-setting` - 修改编辑器设置
- `get-editor-screenshot` - 捕获编辑器 viewport 截图
- `get-signals` - 检查节点信号及连接
- `reload-project` - 重新扫描项目文件系统

### 节点高级工具（示例列表）
- `batch-update-node-properties` - 在一次 UndoRedo 操作中批量更新多个节点属性
- `batch-scene-node-edits` - 在一次 UndoRedo 操作中批量创建/删除/移动场景节点
- `audit-scene-node-persistence` - 审计节点 owner 和持久化状态
- `audit-scene-inheritance` - 审计继承/实例化场景结构

### 脚本高级工具（示例列表）
- `list-project-script-symbols` - 对 GDScript 和 C# 文件建立符号索引
- `find-script-symbol-definition` - 查找脚本符号定义位置
- `find-script-symbol-references` - 查找脚本符号文本引用
- `rename-script-symbol` - 跨项目文件重命名脚本符号
- `open-script-at-line` - 在编辑器中打开脚本指定行

### 场景高级工具（示例列表）
- `list-open-scenes` - 列出当前打开的场景标签页
- `close-scene-tab` - 关闭一个场景标签页

### 编辑器高级工具（示例列表）
- `select-node` - 在场景中选中节点并聚焦 Inspector
- `select-file` - 在 FileSystem dock 中选中文件
- `get-inspector-properties` - 像 Inspector 一样读取节点/资源属性
- `list-export-presets` - 列出导出预设
- `inspect-export-templates` - 检查已安装的导出模板
- `validate-export-preset` - 校验导出预设
- `run-export` - 运行 Godot CLI 导出

### 调试工具（示例列表）
- `get-editor-logs` - 获取编辑器/运行时日志
- `execute-script` - 执行 GDScript 表达式
- `get-performance-metrics` - 获取性能数据
- `debug-print` - 输出调试信息
- `execute-editor-script` - 执行编辑器侧 GDScript
- `clear-output` - 清空 MCP/编辑器输出缓冲
- `get-debugger-sessions` - 列出编辑器调试会话及 active/break 状态
- `set-debugger-breakpoint` - 启用或禁用断点
- `send-debugger-message` - 向运行中的游戏调试器发送消息
- `toggle-debugger-profiler` - 切换 EngineProfiler 通道
- `get-debugger-messages` - 读取 bridge 捕获的自定义运行时消息
- `add-debugger-capture-prefix` - 捕获额外的 EngineDebugger 前缀
- `get-debug-stack-frames` - 读取断点会话的脚本栈帧
- `get-debug-stack-variables` - 读取栈帧的局部变量、成员和全局变量
- `install-runtime-probe` - 将 MCP runtime probe 安装到当前场景
- `remove-runtime-probe` - 从当前场景移除 MCP runtime probe
- `request-debug-break` - 请求进入 Godot 调试中断循环
- `send-debug-command` - 发送 `step/next/out/continue/stack` 调试命令
- `get-runtime-info` - 通过 probe 查询 FPS、节点数等运行时指标
- `get-runtime-scene-tree` - 读取运行中游戏的场景树
- `inspect-runtime-node` - 检查运行时节点及其可序列化属性
- `update-runtime-node-property` - 修改运行时节点属性
- `call-runtime-node-method` - 调用运行时节点方法
- `evaluate-runtime-expression` - 在运行中游戏内求值 GDScript 表达式
- `await-runtime-condition` - 轮询运行时表达式直到为真或超时
- `assert-runtime-condition` - 断言运行时表达式会在超时内为真
- `get-debug-threads` - 返回 DAP 风格的调试线程
- `get-debug-state-events` - 读取记录下来的调试状态变迁
- `get-debug-output` - 读取分类后的运行时调试输出
- `get-debug-scopes` - 以 DAP 风格对栈变量分组
- `get-debug-variables` - 解析 DAP 风格的变量引用
- `expand-debug-variable` - 按 scope 和 path 展开调试变量
- `evaluate-debug-expression` - 在调试器上下文中求值表达式
- `debug-step-into` / `debug-step-over` / `debug-step-out` / `debug-continue` - 调试执行控制
- `debug-step-into-and-wait` / `debug-step-over-and-wait` / `debug-step-out-and-wait` / `debug-continue-and-wait` - 带状态等待的调试执行控制
- `await-debugger-state` - 检查调试会话执行状态
- `get-runtime-performance-snapshot` - 捕获运行时性能快照
- `get-runtime-memory-trend` - 捕获运行时内存趋势
- `create-runtime-node` - 在运行中游戏里创建节点
- `delete-runtime-node` - 从运行中游戏里删除节点
- `simulate-runtime-input-event` - 注入结构化 `InputEvent`
- `simulate-runtime-input-action` - 注入 `InputEventAction`
- `list-runtime-input-actions` - 列出运行时 InputMap actions
- `upsert-runtime-input-action` - 创建或更新运行时 InputMap action
- `remove-runtime-input-action` - 删除运行时 InputMap action
- `list-runtime-animations` - 列出运行时 AnimationPlayer 上的动画
- `play-runtime-animation` - 播放运行时动画
- `stop-runtime-animation` - 停止运行时动画
- `get-runtime-animation-state` - 获取运行时动画播放状态
- `get-runtime-animation-tree-state` - 获取运行时 AnimationTree 状态
- `set-runtime-animation-tree-active` - 启用或禁用运行时 AnimationTree
- `travel-runtime-animation-tree` - 切换运行时动画状态机
- `get-runtime-material-state` - 解析运行时节点材质绑定
- `get-runtime-theme-item` - 解析运行时 Control 的主题项
- `set-runtime-theme-override` - 应用运行时主题 override
- `clear-runtime-theme-override` - 移除运行时主题 override
- `get-runtime-shader-parameters` - 列出运行时 shader 参数
- `set-runtime-shader-parameter` - 更新运行时 shader uniform
- `list-runtime-tilemap-layers` - 列出运行时 TileMap layer
- `get-runtime-tilemap-cell` - 获取运行时 TileMap 单元格数据
- `set-runtime-tilemap-cell` - 写入或清除运行时 TileMap 单元格
- `list-runtime-audio-buses` - 列出运行时音频总线
- `get-runtime-audio-bus` - 获取运行时音频总线状态
- `update-runtime-audio-bus` - 更新运行时音频总线
- `get-runtime-screenshot` - 捕获运行时 viewport 截图

### 项目工具（示例列表）
- `get-project-info` - 获取项目信息
- `get-project-settings` - 获取项目设置
- `list-project-resources` - 列出项目资源
- `create-resource` - 创建新资源
- `get-project-structure` - 获取项目目录结构
- `list-project-tests` - 发现并列出可运行的项目测试
- `run-project-test` - 运行单个项目测试
- `run-project-tests` - 运行多个项目测试
- `list-project-input-actions` - 列出项目 InputMap actions
- `upsert-project-input-action` - 创建或更新项目 InputMap action
- `remove-project-input-action` - 删除项目 InputMap action
- `list-project-autoloads` - 列出项目 autoload 条目
- `list-project-global-classes` - 列出项目全局脚本类
- `get-class-api-metadata` - 获取 ClassDB 或全局类 API 元数据
- `inspect-csharp-project-support` - 检查 C# 项目支持文件
- `compare-render-screenshots` - 比较两张截图的像素差异
- `inspect-tileset-resource` - 检查 TileSet 资源
- `reimport-resources` - 通过导入流水线重新导入资源
- `get-import-metadata` - 获取资源导入元数据
- `get-resource-uid-info` - 检查 ResourceUID 映射
- `fix-resource-uid` - 确保资源具有持久化 UID
- `get-resource-dependencies` - 列出资源依赖
- `scan-missing-resource-dependencies` - 查找损坏的依赖引用
- `scan-cyclic-resource-dependencies` - 查找循环依赖链
- `detect-broken-scripts` - 扫描脚本语法错误
- `audit-project-health` - 执行项目健康检查

## 🔒 安全建议

- **生产环境**：始终启用鉴权（`auth_enabled = true`）
- **Token**：使用强 token（建议至少 16 个字符，混合字母、数字和特殊字符）
- **存储**：不要把 token 提交到版本控制
- **远程访问**：通过网络访问时使用 HTTPS（TLS/SSL）

## 📋 运行要求

- Godot Engine 4.x（推荐 4.5 或更高）
- 无额外依赖（原生实现）

## 📖 文档

更详细的文档见 `docs/current/`：
- [Quick Start Guide](docs/current/quickstart.md)
- [Architecture Design](docs/current/architecture.md)
- [Tools Reference](docs/current/tools-reference.md)
- [Testing Guide](docs/current/testing-guide.md)

## 🤝 贡献

欢迎贡献。可以直接提交 Pull Request。

## 📄 许可证

本项目基于 MIT License 发布，详见 [LICENSE](LICENSE)。

## 👤 作者

**yurineko73**

## 🙏 致谢

- 感谢 Godot Engine 团队打造优秀的游戏引擎
- 感谢 Model Context Protocol（MCP）规范
- 感谢 Anthropic 的 Claude AI 为这个集成方向提供灵感

---

**说明**：这是社区插件，与 Godot Engine 或 Anthropic 官方无隶属关系。
