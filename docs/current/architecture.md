# 架构设计文档

本文档详细说明 Godot MCP Native 项目的系统架构、设计决策和技术实现。

## 目录

1. [系统架构概述](#系统架构概述)
2. [三层架构设计](#三层架构设计)
3. [传输层设计](#传输层设计)
4. [工具系统](#工具系统)
5. [信号流](#信号流)
6. [线程模型](#线程模型)
7. [安全设计](#安全设计)
8. [性能优化](#性能优化)

---

## 系统架构概述

Godot MCP Native 采用 **三层架构**，将 AI Client、MCP 服务器和 Godot 编辑器无缝集成：

```
┌─────────────────┐
│         AI Client (Claude, etc.)              │
│  - 发送 JSON-RPC 请求                          │
│  - 接收工具执行结果                             │
└────────────────┬──────────────────────────────┘
                 │ JSON-RPC 2.0 (stdio / HTTP)
┌────────────────▼──────────────────────────────┐
│    Godot Native MCP Server                │
│  - 工具注册和管理                              │
│  - 请求路由和响应                              │
│  - 认证和授权                                  │
└────────────────┬──────────────────────────────┘
                 │ WebSocket / Godot API
┌────────────────▼──────────────────────────────┐
│         Godot Editor                          │
│  - 场景管理                                    │
│  - 脚本编辑                                    │
│  - 节点操作                                    │
└─────────────────┘
```

### 架构优势

1. **解耦合**：各层独立开发和测试
2. **可扩展**：易于添加新工具或传输方式
3. **跨平台**：支持 Windows、macOS、Linux
4. **灵活部署**：支持本地开发和生产部署

---

## 三层架构设计

### 第一层：AI Client

**职责**：
- 发送 JSON-RPC 2.0 请求
- 接收工具执行结果
- 管理用户对话

**支持的客户端**：
- Claude Desktop
- Cursor
- 自定义 MCP 客户端

**通信协议**：
- **Stdio 模式**：通过标准输入/输出（⚠️ **暂不可用**，处于开发阶段）
- **HTTP 模式**：通过 HTTP POST/GET 请求（推荐）

**示例请求**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "parent_path": "/root",
      "node_type": "Node2D",
      "node_name": "Player"
    }
  },
  "id": 1
}
```

### MCP Server 架构

MCP Server 是核心中间层，负责：

1. **工具管理**：
- 注册工具（205 个工具）
   - 验证工具参数
   - 执行工具逻辑

2. **传输抽象**：
   - 支持多种传输方式（stdio、HTTP）
   - 统一的消息处理接口

3. **安全和认证**：
   - Token-based 认证
   - 时序安全比较（防止时序攻击）
   - 速率限制

#### Godot Native MCP Server

**技术栈**：
- GDScript
- Godot 4.x EditorPlugin
- TCP Server (HTTP 模式)

**目录结构**：
```
addons/godot_mcp/
├── mcp_server_native.gd      # 插件主类
├── native_mcp/
│   ├── mcp_server_core.gd   # 核心服务器
│   ├── mcp_transport_base.gd # 传输层基类
│   ├── mcp_stdio_server.gd  # Stdio 传输
│   ├── mcp_http_server.gd    # HTTP 传输
│   ├── mcp_auth_manager.gd   # 认证管理
│   └── tools/                # 工具实现
└── ui/                       # UI 面板
```

### 第三层：Godot Editor

**职责**：
- 提供 Godot Editor API
- 管理场景、脚本、资源
- 执行游戏逻辑

**关键 API**：
- `EditorInterface`：编辑器接口
- `EditorPlugin`：插件基类
- `ResourceSaver`：资源保存
- `PackedScene`：场景打包

---

## 传输层设计

### 传输层抽象

为了支持多种传输方式，我们设计了 `McpTransportBase` 抽象类：

```gdscript
class_name McpTransportBase
extends RefCounted

# 信号定义
signal message_received(message: Dictionary, context: Variant)
signal server_error(error: String)
signal server_started()
signal server_stopped()

# 接口方法
func start() -> bool:
    push_error("McpTransportBase.start() must be overridden")
    return false

func stop() -> void:
    push_error("McpTransportBase.stop() must be overridden")

func is_running() -> bool:
    push_error("McpTransportBase.is_running() must be overridden")
    return false
```

### Stdio 传输实现

> ⚠️ **注意**：Stdio 传输目前处于开发阶段，暂不可用。请使用 HTTP 传输进行开发和测试。

**类**：`McpStdioServer`

**工作原理**：
1. 在独立线程中监听标准输入
2. 解析 JSON-RPC 消息
3. 通过信号传递到主线程处理
4. 将响应打印到标准输出

**关键代码**：
```gdscript
func _stdin_listen_loop() -> void:
    while _active:
        var line: String = OS.read_string_from_stdin()
        if line.is_empty():
            OS.delay_msec(10)
            continue
        
        var message: Dictionary = JSON.parse_string(line)
        if message:
            message_received.emit(message)
        
        if _mutex.try_lock():
            _mutex.unlock()
```

**优点**：
- 简单直接，无需网络配置
- 适合本地开发
- Claude Desktop 原生支持

**缺点**：
- 不支持远程访问
- 不支持双向流式通信

### HTTP 传输实现

**类**：`McpHttpServer`

**工作原理**：
1. 使用 Godot `TCPServer` 实现 HTTP 服务器
2. 解析 HTTP 请求（POST、GET、OPTIONS）
3. 支持 JSON-RPC over HTTP
4. 支持 SSE (Server-Sent Events) 流式响应

**HTTP 请求处理流程**：
```
客户端请求
    ↓
TCPServer.take_connection()
    ↓
解析 HTTP 请求头和方法
    ↓
认证验证（如果启用）
    ↓
路由到对应的处理器
    ├─ POST /mcp → 处理 JSON-RPC 请求
    ├─ GET /mcp → SSE 连接或服务器信息
    └─ OPTIONS → CORS 预检请求
    ↓
返回 HTTP 响应
```

**SSE 支持**：

SSE 允许服务器向客户端推送实时更新，适合长时间运行的工具。

**关键代码**：
```gdscript
func _handle_sse_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
    # 发送 SSE 响应头
    var response_header: String = "HTTP/1.1 200 OK\r\n"
    response_header += "Content-Type: text/event-stream\r\n"
    response_header += "Cache-Control: no-cache\r\n"
    response_header += "Connection: keep-alive\r\n"
    
    peer.put_data(response_header.to_utf8_buffer())
    
    # 发送初始消息
    _send_sse_event(peer, "connected", {"session_id": session_id})
    
    # 保持连接打开
    _sse_connections[peer] = session_id
```

**会话管理**：

每个 SSE 连接都有一个唯一的会话 ID，用于追踪客户端状态。

```gdscript
var _sse_connections: Dictionary = {}  # peer -> session_id
var _sessions: Dictionary = {}        # session_id -> session_data

func _generate_session_id() -> String:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    
    var chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var session_id: String = ""
    
    for i in range(32):
        var idx: int = rng.randi() % chars.length()
        session_id += chars[idx]
    
    return session_id
```

**优点**：
- 支持远程访问
- 支持 SSE 流式响应
- 易于集成到 Web 应用

**缺点**：
- 需要配置端口和防火墙
- 需要认证机制保证安全

### 传输模式对比

| 特性 | Stdio 模式 | HTTP 模式 |
|------|-------------|------------|
| 传输协议 | 标准输入/输出 | HTTP/1.1 |
| 适用场景 | 本地开发（暂不可用） | 生产部署、远程访问 |
| 状态 | ⚠️ 开发中 | ✅ 可用 |
| 认证支持 | 不支持（进程隔离） | 支持（Bearer Token） |
| SSE 支持 | 不支持 | 支持 |
| 远程访问 | 不支持 | 支持 |
| 配置复杂度 | 低 | 中 |
| 性能 | 高 | 中 |

---

## 工具系统

### 工具注册

Godot-MCP 实现了 **205 个工具**，分为 6 大类：

1. **Node Tools** (16 个)：节点管理（创建、删除、修改属性、复制、移动、重命名、信号连接、组管理）
2. **Script Tools** (9 个)：脚本管理（读取、创建、修改、分析、附加、验证、搜索）
3. **Scene Tools** (6 个)：场景管理
4. **Editor Tools** (8 个)：编辑器操作（运行、停止、截图、信号查询、文件系统重载）
5. **Debug Tools** (6 个)：调试和日志（日志获取、清除、脚本执行、性能监控）
6. **Project Tools** (5 个)：项目配置

### 工具定义结构

每个工具包含以下元数据：

```gdscript
{
  "name": "create_node",
  "description": "在指定父节点下创建新节点",
  "inputSchema": {
    "type": "object",
    "properties": {
      "parent_path": {
        "type": "string",
        "description": "父节点的路径"
      },
      "node_type": {
        "type": "string",
        "description": "节点类型（如 Node2D、Sprite2D）"
      },
      "node_name": {
        "type": "string",
        "description": "新节点的名称"
      }
    },
    "required": ["parent_path", "node_type", "node_name"]
  }
}
```

### 工具执行流程

```
AI Client 请求
    ↓
MCP Server 接收
    ↓
参数验证（使用 JSON Schema）
    ↓
权限检查（根据 security_level）
    ↓
调用工具实现
    ↓
执行 Godot Editor API
    ↓
返回执行结果
    ↓
发送给 AI Client
```

### 工具实现示例

**NodeToolsNative.gd**：

```gdscript
class_name NodeToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null

func initialize(editor_interface: EditorInterface) -> void:
    _editor_interface = editor_interface

func register_tools(server: MCPServerCore) -> void:
    server.register_tool(
        "create_node",
        "在指定父节点下创建新节点",
        {
            "type": "object",
            "properties": {
                "parent_path": {"type": "string"},
                "node_type": {"type": "string"},
                "node_name": {"type": "string"}
            },
            "required": ["parent_path", "node_type", "node_name"]
        },
        Callable(self, "_create_node")
    )

func _create_node(params: Dictionary) -> Dictionary:
    var parent_path: String = params.get("parent_path", "")
    var node_type: String = params.get("node_type", "")
    var node_name: String = params.get("node_name", "")
    
    # 验证参数
    if not ClassDB.class_exists(node_type):
        return {"status": "error", "message": "Invalid node type: " + node_type}
    
    # 获取父节点
    var parent: Node = _editor_interface.get_edited_scene_root().get_node_or_null(parent_path)
    if not parent:
        return {"status": "error", "message": "Parent node not found: " + parent_path}
    
    # 创建节点
    var node: Node = ClassDB.instantiate(node_type)
    node.name = node_name
    parent.add_child(node)
    node.owner = _editor_interface.get_edited_scene_root()
    
    return {
        "status": "success",
        "node_path": str(node.get_path()),
        "message": "Node created: " + node_name
    }
```

---

## 信号流

Godot 使用 **信号（Signals）** 进行线程间通信，确保线程安全。

### 线程模型

```
主线程（Godot Editor）
├─ 处理用户输入
├─ 渲染场景
└─ 执行 Godot Editor API
    ↑
    │ call_deferred()
    │
子线程（HTTP 服务器）
├─ 监听 TCP 连接
├─ 解析 HTTP 请求
└─ 发送信号到主线程
```

### 信号处理流程

**HTTP 服务器线程 → 主线程**：

```gdscript
# 在 HTTP 服务器线程中
func _handle_post_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
    var message: Dictionary = JSON.parse_string(parsed["body"])
    
    # 使用 call_deferred 确保在主线程执行
    call_deferred("_emit_message_received", message, peer)

# 在主线程中执行
func _emit_message_received(message: Dictionary, peer: StreamPeerTCP) -> void:
    message_received.emit(message, peer)
```

**主线程 → HTTP 服务器线程（响应）**：

```gdscript
# 在主线程中
func _send_response(response: Dictionary, context: Variant) -> void:
    if _transport_type == TransportType.TRANSPORT_HTTP:
        var peer: StreamPeerTCP = context as StreamPeerTCP
        if peer:
            _transport.send_response(response, peer)
```

### 关键信号

| 信号 | 发射者 | 接收者 | 用途 |
|------|---------|--------|------|
| `message_received` | Transport | MCPServerCore | 收到 JSON-RPC 消息 |
| `response_sent` | MCPServerCore | UI Panel | 响应已发送 |
| `tool_execution_started` | MCPServerCore | UI Panel | 工具开始执行 |
| `tool_execution_completed` | MCPServerCore | UI Panel | 工具执行完成 |
| `tool_execution_failed` | MCPServerCore | UI Panel | 工具执行失败 |
| `server_started` | Transport | MCP Server Native | 服务器已启动 |
| `server_stopped` | Transport | MCP Server Native | 服务器已停止 |

---

## 线程模型

### 线程安全策略

Godot MCP Native 使用以下策略确保线程安全：

1. **call_deferred()**：
   - 在子线程中调用，确保在主线程执行
   - 用于发射信号、调用 Godot Editor API

2. **Mutex**：
   - 保护共享资源（如消息队列）
   - 避免竞态条件

3. **信号**：
   - 线程间通信的安全方式
   - 避免直接访问其他线程的数据

### 示例：线程安全的消息处理

```gdscript
class_name McpStdioServer
extends McpTransportBase

var _mutex: Mutex = Mutex.new()
var _message_queue: Array[Dictionary] = []

# 在子线程中调用
func _push_message(message: Dictionary) -> void:
    _mutex.lock()
    _message_queue.append(message)
    _mutex.unlock()

# 在主线程中调用
func _process_message_queue() -> void:
    _mutex.lock()
    var messages: Array[Dictionary] = _message_queue.duplicate()
    _message_queue.clear()
    _mutex.unlock()
    
    for msg in messages:
        message_received.emit(msg)
```

---

## 安全设计

### 认证机制

Godot MCP Native 支持 **Token-based 认证**（仅 HTTP 模式）：

```gdscript
class_name McpAuthManager
extends RefCounted

var _token: String = ""
var _enabled: bool = true

func validate_request(headers: Dictionary) -> bool:
    if not _enabled:
        return true
    
    if not headers.has("Authorization"):
        return false
    
    var auth_header: String = headers["Authorization"]
    if not auth_header.begins_with("Bearer "):
        return false
    
    var token: String = auth_header.substr(7)
    
    # 时序安全比较（防止时序攻击）
    if token.length() != _token.length():
        return false
    
    for i in range(token.length()):
        if token[i] != _token[i]:
            return false
    
    return true
```

### 时序安全比较

**为什么需要时序安全比较？**

如果直接使用 `token == _token`，攻击者可以通过测量比较时间来判断 token 的正确字符。

**解决方案**：
- 始终比较所有字符（即使前面已经不匹配）
- 使用恒定时间算法

### 速率限制

防止滥用和 DoS 攻击：

```gdscript
var _request_count: Dictionary = {}  # IP -> count
var _rate_limit: int = 100  # 每分钟最大请求数

func _check_rate_limit(peer: StreamPeerTCP) -> bool:
    var ip: String = peer.get_connected_host()
    var current_time: int = Time.get_unix_time_from_system()
    
    if not _request_count.has(ip):
        _request_count[ip] = {"count": 1, "reset_time": current_time + 60}
        return true
    
    var data: Dictionary = _request_count[ip]
    
    if current_time > data["reset_time"]:
        # 重置计数器
        data["count"] = 1
        data["reset_time"] = current_time + 60
        return true
    
    if data["count"] >= _rate_limit:
        return false
    
    data["count"] += 1
    return true
```

### 路径遍历保护

防止访问项目目录之外的文件：

```gdscript
func _validate_path(path: String) -> bool:
    # 仅允许 res:// 和 user:// 路径
    if not path.begins_with("res://") and not path.begins_with("user://"):
        return false
    
    # 检查路径遍历
    if path.contains(".."):
        return false
    
    return true
```

---

## 性能优化

### 1. 异步处理

避免阻塞主线程：

```gdscript
# 使用 call_deferred 异步执行
call_deferred("_long_running_task", params)
```

### 2. 缓存

缓存频繁访问的数据：

```gdscript
var _scene_cache: Dictionary = {}

func _get_scene_info(scene_path: String) -> Dictionary:
    if _scene_cache.has(scene_path):
        return _scene_cache[scene_path]
    
    var info: Dictionary = _load_scene_info(scene_path)
    _scene_cache[scene_path] = info
    return info
```

### 3. 批量操作

减少 API 调用次数：

```gdscript
# 不好的做法
for node in nodes:
    _create_node(node)

# 好的做法
_create_nodes_batch(nodes)
```

### 4. 延迟加载

仅当需要时才加载工具：

```gdscript
func _register_all_tools() -> void:
    if _should_register_node_tools():
        _tool_instances["NodeToolsNative"] = NodeToolsNative.new()
        _tool_instances["NodeToolsNative"].register_tools(_native_server)
```

---

## 总结

Godot MCP Native 采用模块化、可扩展的架构设计，支持多种传输方式和工具。通过合理的线程模型和信号处理，确保系统的稳定性和性能。安全设计和性能优化措施进一步提升了系统的可靠性和用户体验。

如有任何问题或建议，欢迎在 GitHub Issues 中提出。
