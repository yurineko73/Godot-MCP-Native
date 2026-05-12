# 快速开始指南

本指南将帮助你在 10 分钟内启动并运行 Godot-MCP 项目。

## 前置要求

### 必需软件
- **Godot 4.x** (推荐 4.3 或更高版本)
- **Git** (用于版本控制)
- **Python 3.8+** (用于测试脚本)

### 可选软件
- **Visual Studio Code** 或其他代码编辑器
- **Claude Desktop** (用于测试 MCP 集成)

## 步骤 1: 克隆项目

```bash
git clone https://github.com/yurineko73/Godot-MCP-Native.git
cd Godot-MCP-Native
```

## 步骤 2: 配置 Godot 插件

1. 打开 Godot Editor
2. 导入项目：选择 `project.godot` 文件
3. 在 Godot Editor 中，进入 **项目 > 项目管理 > 插件**
4. 找到 **Godot Native MCP Server** 插件
5. 将状态设置为 **启用**

## 步骤 3: 配置传输模式

Godot-MCP 面板保留两种传输模式配置；当前可用和推荐的是 HTTP 模式。

### 模式 A: Stdio 模式（暂不可用）

> ⚠️ **注意**：Stdio 模式目前处于开发阶段，暂不可用。请使用 HTTP 模式进行开发和测试。

Stdio 模式通过标准输入/输出与 MCP 客户端通信，适合本地进程集成。当前实现仍在开发中，不建议在日常使用或集成测试中启用。

### 模式 B: HTTP 模式（推荐用于开发和生产）

HTTP 模式通过 HTTP 协议通信，支持远程访问和 SSE 流式响应。

**配置步骤**：
1. 在 Godot Editor 中，选择 **MCP Server** 面板
2. 设置 `transport_mode` 为 `http`
3. 设置 `http_port` (默认 9080)
4. 可选：启用 `auth_enabled` 并设置 `auth_token`
5. 可选：启用 `sse_enabled` 以支持 SSE 流
6. 点击 **Start Server** 按钮

### Vibe Coding / 免打扰模式

`vibe_coding_mode` 默认启用。该模式不会停止 MCP 服务，但会阻止会抢占编辑器焦点、切换场景标签、选择节点/文件或打开/控制运行窗口的工具。

- 单次允许编辑器聚焦：在工具参数中传入 `allow_ui_focus=true`
- 单次允许运行窗口控制：在工具参数中传入 `allow_window=true`
- 人工调试时如需 AI 同步操作编辑器，可在 MCP 面板关闭该模式

**Claude Desktop 配置** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "godot": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-token-here"
      }
    }
  }
}
```

## 步骤 4: 验证安装

### 测试 Stdio 模式

Stdio 模式目前处于开发阶段，暂不可用；请优先使用 HTTP 模式验证插件。

### 测试 HTTP 模式

```bash
curl -X POST http://localhost:9080/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token-here" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

预期输出：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [...]
  },
  "id": 1
}
```

## 步骤 5: 调用你的第一个工具

### 使用 Claude Desktop

1. 启动 Claude Desktop
2. 在对话中输入："`请获取 Godot 项目信息`"
3. Claude 将调用 `get_project_info` 工具并返回结果

### 使用 curl (HTTP 模式)

```bash
curl -X POST http://localhost:9080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_project_info",
      "arguments": {}
    },
    "id": 2
  }'
```

## 常见问题

### 问题 1: 插件不显示在 Godot Editor 中

**解决方案**：
- 确认插件已启用：**项目 > 项目管理 > 插件**
- 检查 `addons/godot_mcp` 目录是否存在
- 重启 Godot Editor

### 问题 2: HTTP 服务器无法启动（端口被占用）

**解决方案**：
```bash
# 检查端口占用
netstat -ano | findstr :9080  # Windows
lsof -i :9080                   # macOS/Linux

# 修改端口：在 MCP Server 面板中修改 http_port
```

### 问题 3: 认证失败 (401 Unauthorized)

**解决方案**：
- 确认 `auth_enabled` 已启用
- 确认 `auth_token` 长度 ≥ 16 字符
- 确认请求头包含正确的 `Authorization: Bearer <token>`

### 问题 4: SSE 连接立即断开

**解决方案**：
- 确认 `sse_enabled` 已启用
- 检查客户端是否支持 SSE
- 查看 Godot Editor 输出面板中的错误信息

## 下一步

- 阅读 [架构设计文档](architecture.md) 了解系统架构
- 阅读 [工具参考手册](tools-reference.md) 查看所有可用工具
- 阅读 [当前工具清单](tool-inventory.md) 查看从源码核对出的 146 个工具
- 阅读 [测试指南](testing-guide.md) 了解如何运行测试
- 加入我们的社区讨论（链接待添加）

## 获取帮助

- **GitHub Issues**: 报告 Bug 或提出功能请求
- **GitHub Discussions**: 提问或分享想法
- **Documentation**: 查看 `docs/` 目录中的详细文档

---

**恭喜！你已成功配置 Godot MCP Native 项目。** 🎉
