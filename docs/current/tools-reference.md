# 工具参考手册

本手册详细说明 Godot MCP Native 项目的所有 MCP 工具，包括参数、返回值和使用示例。

## 目录

1. [工具概述](#工具概述)
2. [Node Tools](#node-tools)
3. [Script Tools](#script-tools)
4. [Scene Tools](#scene-tools)
5. [Editor Tools](#editor-tools)
6. [Debug Tools](#debug-tools)
7. [Project Tools](#project-tools)
8. [通用数据类型](#通用数据类型)
9. [错误处理](#错误处理)

---

## 工具概述

Godot MCP Native 当前实现了 **146 个工具**，分为 6 大类。本文档保留核心工具的详细参数说明；完整工具名清单见 [当前工具清单](tool-inventory.md)，实时参数和返回结构以 MCP `tools/list` 返回的 JSON Schema 为准。

| 类别 | 工具数量 | 源文件 | 用途 |
|------|----------|--------|------|
| [Node Tools](#node-tools) | 20 | `node_tools_native.gd` | 节点管理、批量节点编辑、场景继承/持久化审计、信号、组 |
| [Script Tools](#script-tools) | 14 | `script_tools_native.gd` | 脚本读写、符号索引/引用/重命名、跳转、附加、验证、搜索 |
| [Scene Tools](#scene-tools) | 8 | `scene_tools_native.gd` | 场景管理、打开标签页、场景结构、保存和关闭 |
| [Editor Tools](#editor-tools) | 15 | `editor_tools_native.gd` | 编辑器状态、运行控制、选择/聚焦、截图、Inspector、导出和重载 |
| [Debug Tools](#debug-tools) | 63 | `debug_tools_native.gd` | 日志、脚本执行、调试器、DAP 风格线程/栈/变量、运行时探针和运行时检查 |
| [Project Tools](#project-tools) | 26 | `project_tools_native.gd` | 项目配置、资源依赖/UID/import、输入映射、Autoload、全局类、测试和健康检查 |

### 完整工具清单

当前源码注册的完整工具名已整理到 [当前工具清单](tool-inventory.md)。新增或高频但未在本文展开的能力包括：

- 批量场景节点编辑：`batch_scene_node_edits`、`batch_update_node_properties`
- 脚本符号能力：`list_project_script_symbols`、`find_script_symbol_definition`、`find_script_symbol_references`、`rename_script_symbol`、`open_script_at_line`
- 场景标签页能力：`list_open_scenes`、`close_scene_tab`、`get_scene_structure`
- 编辑器和导出能力：`select_node`、`select_file`、`get_inspector_properties`、`list_export_presets`、`validate_export_preset`、`run_export`
- DAP 风格调试能力：`get_debug_threads`、`get_debug_stack_frames`、`get_debug_stack_variables`、`get_debug_scopes`、`expand_debug_variable`、`await_debugger_state`
- 运行时探针能力：`get_runtime_scene_tree`、`inspect_runtime_node`、`update_runtime_node_property`、`get_runtime_screenshot`、`simulate_runtime_input_event`、`assert_runtime_condition`
- 项目审计和测试能力：`audit_project_health`、`detect_broken_scripts`、`scan_missing_resource_dependencies`、`run_project_tests`、`inspect_csharp_project_support`

### 工具调用格式

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "<tool_name>",
    "arguments": {
      "<param1>": "<value1>",
      "<param2>": "<value2>"
    }
  },
  "id": 1
}
```

### 通用响应格式

**成功响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{...}"
      }
    ],
    "structuredContent": { }
  },
  "id": 1
}
```

**错误响应**（通过 `structuredContent` 中的 `error` 字段标识）：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"error\": \"Error description\"}"
      }
    ],
    "structuredContent": {
      "error": "Error description"
    }
  },
  "id": 1
}
```

### 工具注解 (Annotations)

每个工具都包含 MCP 标准注解，帮助客户端理解工具的行为：

| 注解 | 含义 |
|------|------|
| `readOnlyHint` | `true` 表示工具不会修改任何状态 |
| `destructiveHint` | `true` 表示工具可能造成不可逆的修改 |
| `idempotentHint` | `true` 表示相同参数重复调用结果一致 |
| `openWorldHint` | `true` 表示工具可能影响超出参数范围的状态 |

---

## Node Tools

### 1. create_node

在指定父节点下创建新节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 是 | 父节点的路径（如 `/root/MainScene`） |
| `node_type` | string | 是 | 节点类型（如 `Node2D`、`Sprite2D`、`CharacterBody2D`） |
| `node_name` | string | 是 | 新节点的名称 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 新节点的友好路径（如 `/root/MainScene/Player`） |
| `node_type` | string | 实际创建的节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 2. delete_node

删除指定节点。此操作不可撤销。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要删除的节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `deleted_node` | string | 被删除节点的名称 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 3. update_node_property

更新节点的属性值。支持 Undo/Redo（通过 `EditorUndoRedoManager`）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `property_name` | string | 是 | 属性名称（如 `position`、`visible`、`modulate`） |
| `property_value` | variant | 是 | 新的属性值（支持自动类型转换） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 节点路径 |
| `property_name` | string | 属性名称 |
| `old_value` | string | 修改前的值（字符串形式） |
| `new_value` | string | 修改后的值（字符串形式） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**值类型转换**：
- `Vector2` / `Vector2i`：传入 `{"x": 1, "y": 2}` 或字符串 `"(1, 2)"`
- `Vector3` / `Vector3i`：传入 `{"x": 1, "y": 2, "z": 3}` 或字符串 `"(1, 2, 3)"`
- `Color`：传入 `{"r": 1, "g": 0, "b": 0, "a": 1}` 或 `"#ff0000"`
- `bool`：传入 `true`/`false` 或字符串 `"true"`/`"false"`
- 字符串值会自动尝试 `JSON.parse_string()` 解析

---

### 4. get_node_properties

获取节点的所有属性。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `node_type` | string | 节点类型 |
| `properties` | Dictionary | 节点的所有属性键值对（已序列化） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

**属性过滤规则**：
- 跳过 `__` 前缀的内部属性
- 跳过 `CATEGORY`(128)、`GROUP`(64)、`SUBGROUP`(256) 用途的属性
- `Vector2`/`Vector3`/`Color` 等类型自动序列化为 Dictionary

---

### 5. list_nodes

列出指定父节点下的所有子节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 否 | 父节点路径。默认列出当前场景所有节点 |
| `recursive` | boolean | 否 | 是否递归列出所有子节点（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `nodes` | Array[string] | 节点友好路径数组 |
| `count` | int | 节点数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 6. get_scene_tree

获取当前场景的完整节点树。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大遍历深度。`-1` 表示无限制（默认 `-1`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `tree` | Dictionary | 场景树结构（嵌套） |
| `total_nodes` | int | 节点总数 |

**场景树节点结构**：
```json
{
  "name": "Player",
  "type": "Node2D",
  "path": "/root/MainScene/Player",
  "child_count": 2,
  "properties": {
    "visible": true,
    "position": {"x": 100, "y": 200}
  },
  "children": [...]
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 7. duplicate_node

复制节点及其子节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要复制的节点路径 |
| `new_name` | string | 否 | 新节点名称。如不提供，自动生成唯一名称（如 `Player2`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `original_path` | string | 原节点路径 |
| `new_node_path` | string | 新节点的友好路径 |
| `new_node_name` | string | 新节点名称 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- 使用 `node.duplicate()` 复制节点及其所有子节点
- 默认复制标志为 `DUPLICATE_DEFAULT`（15），包含脚本、信号、组和内部状态
- 复制的节点自动添加到原节点的父节点下
- 自动设置 `owner` 为当前场景根节点

---

### 8. move_node

将节点移动到新的父节点下。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要移动的节点路径 |
| `new_parent_path` | string | 是 | 新父节点路径 |
| `keep_global_transform` | boolean | 否 | 是否保持全局变换（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 原节点路径 |
| `new_parent_path` | string | 新父节点路径 |
| `new_node_path` | string | 移动后的节点路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- 使用 `node.reparent()` 方法安全移动节点
- `keep_global_transform=true` 时保持全局位置/旋转（推荐）
- 不允许将节点移动到自身或其后代节点下

---

### 9. rename_node

重命名场景中的节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要重命名的节点路径 |
| `new_name` | string | 是 | 新名称（必须在兄弟节点中唯一） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `old_name` | string | 原名称 |
| `new_name` | string | 新名称 |
| `node_path` | string | 重命名后的节点路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**行为**：
- 新名称必须在同一父节点下唯一
- 重命名为相同名称时直接返回成功

---

### 10. add_resource

向节点添加资源子节点（如碰撞形状、网格实例等）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 目标父节点路径 |
| `resource_type` | string | 是 | 资源节点类型（如 `CollisionShape2D`、`CollisionShape3D`、`MeshInstance3D`、`Sprite2D`） |
| `resource_name` | string | 否 | 资源节点名称。如不提供，使用类型作为名称 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 目标父节点路径 |
| `resource_node_path` | string | 新资源节点的友好路径 |
| `resource_type` | string | 实际创建的节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- 使用 `ClassDB.instantiate()` 创建节点实例
- 仅支持 `Node` 派生类型的实例化
- 自动设置 `owner` 为当前场景根节点

**常见资源类型**：
| 类型 | 用途 |
|------|------|
| `CollisionShape2D` / `CollisionShape3D` | 碰撞形状 |
| `MeshInstance3D` | 3D 网格实例 |
| `Sprite2D` | 2D 精灵 |
| `Area2D` | 检测区域 |
| `StaticBody3D` | 静态物理体 |
| `AudioStreamPlayer` | 音频播放器 |

---

### 11. set_anchor_preset

设置 Control 节点的锚点预设。仅对 Control 派生节点有效。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | Control 节点路径 |
| `preset` | int | 是 | LayoutPreset 枚举值（0-15） |
| `keep_offsets` | boolean | 否 | 是否保持当前偏移（默认 `false`） |

**LayoutPreset 枚举值**：
| 值 | 名称 | 描述 |
|-----|------|------|
| 0 | `TOP_LEFT` | 左上角 |
| 1 | `TOP_RIGHT` | 右上角 |
| 2 | `BOTTOM_LEFT` | 左下角 |
| 3 | `BOTTOM_RIGHT` | 右下角 |
| 4 | `CENTER_LEFT` | 左边居中 |
| 5 | `CENTER_TOP` | 顶部居中 |
| 6 | `CENTER_RIGHT` | 右边居中 |
| 7 | `CENTER_BOTTOM` | 底部居中 |
| 8 | `CENTER` | 完全居中 |
| 9 | `LEFT_WIDE` | 左侧宽 |
| 10 | `TOP_WIDE` | 顶部宽 |
| 11 | `RIGHT_WIDE` | 右侧宽 |
| 12 | `BOTTOM_WIDE` | 底部宽 |
| 13 | `VCENTER_WIDE` | 垂直居中宽 |
| 14 | `HCENTER_WIDE` | 水平居中宽 |
| 15 | `FULL_RECT` | 填满父节点 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `preset_name` | string | 预设名称（如 `"FULL_RECT"`） |
| `preset_value` | int | 预设值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 12. connect_signal

连接信号到接收方法。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `emitter_path` | string | 是 | 发射信号的节点路径 |
| `signal_name` | string | 是 | 信号名称（如 `pressed`、`body_entered`） |
| `receiver_path` | string | 是 | 接收方法的节点路径 |
| `receiver_method` | string | 是 | 接收方法名（如 `_on_button_pressed`） |
| `flags` | int | 否 | 连接标志（默认 `0`） |

**连接标志**：
| 值 | 名称 | 描述 |
|-----|------|------|
| 0 | `CONNECT_DEFAULT` | 默认连接 |
| 1 | `CONNECT_DEFERRED` | 延迟调用（帧末尾） |
| 2 | `CONNECT_ONE_SHOT` | 一次性连接（触发后自动断开） |
| 4 | `CONNECT_PERSIST` | 持久连接（保存到场景） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `emitter` | string | 发射节点路径 |
| `signal` | string | 信号名称 |
| `receiver` | string | 接收节点路径 |
| `method` | string | 接收方法名 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- 验证信号存在于发射节点
- 检查信号是否已连接（避免重复连接）
- 连接失败时返回错误码

---

### 13. disconnect_signal

断开信号连接。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `emitter_path` | string | 是 | 发射信号的节点路径 |
| `signal_name` | string | 是 | 信号名称 |
| `receiver_path` | string | 是 | 接收方法的节点路径 |
| `receiver_method` | string | 是 | 接收方法名 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"not_connected"` |
| `disconnected` | boolean | 是否成功断开 |
| `emitter` | string | 发射节点路径 |
| `signal` | string | 信号名称 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**行为**：
- 如果连接不存在，返回 `disconnected=false` 但不报错
- 使用 `is_connected()` 检查连接是否存在

---

### 14. get_node_groups

获取节点所属的所有组。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `groups` | Array[string] | 组名列表 |
| `group_count` | int | 组数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 15. set_node_groups

设置节点的组成员关系。支持添加、移除和清空操作。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `groups` | Array[string] | 否 | 要添加的组名列表 |
| `remove_groups` | Array[string] | 否 | 要移除的组名列表 |
| `persistent` | boolean | 否 | 是否持久化到场景文件（默认 `false`） |
| `clear_existing` | boolean | 否 | 是否先清除所有现有组（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `added_groups` | Array[string] | 已添加的组名列表 |
| `removed_groups` | Array[string] | 已移除的组名列表 |
| `current_groups` | Array[string] | 当前所有组名列表 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- `clear_existing=true` 时先清除所有现有组，再添加新组
- 添加已存在的组不会重复添加
- 移除不存在的组不会报错
- `persistent=true` 时组关系会保存到场景文件

---

### 16. find_nodes_in_group

查找属于指定组的所有节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `group` | string | 是 | 组名 |
| `node_type` | string | 否 | 按节点类型过滤（如 `Node2D`、`CharacterBody2D`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `group` | string | 搜索的组名 |
| `nodes` | Array[Dictionary] | 节点信息数组 |
| `node_count` | int | 节点数量 |

**每个节点信息**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 节点名称 |
| `type` | string | 节点类型 |
| `path` | string | 节点友好路径 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Script Tools

### 17. list_project_scripts

列出项目中的所有 GDScript 文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径（如 `res://scripts/`）。默认 `res://` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scripts` | Array[string] | 脚本文件路径数组 |
| `count` | int | 脚本数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 18. read_script

读取指定脚本的内容。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_path` | string | 脚本路径 |
| `content` | string | 脚本完整内容 |
| `line_count` | int | 行数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 19. create_script

创建新脚本文件，支持模板和自动附加到节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |
| `content` | string | 否 | 初始内容。如不提供，使用模板 |
| `template` | string | 否 | 模板名称：`empty`（默认）、`node`、`characterbody2d`、`characterbody3d` |
| `attach_to_node` | string | 否 | 创建后自动附加到此节点路径（如 `/root/MainScene/Player`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 创建的脚本路径 |
| `line_count` | int | 行数 |
| `attached_to` | string | 附加到的节点路径（仅当 `attach_to_node` 成功时） |
| `attach_warning` | string | 附加警告信息（仅当附加失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 20. modify_script

修改现有脚本的内容。支持全量替换和单行替换。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `content` | string | 是 | 新内容（全量替换或单行内容） |
| `line_number` | int | 否 | 行号（1-indexed）。提供时仅替换该行，否则全量替换 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 脚本路径 |
| `line_count` | int | 修改后的行数 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 21. analyze_script

分析脚本的代码结构。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_path` | string | 脚本路径 |
| `has_class_name` | boolean | 是否声明了 `class_name` |
| `extends_from` | string | 继承的基类 |
| `language` | string | 脚本语言：`gdscript`、`csharp` 或 `unknown` |
| `functions` | Array[string] | 函数名列表 |
| `signals` | Array[string] | 信号名列表 |
| `properties` | Array[string] | 公有属性名列表（跳过 `_` 前缀的私有变量） |
| `line_count` | int | 行数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 22. get_current_script

获取编辑器中当前正在编辑的脚本。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_found` | boolean | 是否找到正在编辑的脚本 |
| `script_path` | string | 脚本路径（仅当 `script_found=true`） |
| `content` | string | 脚本完整内容（仅当 `script_found=true`） |
| `line_count` | int | 行数（仅当 `script_found=true`） |
| `message` | string | 说明信息（仅当 `script_found=false`） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 23. attach_script

将现有 GDScript 文件附加到场景中的节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 目标节点路径（如 `/root/MainScene/Player`） |
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 目标节点路径 |
| `script_path` | string | 附加的脚本路径 |
| `previous_script` | string | 被替换的旧脚本路径（空字符串表示无旧脚本） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**行为**：
- 使用 `node.set_script()` 附加脚本
- 如果节点已有脚本，返回 `previous_script` 记录旧脚本路径
- 附加后自动刷新 `EditorFileSystem`

---

### 24. validate_script

验证 GDScript 语法，不执行脚本。检查错误和警告。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 否 | 要验证的脚本文件路径（如 `res://scripts/player.gd`） |
| `content` | string | 否 | 直接验证的脚本内容（与 `script_path` 二选一） |
| `check_warnings` | boolean | 否 | 是否检查警告（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `valid` | boolean | 脚本是否通过验证 |
| `errors` | Array[Dictionary] | 错误列表 |
| `warnings` | Array[Dictionary] | 警告列表 |
| `error_count` | int | 错误数量 |
| `warning_count` | int | 警告数量 |

**错误/警告条目结构**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `line` | int | 行号 |
| `column` | int | 列号 |
| `message` | string | 错误/警告消息 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

**行为**：
- 支持文件路径和直接内容两种验证模式
- 使用 `GDScript.new() + reload()` 进行原生语法验证
- `script_path` 和 `content` 至少提供一个

---

### 25. search_in_files

在项目文件中搜索文本模式。支持字面量和正则表达式匹配。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `pattern` | string | 是 | 搜索模式（文本或正则表达式） |
| `search_path` | string | 否 | 搜索目录（默认 `res://`） |
| `file_extensions` | Array[string] | 否 | 文件扩展名过滤（默认 `[".gd"]`） |
| `use_regex` | boolean | 否 | 是否使用正则匹配（默认 `false`，字面量匹配） |
| `case_sensitive` | boolean | 否 | 是否区分大小写（默认 `true`） |
| `max_results` | int | 否 | 最大返回结果数（默认 `50`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `pattern` | string | 搜索模式 |
| `results` | Array[Dictionary] | 搜索结果数组 |
| `total_matches` | int | 匹配总数 |
| `files_searched` | int | 搜索的文件数 |

**每个文件结果**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `file` | string | 文件路径 |
| `matches` | Array[Dictionary] | 匹配列表 |
| `match_count` | int | 匹配数量 |

**每个匹配条目**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `line` | int | 行号 |
| `text` | string | 匹配的文本内容 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Scene Tools

### 26. create_scene

创建新场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径（如 `res://scenes/level1.tscn`） |
| `root_node_type` | string | 否 | 根节点类型（默认 `Node`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `scene_path` | string | 创建的场景路径 |
| `root_node_type` | string | 根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 27. save_scene

保存当前打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `file_path` | string | 否 | 保存路径。如不提供，保存到当前场景路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `saved_path` | string | 保存的场景路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 28. open_scene

打开指定场景文件。会关闭当前打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `scene_path` | string | 打开的场景路径 |
| `root_node_type` | string | 根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 29. get_current_scene

获取当前打开的场景信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `scene_path` | string | 场景文件路径 |
| `root_node_type` | string | 根节点类型 |
| `node_count` | int | 节点总数 |
| `is_modified` | boolean | 场景是否有未保存的修改 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 30. get_scene_structure

获取当前场景的完整树结构。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大遍历深度。`-1` 表示无限制（默认 `-1`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `root_node` | Dictionary | 根节点树结构（嵌套） |
| `total_nodes` | int | 节点总数 |

**节点结构**：
```json
{
  "name": "Player",
  "type": "Node2D",
  "path": "/root/MainScene/Player",
  "children": [...]
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 31. list_project_scenes

列出项目中的所有场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径（如 `res://scenes/`）。默认 `res://` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scenes` | Array[string] | 场景文件路径数组 |
| `count` | int | 场景数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Editor Tools

### 32. get_editor_state

获取 Godot Editor 的当前状态。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `active_scene` | string | 当前打开的场景名称 |
| `selected_nodes` | Array[string] | 选中的节点路径列表 |
| `editor_mode` | string | 编辑器模式 |
| `selected_count` | int | 选中节点数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 33. run_project

运行当前项目（Play 按钮）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 否 | 指定要运行的场景路径。如不提供，运行主场景 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mode` | string | `"playing"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 34. stop_project

停止运行项目（Stop 按钮）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mode` | string | `"editor"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 35. get_selected_nodes

获取当前选中的节点列表（含类型和脚本信息）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `selected_nodes` | Array[Dictionary] | 选中的节点信息数组 |
| `count` | int | 选中节点数量 |

**每个节点信息包含**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `path` | string | 节点的友好路径 |
| `type` | string | 节点类型（如 `Node2D`、`Sprite2D`） |
| `script_path` | string | 附加脚本的路径（仅当节点有脚本时） |

**示例响应**：
```json
{
  "selected_nodes": [
    {
      "path": "/root/MainScene/Player",
      "type": "CharacterBody2D",
      "script_path": "res://scripts/player.gd"
    }
  ],
  "count": 1
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 36. set_editor_setting

修改 Godot Editor 的设置。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_name` | string | 是 | 设置名称（如 `interface/theme/accent_color`） |
| `setting_value` | variant | 是 | 新的设置值 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `setting_name` | string | 设置名称 |
| `old_value` | string | 修改前的值 |
| `new_value` | string | 修改后的值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**注意**：部分设置需要重启编辑器才能生效。

---

### 37. get_editor_screenshot

截取编辑器视口截图并保存到文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `viewport_type` | string | 否 | 视口类型：`3d` 或 `2d`（默认 `3d`） |
| `viewport_index` | int | 否 | 3D 视口索引 0-3（默认 `0`） |
| `save_path` | string | 否 | 截图保存路径（默认 `res://screenshot_editor.png`） |
| `format` | string | 否 | 图片格式：`png` 或 `jpg`（默认 `png`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `save_path` | string | 截图保存路径 |
| `size` | string | 图片尺寸（如 `1920x1080`） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=false`

---

### 38. get_signals

获取节点的所有信号及其连接信息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `include_connections` | boolean | 否 | 是否包含连接详情（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `signals` | Array[Dictionary] | 信号信息数组 |
| `signal_count` | int | 信号数量 |
| `connection_count` | int | 连接总数 |

**每个信号信息**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 信号名称 |
| `arguments` | int | 参数数量 |
| `connections` | Array[Dictionary] | 连接列表（仅 `include_connections=true`） |
| `connection_count` | int | 连接数量（仅 `include_connections=true`） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 39. reload_project

重新扫描项目文件系统并重新加载脚本。适用于外部文件修改后同步。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `full_scan` | boolean | 否 | 是否执行全量扫描（默认 `false`，仅扫描源文件） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"already_scanning"` |
| `scan_type` | string | `"full"` 或 `"sources_only"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**行为**：
- `full_scan=false`：使用 `EditorFileSystem.scan_sources()`，仅扫描源文件变更
- `full_scan=true`：使用 `EditorFileSystem.scan()`，全量重新扫描
- 如果正在扫描中，返回 `already_scanning` 状态和当前进度

---

## Debug Tools

### 40. get_editor_logs

获取编辑器或运行时日志。支持过滤、分页和排序。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `source` | string | 否 | 日志源：`mcp`（MCP 服务器日志，默认）或 `runtime`（`user://logs/godot.log`） |
| `type` | Array[string] | 否 | 按类型过滤（如 `["Error", "Warning"]`）。仅对 MCP 源有效。空数组返回所有 |
| `count` | int | 否 | 返回的最大日志条数（默认 `100`） |
| `offset` | int | 否 | 跳过的日志条数（默认 `0`） |
| `order` | string | 否 | 排序：`desc`（最新优先，默认）或 `asc`（最旧优先） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `logs` | Array[Dictionary] | 日志条目数组 |
| `count` | int | 返回的日志条数 |
| `total_available` | int | 可用日志总数 |
| `source` | string | 日志源 |

**每条日志条目**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `index` | int | 日志索引 |
| `type` | string | 日志类型：`Error`、`Warning`、`Info`、`Debug` |
| `message` | string | 日志内容 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 41. execute_script

在编辑器中执行 GDScript 表达式。使用 Godot 的 `Expression` 类进行安全求值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `code` | string | 是 | GDScript 表达式代码 |
| `bind_objects` | Dictionary | 否 | 额外绑定到表达式的对象 |

**内置绑定单例**：`OS`、`Engine`、`ProjectSettings`、`Input`、`Time`、`JSON`、`ClassDB`、`Performance`、`ResourceLoader`、`ResourceSaver`、`EditorInterface`

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `result` | string | 执行结果（字符串形式） |
| `error` | string | 错误信息（仅失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**限制**：仅支持表达式求值，不支持多行语句、循环、条件判断和 `await`。

---

### 42. get_performance_metrics

获取项目运行的性能数据。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `fps` | float | 当前帧率 |
| `object_count` | int | 对象总数 |
| `resource_count` | int | 资源总数 |
| `memory_usage_mb` | float | 静态内存使用量（MB） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 43. debug_print

在 Godot Editor 输出面板中打印调试信息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `message` | string | 是 | 要打印的消息 |
| `category` | string | 否 | 消息分类标签（如 `MCP`、`AI`、`Debug`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `printed_message` | string | 实际打印的完整消息（含分类前缀） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 44. execute_editor_script

在编辑器上下文中执行完整的 GDScript 脚本。与 `execute_script` 不同，此工具支持多行语句、循环、条件判断等。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `code` | string | 是 | 完整的 GDScript 代码 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `success` | boolean | 是否执行成功 |
| `output` | Array[string] | 执行输出 |
| `error` | string | 错误信息（仅失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=true`

**特性**：
- 支持多行脚本、循环、条件判断
- 自动捕获 `print()` 输出
- 可访问 `edited_scene`（当前编辑的场景根节点）
- 脚本编译失败会返回明确的错误信息

**示例**：
```json
{
  "name": "execute_editor_script",
  "arguments": {
    "code": "var scene = edited_scene\nif scene:\n    _custom_print(scene.name)\n    _custom_print(str(scene.get_child_count()) + ' children')\nelse:\n    _custom_print('No scene open')"
  }
}
```

---

### 45. clear_output

清除编辑器输出面板和 MCP 日志缓冲区。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `clear_mcp_buffer` | boolean | 否 | 是否清除 MCP 日志缓冲区（默认 `true`） |
| `clear_editor_panel` | boolean | 否 | 是否清除编辑器输出面板（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mcp_buffer_cleared` | boolean | MCP 缓冲区是否已清除 |
| `editor_panel_cleared` | boolean | 编辑器面板是否已清除 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=true`

**行为**：
- 清除 MCP 日志缓冲区（线程安全，使用 Mutex 保护）
- 清除编辑器输出面板（通过遍历节点树查找 `EditorLog` 面板）
- 两个清除操作独立控制

---

### 46. get_debugger_sessions

列出 Godot 编辑器调试会话及其状态。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `sessions` | Array[Dictionary] | 调试会话列表 |
| `count` | int | 会话数量 |

**每个会话**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `session_id` | int | 会话 ID |
| `active` | boolean | 是否连接到运行中的实例 |
| `breaked` | boolean | 是否处于断点暂停状态 |
| `debuggable` | boolean | 当前实例是否可脚本调试 |

---

### 47. set_debugger_breakpoint

通过 Godot `EditorDebuggerSession` 启用或禁用脚本断点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `path` | string | 是 | 脚本路径，如 `res://player.gd` |
| `line` | int | 是 | 1-based 行号 |
| `enabled` | boolean | 是 | 是否启用断点 |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success`、`no_sessions` 或错误 |
| `sessions_updated` | int | 更新的会话数量 |

---

### 48. send_debugger_message

向活动调试会话中的运行实例发送自定义 `EngineDebugger` 消息。运行时脚本可通过 `EngineDebugger.register_message_capture()` 接收。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `message` | string | 是 | 消息名，如 `mcp:ping` |
| `data` | Array | 否 | 附加数据 |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success`、`no_active_sessions` 或错误 |
| `sessions_updated` | int | 接收消息的活动会话数量 |

---

### 49. toggle_debugger_profiler

在活动调试会话中切换运行时 `EngineProfiler`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `profiler` | string | 是 | Profiler 名称 |
| `enabled` | boolean | 是 | 是否启用 |
| `data` | Array | 否 | 传给 profiler 的附加参数 |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success`、`no_active_sessions` 或错误 |
| `sessions_updated` | int | 更新的活动会话数量 |

---

### 50. get_debugger_messages

读取 `MCPDebuggerBridge` 从运行实例捕获的自定义调试消息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `count` | int | 否 | 最大返回条数（默认 `100`） |
| `offset` | int | 否 | 跳过条数（默认 `0`） |
| `order` | string | 否 | `desc` 或 `asc`，默认 `desc` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `messages` | Array[Dictionary] | 捕获消息 |
| `count` | int | 返回数量 |
| `total_available` | int | 可用消息总数 |

---

### 51. add_debugger_capture_prefix

允许 debugger bridge 捕获更多 `EngineDebugger` 消息前缀。默认捕获 `mcp`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `prefix` | string | 是 | 前缀，不包含冒号；`*` 表示捕获全部 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success` |
| `prefixes` | Array[string] | 当前捕获前缀列表 |

---

### 52. get_debug_stack_frames

返回最近捕获到的脚本栈帧，并可向已暂停会话请求刷新 `get_stack_dump`。通常先使用 `request_debug_break` 让运行实例进入暂停状态，再调用本工具。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `refresh` | boolean | 否 | 是否先请求刷新栈帧；默认 `true` |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `frames` | Array[Dictionary] | 栈帧列表，包含 `frame`、`file`、`function`、`line` |
| `count` | int | 栈帧数量 |
| `refresh_result` | Dictionary | 刷新请求结果 |

---

### 53. get_debug_stack_variables

返回指定栈帧最近捕获到的局部变量、成员变量和全局变量，并可向已暂停会话请求刷新 `get_stack_frame_vars`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `frame` | int | 否 | 栈帧索引，默认 `0` |
| `refresh` | boolean | 否 | 是否先请求刷新变量；默认 `true` |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `frame` | int | 栈帧索引 |
| `variables` | Array[Dictionary] | 变量列表，包含 `name`、`scope`、`type`、`value` 和 `raw` |
| `count` | int | 变量数量 |
| `refresh_result` | Dictionary | 刷新请求结果 |

---

### 54. install_runtime_probe

向当前场景添加 `MCPRuntimeProbe` 节点。运行项目后，该节点会注册 `EngineDebugger` capture，并响应 `mcp:ping`、`mcp:get_runtime_info`、`mcp:get_scene_tree`、`mcp:inspect_node`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_name` | string | 否 | 探针节点名，默认 `MCPRuntimeProbe` |
| `persistent` | boolean | 否 | 是否设置 owner 以便保存到场景；默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success` 或 `already_installed` |
| `node_path` | string | 探针节点路径 |
| `persistent` | boolean | 是否为可保存节点 |

---

### 55. remove_runtime_probe

从当前场景移除 `MCPRuntimeProbe` 节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_name` | string | 否 | 探针节点名，默认 `MCPRuntimeProbe` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success` 或 `not_installed` |
| `removed_node` | string | 被移除的节点路径 |

---

### 56. request_debug_break

请求已安装的 `MCPRuntimeProbe` 调用 `EngineDebugger.debug()`，让运行实例进入 Godot 脚本调试暂停循环。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success`、`no_active_sessions` 或错误 |
| `sessions_updated` | int | 接收请求的活动会话数量 |

---

### 57. send_debug_command

向已暂停的 Godot 调试循环发送命令。支持 `step`、`next`、`out`、`continue`、`get_stack_dump`、`get_stack_frame_vars`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `command` | string | 是 | 调试命令 |
| `data` | Array | 否 | 命令参数，如 `get_stack_frame_vars` 使用 `[0]` 请求第 0 帧变量 |
| `session_id` | int | 否 | 目标调试会话，默认 `-1` 表示全部活动会话 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `success`、`no_active_sessions` 或错误 |
| `sessions_updated` | int | 接收命令的活动会话数量 |
| `note` | string | 对 stack 命令的 Godot API 限制说明 |

**提示**：读取栈帧和变量时优先使用 `get_debug_stack_frames` / `get_debug_stack_variables`；它们会监听内置 `ScriptEditorDebugger` 信号并返回结构化数据。

---

## Project Tools

### 58. get_project_info

获取项目的基本信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `project_name` | string | 项目名称 |
| `project_version` | string | 项目版本 |
| `project_description` | string | 项目描述 |
| `main_scene` | string | 主场景路径（自动解析 ResourceUID） |
| `project_path` | string | 项目在文件系统中的绝对路径 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 59. get_project_settings

获取项目的设置值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `filter` | string | 否 | 设置路径前缀过滤（如 `display/`、`input/`）。不提供则返回所有设置 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `settings` | Dictionary | 设置键值对（值均为字符串形式） |
| `count` | int | 设置数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 60. list_project_resources

列出项目中的所有资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径。默认 `res://` |
| `resource_types` | Array[string] | 否 | 文件扩展名过滤（如 `[".tres", ".png"]`）。不提供则返回所有常见资源类型 |

**默认搜索的扩展名**：`.tres`, `.res`, `.png`, `.jpg`, `.webp`, `.ogg`, `.wav`, `.mp3`, `.obj`, `.glb`, `.gltf`, `.material`, `.shader`, `.gdshader`, `.tscn`, `.gd`, `.cfg`, `.json`, `.ttf`, `.otf` 等

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resources` | Array[string] | 资源文件路径数组 |
| `count` | int | 资源数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 61. create_resource

创建新的 Godot 资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 资源保存路径（如 `res://resources/my_curve.tres`） |
| `resource_type` | string | 是 | 资源类型（如 `Curve`、`Gradient`、`StyleBoxFlat`、`Animation`） |
| `properties` | Dictionary | 否 | 要设置的属性键值对 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `resource_path` | string | 资源路径 |
| `resource_type` | string | 资源类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 62. get_project_structure

获取项目的目录结构和文件类型统计。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大目录遍历深度（默认 `3`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `directories` | Array[string] | 目录路径列表 |
| `file_counts` | Dictionary | 按扩展名统计的文件数量（如 `{"gd": 15, "tscn": 8}`） |
| `total_files` | int | 文件总数 |
| `total_directories` | int | 目录总数 |

**示例响应**：
```json
{
  "directories": ["res://", "res://addons/", "res://scenes/"],
  "file_counts": {"gd": 15, "tscn": 8, "png": 23},
  "total_files": 46,
  "total_directories": 3
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## 通用数据类型

### Vector2

```json
{"x": 0.0, "y": 0.0}
```

### Vector2i

```json
{"x": 0, "y": 0}
```

### Vector3

```json
{"x": 0.0, "y": 0.0, "z": 0.0}
```

### Vector3i

```json
{"x": 0, "y": 0, "z": 0}
```

### Vector4

```json
{"x": 0.0, "y": 0.0, "z": 0.0, "w": 0.0}
```

### Color

```json
{"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
```

### Rect2

```json
{"x": 0, "y": 0, "w": 100, "h": 100}
```

### Transform2D

```json
{
  "rotation": 0.0,
  "origin": {"x": 0.0, "y": 0.0}
}
```

---

## 错误处理

### 错误响应格式

工具调用失败时，`structuredContent` 中会包含 `error` 字段：

```json
{
  "error": "Node not found: /root/NonExistent"
}
```

### 常见错误

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `"Editor interface not available"` | 编辑器接口未注入 | 确保插件已正确加载 |
| `"Parent node not found: ..."` | 节点路径无效 | 使用 `list_nodes` 查看可用节点 |
| `"Invalid node type: ..."` | 节点类型不存在 | 使用 `ClassDB.class_exists()` 验证 |
| `"Node not found: ..."` | 节点路径无效 | 检查节点路径是否正确 |
| `"Property '...' not found on node ..."` | 属性不存在 | 使用 `get_node_properties` 查看可用属性 |
| `"Missing required parameter: ..."` | 缺少必需参数 | 检查参数是否完整 |
| `"Invalid path: ..."` | 路径安全验证失败 | 确保路径以 `res://` 开头且不包含 `..` |
| `"File not found: ..."` | 文件不存在 | 检查文件路径是否正确 |
| `"File already exists: ..."` | 文件已存在 | 使用不同的路径或先删除现有文件 |
| `"Failed to open file: ..."` | 文件无法打开 | 检查文件权限 |
| `"Invalid resource type: ..."` | 资源类型不存在 | 使用 `ClassDB.class_exists()` 验证 |
| `"Scene operation in progress, please retry"` | 场景操作锁 | 等待当前操作完成后重试 |
| `"No scene is currently open"` | 没有打开的场景 | 先使用 `open_scene` 打开场景 |
| `"Script compilation failed. Check syntax."` | 脚本编译失败 | 检查 GDScript 语法 |

### 路径安全 (PathValidator)

所有文件和目录路径都经过 `PathValidator` 验证：

- 路径必须以 `res://` 开头
- 不允许包含 `..`（防止路径遍历）
- 文件路径会验证扩展名（如 `.gd`、`.tscn`、`.tres`）
- 路径会被清理和规范化

---

## 总结

本手册详细说明了 Godot MCP Native 项目的核心工具。当前源码注册了 146 个工具；完整清单见 [当前工具清单](tool-inventory.md)，实时参数、返回值和注解信息以 `tools/list` 为准。

**提示**：
- 使用 `tools/list` 方法获取所有工具的实时列表和完整 JSON Schema
- 关注每个工具的注解（`readOnlyHint`、`destructiveHint` 等）来理解工具的行为
- `update_node_property` 支持 Undo/Redo，可通过 `Ctrl+Z` 撤销
- `duplicate_node` 可复制节点及其子节点，自动生成唯一名称
- `move_node` 使用 `reparent()` 安全移动节点，支持保持全局变换
- `connect_signal` / `disconnect_signal` 管理节点间的信号连接
- `set_node_groups` / `get_node_groups` / `find_nodes_in_group` 管理节点组
- `set_anchor_preset` 快速设置 Control 节点的布局锚点
- `execute_editor_script` 适合复杂脚本执行，`execute_script` 适合简单表达式求值
- 所有文件路径都经过 `PathValidator` 安全验证
