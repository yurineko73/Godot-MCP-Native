# 工具参考手册

本手册详细说明 Godot MCP Native 项目的所有 MCP 工具，包括参数、返回值和使用示例。

## 目录

1. [工具概述](#工具概述)
2. [MCP Resources](#mcp-resources)
3. [Node Tools](#node-tools)
4. [Script Tools](#script-tools)
5. [Scene Tools](#scene-tools)
6. [Editor Tools](#editor-tools)
7. [Debug Tools](#debug-tools)
8. [Project Tools](#project-tools)
9. [通用数据类型](#通用数据类型)
10. [错误处理](#错误处理)

---

## 工具概述

Godot MCP Native 实现了 **205 个工具**，分为 6 大类（含核心和补充工具）：

| 类别 | 核心工具 | 补充工具 | 总计 | 源文件 | 用途 |
|------|----------|----------|------|--------|------|
| [Node Tools](#node-tools) | 16 | 4 | 20 | `node_tools_native.gd` | 节点管理（创建、删除、修改属性、复制、移动、重命名、信号、组） |
| [Script Tools](#script-tools) | 9 | 5 | 14 | `script_tools_native.gd` | 脚本管理（读取、创建、修改、分析、附加、验证、搜索、符号索引） |
| [Scene Tools](#scene-tools) | 6 | 2 | 8 | `scene_tools_native.gd` | 场景管理（创建、保存、打开、列出） |
| [Editor Tools](#editor-tools) | 7 | 38 | 45 | `editor_tools_native.gd` | 编辑器操作（运行、停止、状态、截图、信号、导出、选择、编辑器路径、shell 状态、编辑器元数据、运行态、3D 吸附状态、子系统可用性、预览器可用性、undo/redo 可用性、视口可用性、base control 可用性、file-system-dock 可用性、inspector 可用性、当前位置摘要、选中路径摘要、selection 对象可用性、command palette 可用性、toaster 可用性、resource filesystem 可用性、script editor 可用性、当前脚本摘要、当前场景摘要、打开场景列表摘要、打开场景根节点摘要、editor settings 可用性、editor theme 可用性、当前 feature profile 摘要、单 plugin enabled 状态、当前场景 dirty-state 摘要） |
| [Debug Tools](#debug-tools) | 3 | 67 | 70 | `debug_tools_native.gd` | 调试和运行时（日志、断点、栈帧、Profiler、运行时探针、动画、音频、着色器、瓦片地图） |
| [Project Tools](#project-tools) | 5 | 43 | 48 | `project_tools_native.gd` | 项目配置（信息、设置、单项写入与清理、单 project setting 检查、插件列表、单插件检查与单插件启停、project configuration summary、autoload 列表、单 autoload 检查与单项写入/删除、feature profile 列表、单 feature profile 检查与单项切换、测试、输入映射列表、单 input action 检查与单项写入/删除、全局类列表、单 global class 检查、自动加载、资源检查、复制、移动、删除、写入与诊断） |

## MCP Resources

Godot MCP Native 当前注册了 **47 个 MCP 资源**，用于稳定的只读上下文获取：

| URI | 名称 | MIME Type | 描述 |
|------|------|------|------|
| `godot://scene/list` | Godot Scene List | `application/json` | List of all .tscn scene files in the project |
| `godot://scene/current` | Current Scene | `application/json` | Structure of the currently open scene in the editor |
| `godot://scene/open` | Open Godot Scenes | `application/json` | Get the currently open scene tabs in the editor |
| `godot://tools/catalog` | Godot Tool Catalog | `application/json` | Get the live registered MCP tool catalog |
| `godot://script/list` | Godot Script List | `application/json` | List of all .gd script files in the project |
| `godot://script/current` | Current Script | `text/plain` | Content of the currently open script in the editor |
| `godot://editor/script_summary` | Editor Script Summary | `application/json` | Get the current open-script/editor summary snapshot |
| `godot://editor/paths` | Editor Paths | `application/json` | Get the current editor paths snapshot |
| `godot://editor/shell_state` | Editor Shell State | `application/json` | Get the current editor shell-state snapshot |
| `godot://editor/language` | Editor Language | `application/json` | Get the current editor language snapshot |
| `godot://editor/current_location` | Editor Current Location | `application/json` | Get the current editor path and directory snapshot |
| `godot://editor/current_feature_profile` | Editor Current Feature Profile | `application/json` | Get the current editor feature-profile snapshot |
| `godot://editor/selected_paths` | Editor Selected Paths | `application/json` | Get the current editor selected-path snapshot |
| `godot://editor/play_state` | Editor Play State | `application/json` | Get the current editor play-state snapshot |
| `godot://editor/3d_snap_state` | Editor 3D Snap State | `application/json` | Get the current editor 3D snap-state snapshot |
| `godot://editor/subsystem_availability` | Editor Subsystem Availability | `application/json` | Get the current editor subsystem availability snapshot |
| `godot://editor/previewer_availability` | Editor Previewer Availability | `application/json` | Get the current editor resource-previewer availability snapshot |
| `godot://editor/undo_redo_availability` | Editor Undo Redo Availability | `application/json` | Get the current editor undo-redo availability snapshot |
| `godot://editor/base_control_availability` | Editor Base Control Availability | `application/json` | Get the current editor base-control availability snapshot |
| `godot://editor/file_system_dock_availability` | Editor File System Dock Availability | `application/json` | Get the current editor file-system-dock availability snapshot |
| `godot://editor/inspector_availability` | Editor Inspector Availability | `application/json` | Get the current editor inspector availability snapshot |
| `godot://editor/viewport_availability` | Editor Viewport Availability | `application/json` | Get the current editor viewport availability snapshot |
| `godot://editor/selection_availability` | Editor Selection Availability | `application/json` | Get the current editor selection-object availability snapshot |
| `godot://editor/command_palette_availability` | Editor Command Palette Availability | `application/json` | Get the current editor command-palette availability snapshot |
| `godot://editor/toaster_availability` | Editor Toaster Availability | `application/json` | Get the current editor toaster availability snapshot |
| `godot://editor/resource_filesystem_availability` | Editor Resource Filesystem Availability | `application/json` | Get the current editor resource-filesystem availability snapshot |
| `godot://editor/script_editor_availability` | Editor Script Editor Availability | `application/json` | Get the current editor script-editor availability snapshot |
| `godot://editor/settings_availability` | Editor Settings Availability | `application/json` | Get the current editor settings availability snapshot |
| `godot://editor/theme_availability` | Editor Theme Availability | `application/json` | Get the current editor theme availability snapshot |
| `godot://editor/current_scene_dirty_state` | Editor Current Scene Dirty State | `application/json` | Get the current active scene dirty-state snapshot |
| `godot://editor/open_scene_summary` | Editor Open Scene Summary | `application/json` | Get the current open-scene summary snapshot |
| `godot://editor/open_scenes_summary` | Editor Open Scenes Summary | `application/json` | Get the current open-scenes summary snapshot |
| `godot://editor/open_scene_roots_summary` | Editor Open Scene Roots Summary | `application/json` | Get the current open-scene-roots summary snapshot |
| `godot://project/info` | Project Info | `application/json` | Project name, version, and basic information |
| `godot://project/settings` | Project Settings | `application/json` | Project setting values and configuration |
| `godot://project/class_metadata` | Project Class Metadata | `application/json` | Get normalized project global class metadata |
| `godot://project/global_classes` | Project Global Classes | `application/json` | Get the installed project global class inventory |
| `godot://project/configuration_summary` | Project Configuration Summary | `application/json` | Get a bounded snapshot of installed plugins, autoloads, and feature profiles |
| `godot://project/plugins` | Project Plugins | `application/json` | Get the installed project plugin inventory and enabled states |
| `godot://project/feature_profiles` | Project Feature Profiles | `application/json` | Get the installed project feature-profile inventory and current active profile |
| `godot://project/autoloads` | Project Autoloads | `application/json` | Get the installed project autoload inventory |
| `godot://project/tests` | Project Tests | `application/json` | Get the discovered project test inventory |
| `godot://project/test_runners` | Project Test Runners | `application/json` | Get current runner availability for supported project test frameworks |
| `godot://project/dependency_snapshot` | Project Dependency Snapshot | `application/json` | Get a stable snapshot of parsed project resource dependencies |
| `godot://editor/logs` | Editor Logs | `application/json` | Get a bounded snapshot of recent MCP/editor log entries |
| `godot://runtime/state` | Runtime State | `application/json` | Get a bounded runtime-state snapshot or explicit no-session truth |
| `godot://editor/state` | Editor State | `application/json` | Current editor state and active tools |

### Vibe Coding / 免打扰模式

`vibe_coding_mode` 默认启用。该模式不会关闭 MCP 服务，但会阻止会抢占真人用户编辑器上下文的操作。

- 会切换场景、选择节点/文件或聚焦脚本编辑器的工具，需要本次调用传入 `allow_ui_focus=true`。
- 会打开或控制运行窗口的工具，需要本次调用传入 `allow_window=true`。
- 需要人工调试配合 MCP 时，可以在 MCP 面板关闭 `Vibe Coding / 免打扰模式`。

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
| `max_properties` | int | 否 | 最多返回多少个属性。省略或传 `0` 表示不限制 |
| `cursor` | int | 否 | 上一次截断结果的零基偏移，用于继续读取下一页 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `node_type` | string | 节点类型 |
| `properties` | Dictionary | 节点的所有属性键值对（已序列化） |
| `count` | int | 本次返回的属性数量 |
| `total_available` | int | 当前节点可用属性总数 |
| `truncated` | bool | 当 `max_properties` 导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续属性可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

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
| `max_items` | int | 否 | 最多返回多少个节点路径。省略或传 `0` 表示不限制 |
| `cursor` | int | 否 | 上一次截断结果的零基偏移，用于继续读取下一页 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `nodes` | Array[string] | 节点友好路径数组 |
| `count` | int | 节点数量 |
| `total_available` | int | 当前查询条件下可用的节点总数 |
| `truncated` | bool | 当 `max_items` 导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续节点可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 6. get_scene_tree

获取当前场景的完整节点树。传入较小的 `max_depth` 时，返回会显式标记是否发生截断，并给出继续获取更深层树的下一步深度提示。

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
| `truncated` | bool | 当 `max_depth` 限制导致返回不完整时为 `true` |
| `max_depth_applied` | int | 本次实际应用的 `max_depth` 值 |
| `next_max_depth` | int | 当结果被截断时，建议下一次请求尝试的更深层级 |

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
| `max_items` | int | 否 | 最多返回多少个组。省略或传 `0` 表示不限制 |
| `cursor` | int | 否 | 上一次截断结果的零基偏移，用于继续读取下一页 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `groups` | Array[string] | 组名列表 |
| `group_count` | int | 组数量 |
| `total_available` | int | 当前节点可用组总数 |
| `truncated` | bool | 当 `max_items` 导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续组可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

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
| `max_items` | int | 否 | 最多返回多少个匹配节点。省略或传 `0` 表示不限制 |
| `cursor` | int | 否 | 上一次截断结果的零基偏移，用于继续读取下一页 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `group` | string | 搜索的组名 |
| `nodes` | Array[Dictionary] | 节点信息数组 |
| `node_count` | int | 节点数量 |
| `total_available` | int | 当前组查询条件下可用节点总数 |
| `truncated` | bool | 当 `max_items` 导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续节点可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

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

### open_script_at_line

打开脚本并定位到指定行/列。默认会尝试在脚本编辑器中定位，但在 `vibe_coding_mode=true` 时不会抢占编辑器焦点，除非本次调用传入 `allow_ui_focus=true`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |
| `line` | int | 否 | 1-based 行号（默认 `1`） |
| `column` | int | 否 | 0-based 列号（默认 `0`） |
| `grab_focus` | boolean | 否 | 是否让编辑器获取焦点（默认 `true`）。免打扰模式下只有 `allow_ui_focus=true` 时才生效 |
| `allow_ui_focus` | boolean | 否 | 免打扰模式下允许本次调用聚焦脚本编辑器（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 打开的脚本路径 |
| `line` | int | 请求的 1-based 行号 |
| `column` | int | 请求的 0-based 列号 |
| `caret_line` | int | Godot 编辑器中的 0-based 光标行 |
| `caret_column` | int | Godot 编辑器中的 0-based 光标列 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

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
| `total_matches` | int | 本次返回的匹配数量 |
| `files_searched` | int | 搜索的文件数 |
| `truncated` | bool | 当 `max_results` 限制导致本次搜索结果不完整时为 `true` |
| `has_more` | bool | 是否还有更多匹配可通过增大 `max_results` 继续获取 |
| `max_results_applied` | int | 本次实际应用的 `max_results` |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

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

保存当前打开的场景，或一次性保存所有当前已打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `save_all_open_scenes` | boolean | 否 | 是否保存当前所有已打开场景，而不是只保存当前场景（默认 `false`） |
| `use_editor_save_as` | boolean | 否 | 是否用编辑器原生“另存为”语义把当前场景切换到 `file_path`（默认 `false`） |
| `file_path` | string | 否 | 保存路径。如不提供，保存到当前场景路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `saved_path` | string | 保存的场景路径 |
| `saved_scene_count` | integer | 本次保存的场景数量 |
| `saved_all_open_scenes` | boolean | 是否走了“保存所有已打开场景”分支 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**行为**：
- `save_all_open_scenes=true` 时调用编辑器的“保存所有已打开场景”语义，并要求不能同时传 `file_path`。
- `use_editor_save_as=true` 时要求提供 `file_path`，并调用编辑器原生 `save_scene_as()` 语义把当前场景切换到新的保存路径。
- 普通单场景保存分支仍沿用当前活动场景或显式 `file_path` 的保存行为。

---

### 28. open_scene

打开指定场景文件。会关闭当前打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |
| `reload_from_disk` | boolean | 否 | 是否对这个已打开场景执行从磁盘重载，而不是再次打开它（默认 `false`） |
| `set_inherited` | boolean | 否 | 是否以“新建继承场景”的方式打开该场景（默认 `false`） |
| `allow_ui_focus` | boolean | 否 | 免打扰模式下允许本次调用切换当前编辑器场景（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `scene_path` | string | 打开的源场景路径；当 `set_inherited=true` 时，当前编辑场景本身仍是未保存状态 |
| `root_node_type` | string | 根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

**行为**：
- `reload_from_disk=true` 时，要求该场景当前已经打开，并调用编辑器的“从磁盘重载”语义。
- `reload_from_disk` 与 `set_inherited` 不能同时为 `true`。

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

### close_scene_tab

关闭当前场景标签页，或先激活指定场景标签页再关闭。该操作会改变编辑器场景标签状态，在 `vibe_coding_mode=true` 时需要本次调用传入 `allow_ui_focus=true`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 否 | 要关闭的场景路径。如不提供，关闭当前活动场景 |
| `allow_ui_focus` | boolean | 否 | 免打扰模式下允许本次调用激活或关闭场景标签（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `closed_scene` | string | 被关闭的场景路径 |
| `remaining_count` | int | 关闭后仍打开的场景数量 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

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
| `allow_window` | boolean | 否 | 免打扰模式下允许本次调用打开运行窗口（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mode` | string | `"playing"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 34. stop_project

停止运行项目（Stop 按钮）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `allow_window` | boolean | 否 | 免打扰模式下允许本次调用控制运行窗口（默认 `false`） |

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

### select_node

在当前编辑场景中选择节点，并在 Inspector 中编辑该节点。该操作会改变编辑器选择和焦点，在 `vibe_coding_mode=true` 时需要本次调用传入 `allow_ui_focus=true`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径（如 `/root/MainScene/Player`） |
| `clear_existing` | boolean | 否 | 选择前是否清空现有选择（默认 `true`） |
| `allow_ui_focus` | boolean | 否 | 免打扰模式下允许本次调用改变编辑器选择/焦点（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 被选择节点的友好路径 |
| `node_type` | string | 节点类型 |
| `selected_count` | int | 选择后的节点数量 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### select_file

在 Godot FileSystem dock 中选择项目文件。该操作会改变编辑器文件选择，在 `vibe_coding_mode=true` 时需要本次调用传入 `allow_ui_focus=true`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `file_path` | string | 是 | 项目文件路径（如 `res://scenes/Main.tscn`） |
| `allow_ui_focus` | boolean | 否 | 免打扰模式下允许本次调用改变 FileSystem 选择（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `file_path` | string | 被选择的文件路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

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

截取编辑器视口截图并保存到文件。传入 `scene_path` 时，不再依赖当前活动编辑器视口，而是通过 generated-scene helper 离屏渲染指定场景并输出截图。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 否 | 指定要离屏截图的场景路径；提供后会走 generated-scene helper，而不是实时编辑器视口。 |
| `viewport_type` | string | 否 | 实时编辑器视口类型：`3d` 或 `2d`（默认 `3d`）。提供 `scene_path` 时忽略。 |
| `viewport_index` | int | 否 | 3D 实时编辑器视口索引 0-3（默认 `0`）。提供 `scene_path` 时忽略。 |
| `save_path` | string | 否 | 截图保存路径（默认 `res://screenshot_editor.png`） |
| `format` | string | 否 | 图片格式：`png` 或 `jpg`（默认 `png`） |
| `viewport_width` | int | 否 | 离屏截图宽度；仅在提供 `scene_path` 时使用（默认 `256`）。 |
| `viewport_height` | int | 否 | 离屏截图高度；仅在提供 `scene_path` 时使用（默认 `256`）。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `save_path` | string | 截图保存路径 |
| `size` | string | 图片尺寸（如 `1920x1080`） |
| `width` | int | 截图宽度 |
| `height` | int | 截图高度 |
| `scene_path` | string | 离屏截图时回显输入的场景路径 |
| `render_mode` | string | 离屏截图时返回 `2d` 或 `3d`，表示 helper 采用的渲染模式 |

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
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续日志可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |
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
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续消息可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

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

### 58. get_runtime_info

通过运行时探针查询正在运行的游戏实例，返回运行时指标。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `fps` | number | 当前帧率 |
| `physics_frames` | int | 物理帧计数 |
| `process_frames` | int | 处理帧计数 |
| `debugger_active` | boolean | 调试器是否连接 |
| `current_scene` | string | 当前场景路径 |
| `node_count` | int | 场景节点总数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 59. get_runtime_scene_tree

从运行中的游戏实例读取实时场景树。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大遍历深度，默认 `6` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：运行时场景树根节点结构，包含 name、type、path、child_count、children。

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 60. inspect_runtime_node

通过运行时探针检查运行时节点及其序列化属性。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 运行时节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：节点信息，包括 name、type、path 和可序列化的 properties。

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 61. update_runtime_node_property

通过运行时探针修改运行时节点上的属性。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 运行时节点路径 |
| `property_name` | string | 是 | 属性名称 |
| `property_value` | variant | 是 | 属性值（支持自动类型转换） |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `property_name` | string | 属性名称 |
| `old_value` | variant | 修改前的值 |
| `new_value` | variant | 修改后的值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 62. call_runtime_node_method

在运行时节点上调用方法并返回序列化后的结果。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 运行时节点路径 |
| `method_name` | string | 是 | 方法名称 |
| `arguments` | Array | 否 | 方法参数数组 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `method_name` | string | 方法名称 |
| `arguments` | Array | 传入的参数 |
| `result` | variant | 方法返回结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 63. evaluate_runtime_expression

在运行中的游戏实例中计算 GDScript 表达式，可选相对目标节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `expression` | string | 是 | GDScript 表达式 |
| `node_path` | string | 否 | 目标节点路径（作为表达式基座） |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `expression` | string | 原始表达式 |
| `node_path` | string | 目标节点路径 |
| `value` | variant | 表达式计算结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 64. await_runtime_condition

轮询运行时表达式直到其为真或超时。适用于等待游戏状态变化。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `expression` | string | 是 | GDScript 表达式 |
| `node_path` | string | 否 | 目标节点路径 |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `3000` |
| `poll_interval_ms` | int | 否 | 轮询间隔（毫秒），默认 `100` |
| `session_id` | int | 否 | 目标调试会话 ID |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `condition_met` | boolean | 条件是否已满足 |
| `attempts` | int | 轮询次数 |
| `elapsed_ms` | int | 总轮询耗时（毫秒） |
| `last_value` | variant | 最后一次表达式值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 65. assert_runtime_condition

断言运行时表达式在超时窗口内变为真。相当于带断言的 `await_runtime_condition`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `expression` | string | 是 | GDScript 表达式 |
| `node_path` | string | 否 | 目标节点路径 |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `3000` |
| `poll_interval_ms` | int | 否 | 轮询间隔（毫秒），默认 `100` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `description` | string | 否 | 断言描述 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"failed"` |
| `description` | string | 断言描述 |
| `attempts` | int | 轮询次数 |
| `elapsed_ms` | int | 总耗时（毫秒） |
| `last_value` | variant | 最后一次表达式值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

## Project Tools

### 66. get_project_info

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

### 67. get_project_settings

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

### 68. list_project_resources

列出项目中的所有资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径。默认 `res://` |
| `resource_types` | Array[string] | 否 | 文件扩展名过滤（如 `[".tres", ".png"]`）。不提供则返回所有常见资源类型 |
| `include_resource_details` | boolean | 否 | 是否为每个结果额外加载资源并返回有界属性摘要。默认 `false` |
| `include_property_values` | boolean | 否 | 当 `include_resource_details=true` 时，是否序列化属性值。默认 `false` |
| `property_filter` | string | 否 | 当 `include_resource_details=true` 时，对属性名做不区分大小写的子串过滤 |
| `max_properties` | int | 否 | 每个资源最多返回多少个匹配属性。默认 `40` |

**默认搜索的扩展名**：`.tres`, `.res`, `.png`, `.jpg`, `.webp`, `.ogg`, `.wav`, `.mp3`, `.obj`, `.glb`, `.gltf`, `.material`, `.shader`, `.gdshader`, `.tscn`, `.gd`, `.cfg`, `.json`, `.ttf`, `.otf` 等

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resources` | Array[string] | 资源文件路径数组 |
| `count` | int | 资源数量 |
| `details_included` | boolean | 是否包含 `resource_details` 明细 |
| `include_property_values` | boolean | 本次明细是否包含属性值 |
| `property_filter_applied` | string | 实际应用的属性过滤器 |
| `max_properties_applied` | int | 每个资源明细应用的属性返回上限 |
| `resource_details` | array | 可选资源明细数组；每项包含 `resource_path`、`is_loadable`、`class_name`、`script_path`、`property_count`、`returned_property_count`、`properties`、`properties_truncated`、`has_more_properties`，以及截断时的 `next_max_properties` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 69. create_resource

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

### 70. get_project_structure

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

## Node-Advanced（补充工具）

这些工具扩展了节点管理功能，支持批量操作和场景审计。需在工具管理面板中启用 `Node-Advanced` 分组后使用。

### 71. batch_update_node_properties

在一个 UndoRedo 动作中批量更新多个节点属性。适用于需要一步撤销的场景事务式编辑。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `label` | string | 否 | UndoRedo 动作标签（默认 `"Batch Update Node Properties"`） |
| `changes` | array | 是 | 属性更新列表，每项包含 `node_path`、`property_name`、`property_value` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `label` | string | UndoRedo 标签 |
| `change_count` | int | 更新的属性数量 |
| `changes` | array | 每项更新的结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 72. batch_scene_node_edits

在一个 UndoRedo 动作中批量执行创建/删除场景节点编辑，使完整的结构变更可一步撤销。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `label` | string | 否 | UndoRedo 动作标签 |
| `operations` | array | 是 | 有序的创建/删除操作列表，每项需指定 `type`（`create`/`delete`/`move`）及相关参数 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `label` | string | UndoRedo 标签 |
| `operation_count` | int | 操作数量 |
| `operations` | array | 每项操作的结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 73. audit_scene_node_persistence

审计当前编辑场景的节点 owner 和持久化状态。报告影响场景保存和继承的缺失或无效 owner 关系。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_path` | string | 场景文件路径 |
| `scene_root_path` | string | 场景根节点路径 |
| `total_nodes` | int | 节点总数 |
| `persistent_node_count` | int | 可持久化的节点数 |
| `issue_count` | int | 问题数量 |
| `nodes` | array | 节点详细信息 |
| `issues` | array | 发现的问题列表 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 74. audit_scene_inheritance

审计当前场景的继承/实例化结构。分类本地节点、实例根节点、继承实例内容和实例化子树中的本地新增。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_path` | string | 场景文件路径 |
| `scene_root_path` | string | 场景根节点路径 |
| `node_count` | int | 节点总数 |
| `instance_root_count` | int | 实例根节点数 |
| `issue_count` | int | 问题数量 |
| `instance_roots` | array | 实例根节点信息 |
| `nodes` | array | 节点详细信息 |
| `issues` | array | 发现的问题列表 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

## Script-Advanced（补充工具）

这些工具扩展了脚本管理功能，支持符号索引、定义查找和引用搜索。需在工具管理面板中启用 `Script-Advanced` 分组后使用。

### 75. list_project_script_symbols

索引项目 GDScript 和 C# 文件中的脚本符号。返回类、继承、函数、信号、属性和常量。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径，默认 `res://` |
| `include_extensions` | array | 否 | 脚本文件扩展名，默认 `[".gd", ".cs"]` |
| `symbol_kinds` | array | 否 | 符号种类过滤：`function`、`signal`、`property`、`constant` |
| `name_filter` | string | 否 | 符号名称的大小写不敏感子串过滤 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scripts` | array | 脚本符号信息数组 |
| `count` | int | 脚本数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 76. find_script_symbol_definition

跨项目 GDScript 和 C# 文件查找脚本符号的定义位置。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `symbol_name` | string | 是 | 要查找的符号名称 |
| `search_path` | string | 否 | 搜索子路径，默认 `res://` |
| `include_extensions` | array | 否 | 脚本文件扩展名，默认 `[".gd", ".cs"]` |
| `symbol_kinds` | array | 否 | 符号种类过滤：`class`、`function`、`signal`、`property`、`constant` |
| `preferred_script_path` | string | 否 | 优先排名靠前的脚本路径 |
| `max_results` | int | 否 | 最大返回定义数，默认 `20` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `symbol_name` | string | 搜索的符号名称 |
| `definitions` | array | 定义位置数组 |
| `count` | int | 定义数量 |
| `truncated` | bool | 当 `max_results` 限制导致本次定义结果不完整时为 `true` |
| `has_more` | bool | 是否还有更多定义可通过增大 `max_results` 继续获取 |
| `max_results_applied` | int | 本次实际应用的 `max_results` |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 77. find_script_symbol_references

跨 GDScript、C# 和场景文件查找脚本符号的文本引用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `symbol_name` | string | 是 | 要搜索的符号名称 |
| `search_path` | string | 否 | 搜索子路径，默认 `res://` |
| `include_extensions` | array | 否 | 文件扩展名，默认 `[".gd", ".cs", ".tscn"]` |
| `include_definitions` | boolean | 否 | 是否包含定义行，默认 `false` |
| `case_sensitive` | boolean | 否 | 是否区分大小写，默认 `true` |
| `preferred_script_path` | string | 否 | 优先排名靠前的脚本路径 |
| `max_results` | int | 否 | 最大返回引用数，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `symbol_name` | string | 搜索的符号名称 |
| `references` | array | 引用位置数组 |
| `count` | int | 引用数量 |
| `truncated` | bool | 当 `max_results` 限制导致本次引用结果不完整时为 `true` |
| `has_more` | bool | 是否还有更多引用可通过增大 `max_results` 继续获取 |
| `max_results_applied` | int | 本次实际应用的 `max_results` |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 78. rename_script_symbol

跨项目文件使用标识符边界文本替换重命名脚本符号。支持 dry-run 预览。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `symbol_name` | string | 是 | 现有符号名称 |
| `new_name` | string | 是 | 新符号名称 |
| `search_path` | string | 否 | 搜索子路径，默认 `res://` |
| `include_extensions` | array | 否 | 文件扩展名，默认 `[".gd", ".cs"]` |
| `case_sensitive` | boolean | 否 | 是否区分大小写，默认 `true` |
| `dry_run` | boolean | 否 | 预览模式不修改文件，默认 `true` |
| `max_results` | int | 否 | 最大替换匹配数，默认 `200` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `symbol_name` | string | 原始符号名称 |
| `new_name` | string | 新符号名称 |
| `dry_run` | boolean | 是否为预览模式 |
| `changed_files` | array | 修改的文件列表 |
| `replacement_count` | int | 替换数量 |
| `truncated` | bool | 当 `max_results` 限制导致本次替换预览或应用不完整时为 `true` |
| `has_more` | bool | 是否还有更多替换可通过增大 `max_results` 继续获取或应用 |
| `max_results_applied` | int | 本次实际应用的 `max_results` |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 79. open_script_at_line

在 Godot 脚本编辑器中打开脚本文件并将光标移动到指定行和列。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `line` | int | 否 | 1-based 行号，默认 `1` |
| `column` | int | 否 | 0-based 列号，默认 `0` |
| `grab_focus` | boolean | 否 | 是否获取焦点，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 脚本路径 |
| `line` | int | 打开的行号 |
| `column` | int | 打开的列号 |
| `caret_line` | int | 实际光标行号 |
| `caret_column` | int | 实际光标列号 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

## Scene-Advanced（补充工具）

这些工具扩展了场景管理功能，支持列出和关闭场景标签页。需在工具管理面板中启用 `Scene-Advanced` 分组后使用。

### 80. list_open_scenes

列出 Godot 编辑器中当前打开的场景标签页。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `active_scene` | string | 当前活动场景路径 |
| `open_scenes` | array | 所有打开的场景路径 |
| `count` | int | 打开的场景数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 81. close_scene_tab

关闭当前活动场景标签页，或关闭指定路径的场景标签页。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 否 | 要关闭的场景路径。不提供则关闭当前活动场景 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `closed_scene` | string | 已关闭的场景路径 |
| `remaining_count` | int | 剩余打开的场景数 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

## Editor-Advanced（补充工具）

这些工具扩展了编辑器操作功能，支持节点/文件选择、属性检查、导出管理。需在工具管理面板中启用 `Editor-Advanced` 分组后使用。

### 82. select_node

在当前编辑的场景中选择一个节点并在检查器中聚焦显示。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径（如 `/root/MainScene/Player`） |
| `clear_existing` | boolean | 否 | 是否清除现有选择，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 选择的节点路径 |
| `node_type` | string | 节点类型 |
| `selected_count` | int | 选中节点数量 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 83. select_file

在 Godot 文件系统停靠面板中选择一个项目文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `file_path` | string | 是 | 项目文件路径（如 `res://scenes/Main.tscn`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `file_path` | string | 选择的文件路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 84. get_file_system_navigation

???? Godot FileSystem dock ???????????????????????????

**??**?
| ?? | ?? | ?? | ?? |
|------|------|------|------|
| ? | - | - | ???? |

**???**?
| ?? | ?? | ?? |
|------|------|------|
| `current_path` | string | FileSystem dock ??????? |
| `current_directory` | string | FileSystem dock ????????????????????????? |
| `selected_paths` | array | ??? FileSystem dock ????????????? |
| `selected_count` | int | ???????? |

**??**?`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 85. get_inspector_properties

检查节点或资源并返回类似检查器的属性元数据和序列化值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 否 | 节点路径（与 `resource_path` 二选一） |
| `resource_path` | string | 否 | 资源路径（与 `node_path` 二选一） |
| `property_filter` | string | 否 | 属性名称子串过滤 |
| `include_values` | boolean | 否 | 是否包含属性值，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `target_kind` | string | 目标类型：`node` 或 `resource` |
| `target_path` | string | 目标路径 |
| `class_name` | string | 类名 |
| `property_count` | int | 属性数量 |
| `properties` | array | 属性信息数组 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 86. list_export_presets

从 `export_presets.cfg` 列出导出预设。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `config_path` | string | 配置文件路径 |
| `presets` | array | 导出预设数组 |
| `count` | int | 预设数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 87. inspect_export_templates

检查本地已安装的 Godot 导出模板。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `templates_root` | string | 模板根目录 |
| `current_version` | string | 当前编辑器版本 |
| `matching_version_installed` | boolean | 是否已安装匹配的模板版本 |
| `installed_versions` | array | 已安装的版本列表 |
| `detected_files` | array | 检测到的模板文件 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 88. validate_export_preset

根据 `export_presets.cfg` 和本地模板可用性验证导出预设。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `preset` | string | 是 | 预设名称或节名（如 `"Windows Desktop"` 或 `"preset.0"`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `valid` | boolean | 预设是否有效 |
| `preset` | object | 预设详情 |
| `errors` | array | 错误列表 |
| `warnings` | array | 警告列表 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 89. run_export

运行 Godot CLI 导出指定预设。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `preset` | string | 是 | 预设名称或节名 |
| `output_path` | string | 否 | 输出路径覆盖 |
| `mode` | string | 否 | 导出模式：`release`、`debug`、`pack`、`patch`（默认 `release`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `success` | boolean | 导出是否成功 |
| `exit_code` | int | Godot CLI 退出码 |
| `command` | array | 执行的命令 |
| `output_path` | string | 输出文件路径 |
| `logs` | array | 日志输出 |
| `errors` | array | 错误输出 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

## Debug-Advanced（补充工具）

这些工具扩展了调试功能，包括调试器线程/变量操作、执行控制、运行时场景管理、动画/音频/着色器等运行时操作。需在工具管理面板中启用 `Debug-Advanced` 分组后使用。

### 90. get_debug_threads

返回活动 Godot 调试会话中的 DAP 样式调试器线程。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `threads` | array | 线程信息数组 |
| `count` | int | 线程数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 91. get_debug_state_events

从 bridge 读取记录的调试器断点/恢复/停止状态转换记录。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `count` | int | 否 | 最大返回条数，默认 `100` |
| `offset` | int | 否 | 跳过条数，默认 `0` |
| `order` | string | 否 | `desc`（最新优先）或 `asc`，默认 `desc` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `events` | array | 状态事件数组 |
| `count` | int | 返回数量 |
| `total_available` | int | 可用事件总数 |
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续事件可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 92. get_debug_output

读取编辑器 bridge 捕获的分类运行时调试器输出。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `count` | int | 否 | 最大返回条数，默认 `100` |
| `offset` | int | 否 | 跳过条数，默认 `0` |
| `order` | string | 否 | `desc` 或 `asc`，默认 `desc` |
| `category` | string | 否 | 分类过滤：`""`（全部）、`stdout`、`stderr`、`stdout_rich` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `events` | array | 输出事件数组 |
| `count` | int | 返回数量 |
| `total_available` | int | 可用事件总数 |
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续事件可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 93. get_debug_scopes

将捕获的栈变量分组为 DAP 风格的 scope（局部/成员/全局/常量）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `frame` | int | 否 | 栈帧索引，默认 `0` |
| `refresh` | boolean | 否 | 是否先请求刷新，默认 `true` |
| `session_id` | int | 否 | 目标调试会话 ID，`-1` 表示全部 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `frame` | int | 栈帧索引 |
| `scopes` | array | scope 数组 |
| `count` | int | scope 数量 |
| `refresh_result` | object | 刷新请求结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 94. get_debug_variables

通过 DAP 风格 `variablesReference` 解析子变量，支持大型数组和字典的分页。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `variables_reference` | int | 是 | 变量引用 ID |
| `offset` | int | 否 | 偏移量，默认 `0` |
| `count` | int | 否 | 最大返回数，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `variables_reference` | int | 变量引用 ID |
| `variables` | array | 变量数组 |
| `count` | int | 返回数量 |
| `total_available` | int | 可用变量总数 |
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续变量可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 95. expand_debug_variable

通过 scope 和路径展开捕获的调试变量或评估表达式值，支持数组和字典分页。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `frame` | int | 否 | 栈帧索引，默认 `0` |
| `scope` | string | 是 | scope 名称：`local`、`member`、`global`、`constant`、`evaluation` |
| `variable_path` | array | 是 | 路径片段，从顶层变量名开始 |
| `offset` | int | 否 | 偏移量，默认 `0` |
| `count` | int | 否 | 最大返回数，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `frame` | int | 栈帧索引 |
| `scope` | string | scope 名称 |
| `variable_path` | array | 展开路径 |
| `entries` | array | 子项数组 |
| `count` | int | 返回数量 |
| `total_available` | int | 可用项总数 |
| `truncated` | bool | 当 `count` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有后续子项可通过 continuation 继续获取 |
| `next_cursor` | int | 当 `has_more=true` 时，下一次请求应传入的 continuation 偏移 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 96. evaluate_debug_expression

在暂停的脚本调试器上下文中为指定帧评估表达式。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `expression` | string | 是 | GDScript 表达式 |
| `frame` | int | 否 | 栈帧索引，默认 `0` |
| `session_id` | int | 否 | 目标调试会话 ID |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"pending"` |
| `expression` | string | 原始表达式 |
| `frame` | int | 栈帧索引 |
| `type` | string | 结果类型 |
| `value` | variant | 计算结果 |
| `has_children` | boolean | 是否有子变量 |
| `refresh_result` | object | 刷新请求结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 97. debug_step_into

Step Into：进入下一行语句。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话 ID，`-1` 表示全部 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"`、`"no_active_sessions"` 或错误 |
| `sessions_updated` | int | 更新的会话数 |
| `command` | string | 执行的命令 |
| `target_state` | string | 目标状态：`breaked` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 98. debug_step_over

Step Over：跳过下一行语句。

**参数**：同 `debug_step_into`（仅 `session_id`）

**返回值**：同 `debug_step_into`

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 99. debug_step_out

Step Out：跳出当前函数帧。

**参数**：同 `debug_step_into`

**返回值**：同 `debug_step_into`

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 100. debug_continue

Continue：恢复执行。

**参数**：同 `debug_step_into`

**返回值**：同 `debug_step_into`

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 101. debug_step_into_and_wait

发送 step-into 命令并等待调试器报告暂停状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间（毫秒），默认 `3000` |
| `poll_interval_ms` | int | 否 | 轮询间隔，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"matched"`、`"timeout"` 或错误 |
| `command` | string | 执行的命令 |
| `target_state` | string | 目标状态 |
| `matched_state` | object | 匹配到的状态 |
| `sessions` | array | 会话状态 |
| `state_events` | array | 状态事件记录 |
| `attempts` | int | 轮询次数 |
| `elapsed_ms` | int | 总耗时（毫秒） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 102. debug_step_over_and_wait

发送 step-over 命令并等待调试器报告暂停状态。参数和返回值同 `debug_step_into_and_wait`。

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 103. debug_step_out_and_wait

发送 step-out 命令并等待调试器报告暂停状态。参数和返回值同 `debug_step_into_and_wait`。

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 104. debug_continue_and_wait

发送 continue 命令并等待调试器报告运行状态。参数和返回值同 `debug_step_into_and_wait`。

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 105. await_debugger_state

使用最新的 bridge 快照检查调试器会话是否达到目标执行状态。客户端在 continue/step 操作后重复调用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `target_state` | string | 否 | 目标状态：`breaked`、`running`、`stopped`，默认 `breaked` |
| `session_id` | int | 否 | 会话 ID，`-1` 表示任意 |
| `timeout_ms` | int | 否 | 超时时间，默认 `3000` |
| `poll_interval_ms` | int | 否 | 轮询间隔，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"matched"`、`"timeout"` 或 `"no_sessions"` |
| `target_state` | string | 目标状态 |
| `matched_state` | object | 匹配到的状态 |
| `sessions` | array | 会话列表 |
| `state_events` | array | 状态事件记录 |
| `attempts` | int | 轮询次数 |
| `elapsed_ms` | int | 总耗时（毫秒） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 106. get_runtime_performance_snapshot

从运行中的游戏实例捕获运行时性能快照，包括帧时间、对象计数和内存使用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `fps` | number | 当前帧率 |
| `frame_time_sec` | number | 帧耗时 |
| `physics_frame_time_sec` | number | 物理帧耗时 |
| `object_count` | int | 对象总数 |
| `resource_count` | int | 资源总数 |
| `rendered_objects_in_frame` | int | 帧内渲染对象数 |
| `memory_static_bytes` | int | 静态内存（字节） |
| `memory_static_mb` | number | 静态内存（MB） |
| `current_scene` | string | 当前场景路径 |
| `node_count` | int | 节点总数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 107. get_runtime_memory_trend

从运行中的游戏捕获短时内存和对象计数趋势（多次采样）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `sample_count` | int | 否 | 采样次数，默认 `5` |
| `sample_interval_ms` | int | 否 | 采样间隔，默认 `100` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `3000` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `sample_count` | int | 采样次数 |
| `sample_interval_ms` | int | 采样间隔 |
| `memory_static_delta_bytes` | int | 内存变化（字节） |
| `object_count_delta` | int | 对象数变化 |
| `resource_count_delta` | int | 资源数变化 |
| `current_scene` | string | 当前场景路径 |
| `samples` | array | 采样数据数组 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 108. create_runtime_node

在运行中游戏的父节点下创建新节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 是 | 父节点路径 |
| `node_type` | string | 是 | 节点类型（如 `Node2D`、`Sprite2D`） |
| `node_name` | string | 是 | 新节点名称 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `parent_path` | string | 父节点路径 |
| `node_path` | string | 新节点路径 |
| `node_type` | string | 节点类型 |
| `node_name` | string | 节点名称 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 109. delete_runtime_node

删除运行中的游戏节点。运行时场景根节点和 MCPRuntimeProbe 节点受保护。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要删除的节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 已删除节点路径 |
| `node_type` | string | 节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=true`

---

### 110. simulate_runtime_input_event

通过 `Input.parse_input_event()` 向运行中的游戏注入结构化 InputEvent。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `event` | object | 是 | 结构化输入事件，支持类型：`action`、`key`、`mouse_button`、`mouse_motion` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `type` | string | 事件类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 111. simulate_runtime_input_action

通过 `Input.parse_input_event()` 向运行中的游戏注入 InputEventAction。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 动作名称 |
| `pressed` | boolean | 否 | 是否按下，默认 `true` |
| `strength` | number | 否 | 强度值，默认 `1.0` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 动作名称 |
| `action_exists` | boolean | 动作是否存在于 InputMap |
| `pressed` | boolean | 按下状态 |
| `strength` | number | 强度值 |
| `runtime_pressed` | boolean | 运行时的实际 pressed 状态 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 112. list_runtime_input_actions

列出运行中的游戏可用的 InputMap 动作，包含序列化的输入事件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 否 | 精确动作名称过滤 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `actions` | array | 动作数组 |
| `count` | int | 动作数量 |
| `filter` | string | 过滤条件 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 113. upsert_runtime_input_action

在运行中的游戏创建或更新 InputMap 动作。支持替换现有事件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 动作名称 |
| `deadzone` | number | 否 | 死区值，默认 `0.5` |
| `erase_existing` | boolean | 否 | 是否清除现有事件，默认 `false` |
| `events` | array | 否 | 要添加的结构化输入事件 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 动作名称 |
| `existed_before` | boolean | 之前是否存在 |
| `deadzone` | number | 死区值 |
| `event_count` | int | 事件总数 |
| `events` | array | 当前事件列表 |
| `added_events` | array | 新添加的事件 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 114. remove_runtime_input_action

从运行中的游戏移除 InputMap 动作。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 动作名称 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 动作名称 |
| `removed` | boolean | 是否已移除 |
| `event_count` | int | 移除前的事件数 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=true`

---

### 115. list_runtime_animations

列出运行时 AnimationPlayer 节点上的可用动画。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `animations` | array | 动画名称列表 |
| `count` | int | 动画数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 116. play_runtime_animation

播放运行时 AnimationPlayer 节点上的动画。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `animation_name` | string | 是 | 动画名称 |
| `custom_blend` | number | 否 | 自定义混合时间，`-1.0` 表示默认 |
| `custom_speed` | number | 否 | 播放速度倍率，默认 `1.0` |
| `from_end` | boolean | 否 | 是否从末尾开始，默认 `false` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `current_animation` | string | 当前动画名称 |
| `is_playing` | boolean | 是否正在播放 |
| `current_position` | number | 当前播放位置 |
| `current_length` | number | 动画总长度 |
| `speed_scale` | number | 速度缩放 |
| `playing_speed` | number | 实际播放速度 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 117. stop_runtime_animation

停止运行时 AnimationPlayer 节点的播放。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `keep_state` | boolean | 否 | 是否保持当前状态，默认 `false` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `current_animation` | string | 当前动画名称 |
| `is_playing` | boolean | 是否停止播放 |
| `current_position` | number | 停止时的位置 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 118. get_runtime_animation_state

返回运行时 AnimationPlayer 节点的当前播放状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：同 `play_runtime_animation` 的返回值（不含 `playing_speed`）

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 119. get_runtime_animation_tree_state

返回运行时 AnimationTree 节点的当前状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `active` | boolean | 是否激活 |
| `anim_player` | string | 关联的 AnimationPlayer 路径 |
| `tree_root_type` | string | 树根节点类型 |
| `has_playback` | boolean | 是否有 playback 对象 |
| `current_node` | string | 当前状态机节点 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 120. set_runtime_animation_tree_active

启用或禁用运行时 AnimationTree 节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `active` | boolean | 是 | 是否激活 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `active` | boolean | 当前激活状态 |
| `tree_root_type` | string | 树根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 121. travel_runtime_animation_tree

将运行时 AnimationTree 状态机播放转移到目标节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `state_name` | string | 是 | 目标状态节点名称 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `current_node` | string | 当前状态节点 |
| `travel_path` | array | 转移路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 122. get_runtime_material_state

解析运行时节点的材质绑定并返回材质元数据。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `material_target` | string | 否 | 材质目标：`auto`、`material`、`material_override`、`surface_override`，默认 `auto` |
| `surface_index` | int | 否 | 表面索引，默认 `0` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `material_class` | string | 材质类名 |
| `material_target` | string | 材质目标 |
| `is_shader_material` | boolean | 是否为 ShaderMaterial |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 123. get_runtime_theme_item

解析一个运行时 Control 主题项并报告其当前值和覆盖状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `item_type` | string | 是 | 类型：`color`、`constant`、`font`、`font_size`、`stylebox`、`icon` |
| `item_name` | string | 是 | 主题项名称 |
| `theme_type` | string | 否 | 主题类型 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `item_type` | string | 项类型 |
| `item_name` | string | 项名称 |
| `has_override` | boolean | 是否有覆盖 |
| `has_item` | boolean | 是否存在该项 |
| `value` | variant | 当前值 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 124. set_runtime_theme_override

应用一个运行时 Control 主题覆盖（color/constant/font/font_size/stylebox/icon）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `item_type` | string | 是 | 项类型 |
| `item_name` | string | 是 | 项名称 |
| `value` | variant | 是 | 覆盖值 |
| `theme_type` | string | 否 | 主题类型 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `item_type` | string | 项类型 |
| `item_name` | string | 项名称 |
| `has_override` | boolean | 是否有覆盖 |
| `value` | variant | 当前值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 125. clear_runtime_theme_override

移除一个运行时 Control 主题覆盖并返回清除后的值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `item_type` | string | 是 | 项类型 |
| `item_name` | string | 是 | 项名称 |
| `theme_type` | string | 否 | 主题类型 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `item_type` | string | 项类型 |
| `item_name` | string | 项名称 |
| `has_override` | boolean | 是否仍有覆盖 |
| `value` | variant | 清除后的值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 126. get_runtime_shader_parameters

列出运行时 ShaderMaterial 绑定的着色器 uniform 和当前值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `material_target` | string | 否 | 材质目标，默认 `auto` |
| `surface_index` | int | 否 | 表面索引，默认 `0` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `parameters` | array | 着色器参数数组 |
| `count` | int | 参数数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 127. set_runtime_shader_parameter

更新运行时 ShaderMaterial 绑定的一个着色器 uniform。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `parameter_name` | string | 是 | 参数名称 |
| `value` | variant | 是 | 新值 |
| `material_target` | string | 否 | 材质目标，默认 `auto` |
| `surface_index` | int | 否 | 表面索引，默认 `0` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `parameter_name` | string | 参数名称 |
| `old_value` | variant | 旧值 |
| `new_value` | variant | 新值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 128. list_runtime_tilemap_layers

列出运行时 TileMap 节点的层和使用中的 tile 计数。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `layers` | array | 层信息数组 |
| `count` | int | 层数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 129. get_runtime_tilemap_cell

返回指定 TileMap 层坐标处的运行时单元格数据。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `layer` | int | 是 | 层索引 |
| `coords` | object | 是 | 坐标 `{"x": int, "y": int}` |
| `use_proxies` | boolean | 否 | 是否使用代理 tile，默认 `false` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `layer` | int | 层索引 |
| `coords` | object | 坐标 |
| `source_id` | int | 源 ID |
| `atlas_coords` | object | 图集坐标 |
| `alternative_tile` | int | 替代 tile ID |
| `is_empty` | boolean | 是否为空 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 130. set_runtime_tilemap_cell

写入或擦除指定 TileMap 层坐标处的运行时单元格。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `layer` | int | 是 | 层索引 |
| `coords` | object | 是 | 坐标 |
| `source_id` | int | 否 | 源 ID |
| `atlas_coords` | object | 否 | 图集坐标 |
| `alternative_tile` | int | 否 | 替代 tile ID，默认 `0` |
| `erase` | boolean | 否 | 是否擦除，默认 `false` |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `layer` | int | 层索引 |
| `coords` | object | 坐标 |
| `source_id` | int | 源 ID |
| `atlas_coords` | object | 图集坐标 |
| `alternative_tile` | int | 替代 tile ID |
| `is_empty` | boolean | 是否为空 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 131. list_runtime_audio_buses

列出运行中的游戏可用的 AudioServer 总线。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `buses` | array | 总线信息数组 |
| `count` | int | 总线数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 132. get_runtime_audio_bus

返回运行中的游戏内一个 AudioServer 总线的当前状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `bus_name` | string | 是 | 总线名称 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `index` | int | 总线索引 |
| `name` | string | 总线名称 |
| `volume_db` | number | 音量（dB） |
| `mute` | boolean | 是否静音 |
| `solo` | boolean | 是否独奏 |
| `bypass_effects` | boolean | 是否旁路效果 |
| `send` | string | 发送目标 |
| `effect_count` | int | 效果器数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=true`

---

### 133. update_runtime_audio_bus

更新运行中的游戏内一个 AudioServer 总线的 mute 和/或 volume_db。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `bus_name` | string | 是 | 总线名称 |
| `volume_db` | number | 否 | 音量（dB） |
| `mute` | boolean | 否 | 是否静音 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `index` | int | 总线索引 |
| `name` | string | 总线名称 |
| `volume_db` | number | 音量（dB） |
| `mute` | boolean | 是否静音 |
| `solo` | boolean | 是否独奏 |
| `bypass_effects` | boolean | 是否旁路效果 |
| `send` | string | 发送目标 |
| `effect_count` | int | 效果器数量 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

### 134. get_runtime_screenshot

从运行中的游戏捕获当前运行时视口（或指定 Viewport/SubViewport）截图并保存到文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `save_path` | string | 否 | 输出路径，必须使用 `res://` 或 `user://`，默认 `user://mcp_runtime_capture.png` |
| `format` | string | 否 | 图片格式：`png` 或 `jpg`，默认 `png` |
| `viewport_path` | string | 否 | 可选的运行时视口节点路径 |
| `session_id` | int | 否 | 目标调试会话 ID |
| `timeout_ms` | int | 否 | 超时时间，默认 `1500` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `save_path` | string | 保存路径 |
| `format` | string | 图片格式 |
| `viewport_path` | string | 视口路径 |
| `width` | int | 图片宽度 |
| `height` | int | 图片高度 |
| `size` | string | 图片尺寸描述 |
| `current_scene` | string | 当前场景路径 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=true`

---

## Project-Advanced（补充工具）

这些工具扩展了项目配置管理功能，包括测试运行、输入映射管理、自动加载/全局类查询、资源诊断。需在工具管理面板中启用 `Project-Advanced` 分组后使用。

### 135. list_project_tests

发现 Godot 项目测试目录下的可运行测试。报告 Python 集成测试和 GUT 单元测试，包括每个测试当前是否可运行。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径 |
| `framework` | string | 否 | 框架过滤：`python` 或 `gut` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `tests` | array | 测试信息数组 |
| `count` | int | 测试数量 |
| `search_path` | string | 搜索路径 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 136. inspect_project_test

Inspect a single project test entry and return the same normalized metadata shape used by `list_project_tests`.

**Parameters**:
| Parameter | Type | Required | Description |
|------|------|------|------|
| `test_path` | string | Yes | `res://` path to one project test file |

**Returns**:
| Field | Type | Description |
|------|------|------|
| `test_path` | string | Test file path |
| `exists` | boolean | Whether the requested test entry currently exists |
| `framework` | string | Test framework: `python` or `gut`; omitted when missing |
| `kind` | string | Test kind: `integration` or `unit`; omitted when missing |
| `runnable` | boolean | Whether the test is runnable right now; omitted when missing |
| `available_runner` | boolean | Whether a runner is available in the current environment; omitted when missing |
| `name` | string | Test filename; omitted when missing |

**Annotations**: `readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 137. list_project_test_runners

Inspect the currently available project test runners for supported frameworks without executing project tests.

**Parameters**:
| Parameter | Type | Required | Description |
|------|------|------|------|
| None | - | - | No parameters. |

**Returns**:
| Field | Type | Description |
|------|------|------|
| `count` | integer | Number of supported framework runner entries |
| `runners` | array | Runner availability entries |

Each runner entry includes:
| Field | Type | Description |
|------|------|------|
| `framework` | string | Supported framework name: `python` or `gut` |
| `kind` | string | Associated test kind: `integration` or `unit` |
| `available` | boolean | Whether the runner is currently available |
| `reason` | string | Short truthful explanation for the availability result |
| `command` | array | Command shape used to probe or invoke the runner |
| `probe_exit_code` | integer | Exit code from the Python availability probe; python only |
| `runner_path` | string | Installed GUT runner path; gut only |

**Annotations**: `readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 138. run_project_test

运行单个项目测试脚本。Python 集成测试使用 python 执行，GUT 单元测试通过 Godot headless 执行。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `test_path` | string | 是 | `res://` 下的测试文件路径 |
| `timeout_ms` | int | 否 | 超时时间（毫秒） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"`、`"skipped"` 或 `"error"` |
| `framework` | string | 测试框架：`python` 或 `gut` |
| `test_path` | string | 测试文件路径 |
| `exit_code` | int | 退出码 |
| `command` | array | 执行的命令 |
| `output` | array | 输出内容 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 139. run_project_tests

从目录中发现并运行多个项目测试，聚合通过/失败计数。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索路径，默认 `res://test` |
| `framework` | string | 否 | 框架过滤：`python` 或 `gut` |
| `only_runnable` | boolean | 否 | 是否只运行可运行的测试，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"partial"` |
| `search_path` | string | 搜索路径 |
| `framework` | string | 框架 |
| `total_count` | int | 总测试数 |
| `passed_count` | int | 通过数 |
| `failed_count` | int | 失败数 |
| `skipped_count` | int | 跳过数 |
| `results` | array | 每个测试的结果 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 140. list_project_input_actions

列出 ProjectSettings 中存储的项目 InputMap 动作，包含序列化的输入事件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 否 | 精确动作名称过滤 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `actions` | array | 动作数组 |
| `count` | int | 动作数量 |
| `filter` | string | 过滤条件 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 141. upsert_project_input_action

在 ProjectSettings 中创建或更新项目 InputMap 动作并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 动作名称 |
| `deadzone` | number | 否 | 死区值，默认 `0.5` |
| `erase_existing` | boolean | 否 | 是否清除现有事件，默认 `false` |
| `events` | array | 否 | 要存储的结构化输入事件 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 动作名称 |
| `existed_before` | boolean | 之前是否存在 |
| `deadzone` | number | 死区值 |
| `event_count` | int | 事件总数 |
| `events` | array | 当前事件 |
| `added_events` | array | 新添加的事件 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 142. remove_project_input_action

从 ProjectSettings 中移除项目 InputMap 动作并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 动作名称 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 动作名称 |
| `removed` | boolean | 是否已移除 |
| `event_count` | int | 移除前的事件数 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 143. list_project_autoloads

列出项目自动加载条目，包含解析后的路径、单例标志和项目设置顺序。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `filter` | string | 否 | 大小写不敏感的自动加载名称或路径过滤 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `autoloads` | array | 自动加载条目数组 |
| `count` | int | 条目数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 144. list_project_global_classes

列出通过 `class_name` 元数据注册的项目全局脚本类。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `filter` | string | 否 | 大小写不敏感的类名、基类型或脚本路径过滤 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `classes` | array | 全局类信息数组 |
| `count` | int | 类数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 145. get_class_api_metadata

获取引擎 ClassDB 类或项目全局脚本类的类型化 API 元数据。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `class_name` | string | 是 | 类名（如 `"Node"` 或项目 `class_name`） |
| `filter` | string | 否 | 方法/属性/信号/常量名称大小写不敏感过滤 |
| `include_base_api` | boolean | 否 | 对全局类是否包含基类 ClassDB 元数据，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `class_name` | string | 类名 |
| `source` | string | 来源：`classdb` 或 `global_class` |
| `base_class` | string | 基类 |
| `methods` | array | 方法列表 |
| `properties` | array | 属性列表 |
| `signals` | array | 信号列表 |
| `constants` | array | 常量列表 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 146. inspect_csharp_project_support

检查 C# / Mono 项目支持文件（.csproj 和 .sln），包括目标框架、程序集元数据和引用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 扫描目录，默认 `res://` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `search_path` | string | 搜索路径 |
| `project_count` | int | 项目文件数 |
| `solution_count` | int | 解决方案文件数 |
| `projects` | array | 项目详情 |
| `solutions` | array | 解决方案详情 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 147. compare_render_screenshots

比较两张截图图像并报告像素差异、RMSE 和基于阈值的匹配状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `baseline_path` | string | 是 | 基准截图路径 |
| `candidate_path` | string | 是 | 候选截图路径 |
| `max_diff_pixels` | int | 否 | 允许的最大差异像素数，默认 `0` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `baseline_path` | string | 基准路径 |
| `candidate_path` | string | 候选路径 |
| `width` | int | 图像宽度 |
| `height` | int | 图像高度 |
| `diff_pixel_count` | int | 差异像素数 |
| `diff_ratio` | number | 差异比例 |
| `rmse` | number | 均方根误差 |
| `max_channel_delta` | number | 最大通道差异 |
| `matches` | boolean | 是否匹配 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 148. inspect_tileset_resource

检查 TileSet 资源并汇总其源、图集 tile 和场景 tile。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | TileSet 资源路径 |
| `include_tiles` | boolean | 否 | 是否包含每个 tile 的详细信息，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_path` | string | 资源路径 |
| `source_count` | int | 源数量 |
| `tile_size` | object | tile 尺寸 |
| `sources` | array | 源信息数组 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 149. reimport_resources

使用 Godot 的 `EditorFileSystem` 导入管线重新导入项目资源。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_paths` | array | 是 | 要重新导入的源资源路径列表 |
| `refresh_metadata` | boolean | 否 | 是否在重导入前刷新元数据，默认 `true` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"partial"` |
| `requested_count` | int | 请求重导入数 |
| `reimported_count` | int | 实际重导入数 |
| `resource_paths` | array | 请求的路径 |
| `invalid_paths` | array | 无效路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 150. get_import_metadata

读取源资产的 Godot 导入元数据，包括导入器设置和导入后的产物路径。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 源资产路径（如 `res://icon.png`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_path` | string | 资源路径 |
| `import_config_path` | string | 导入配置文件路径 |
| `exists` | boolean | 是否存在 |
| `importer` | string | 导入器名称 |
| `resource_type` | string | 资源类型 |
| `uid` | string | 资源 UID |
| `imported_path` | string | 导入后的资源路径 |
| `sections` | object | 导入器设置节 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 151. get_resource_uid_info

检查 Godot ResourceUID 映射，用于资源路径或 `uid://` 标识符。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 否 | 资源路径 |
| `uid` | string | 否 | `uid://` 标识符 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_path` | string | 资源路径 |
| `uid` | string | UID 字符串 |
| `uid_id` | string | UID 数值 ID |
| `editor_uid` | string | 编辑器 UID |
| `resolved_path` | string | 解析后的路径 |
| `exists` | boolean | 资源是否存在 |
| `has_uid_mapping` | boolean | 是否有 UID 映射 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 152. fix_resource_uid

确保资源文件有持久的 UID 并刷新编辑器文件系统映射。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 要修复的资源路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"`、`"already_assigned"` 或错误 |
| `resource_path` | string | 资源路径 |
| `previous_uid` | string | 之前的 UID |
| `uid` | string | 新的 UID |
| `uid_id` | string | UID 数值 ID |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 153. get_resource_dependencies

使用 Godot 的 `ResourceLoader` 依赖元数据列出解析后的资源依赖。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 要检查的资源路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_path` | string | 资源路径 |
| `dependency_count` | int | 依赖数量 |
| `dependencies` | array | 依赖路径列表 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 154. scan_missing_resource_dependencies

扫描项目资源中的破损或缺失依赖引用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 扫描目录，默认 `res://` |
| `max_results` | int | 否 | 最大返回问题数，默认 `200` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `search_path` | string | 搜索路径 |
| `scanned_resources` | int | 扫描的资源数 |
| `issue_count` | int | 问题数量 |
| `issues` | array | 问题详情数组 |
| `truncated` | bool | 当 `max_results` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有更多问题可通过增大 `max_results` 重新扫描 |
| `max_results_applied` | int | 本次实际应用的 `max_results` 值 |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 155. scan_cyclic_resource_dependencies

基于解析的 `ResourceLoader` 依赖元数据扫描项目资源的循环依赖链。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 扫描目录，默认 `res://` |
| `max_results` | int | 否 | 最大返回问题数，默认 `100` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `search_path` | string | 搜索路径 |
| `scanned_resources` | int | 扫描的资源数 |
| `issue_count` | int | 问题数量 |
| `issues` | array | 循环依赖链详情 |
| `truncated` | bool | 当 `max_results` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有更多循环依赖问题可通过增大 `max_results` 重新扫描 |
| `max_results_applied` | int | 本次实际应用的 `max_results` 值 |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 156. detect_broken_scripts

扫描 GDScript 文件的语法错误和轻量级警告。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 扫描目录，默认 `res://` |
| `include_warnings` | boolean | 否 | 是否包含警告，默认 `true` |
| `max_results` | int | 否 | 最大返回问题数，默认 `200` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `search_path` | string | 搜索路径 |
| `scanned_scripts` | int | 扫描的脚本数 |
| `broken_count` | int | 有语法错误的脚本数 |
| `warning_count` | int | 有警告的脚本数 |
| `issues` | array | 问题详情数组 |
| `truncated` | bool | 当 `max_results` 限制导致本次返回不完整时为 `true` |
| `has_more` | bool | 是否还有更多脚本问题可通过增大 `max_results` 重新扫描 |
| `max_results_applied` | int | 本次实际应用的 `max_results` 值 |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 157. audit_project_health

运行轻量级项目健康审计，覆盖破损脚本和缺失资源依赖。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 扫描目录，默认 `res://` |
| `include_warnings` | boolean | 否 | 是否包含脚本警告，默认 `true` |
| `max_results` | int | 否 | 每类最大问题数，默认 `200` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"healthy"`、`"issues_found"` 或 `"error"` |
| `search_path` | string | 搜索路径 |
| `summary` | object | 审计摘要（broken_scripts、missing_deps、cyclic_deps 计数） |
| `broken_scripts` | array | 破损脚本详情 |
| `missing_dependencies` | array | 缺失依赖详情 |
| `cyclic_dependencies` | array | 循环依赖详情 |
| `truncated` | bool | 当任一子扫描受到 `max_results` 限制而不完整时为 `true` |
| `has_more` | bool | 是否还有更多诊断问题可通过增大 `max_results` 重新运行审计 |
| `max_results_applied` | int | 本次实际应用的 `max_results` 值 |
| `next_max_results` | int | 当 `has_more=true` 时，建议下一次请求使用的更大 `max_results` |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

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

### 158. inspect_project_resource

检查单个项目资源，并返回有界的属性摘要。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 要检查的资源路径，如 `res://resources/example.tres` |
| `include_property_values` | boolean | 否 | 是否序列化返回属性值。默认 `false` |
| `property_filter` | string | 否 | 对属性名做不区分大小写的子串过滤 |
| `max_properties` | int | 否 | 最多返回多少个匹配属性。默认 `40` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_path` | string | 资源路径 |
| `is_loadable` | boolean | 资源是否成功加载 |
| `class_name` | string | 资源的 Godot 类名 |
| `script_path` | string | 资源挂载脚本路径，无脚本时为空 |
| `property_filter_applied` | string | 实际应用的属性过滤器 |
| `include_property_values` | boolean | 本次是否序列化属性值 |
| `property_count` | int | 匹配过滤条件的总属性数 |
| `returned_property_count` | int | 本次实际返回的属性数 |
| `properties` | array | 属性条目数组，每项包含 `name`、`type`、`usage`、`hint`、`hint_string`、`class_name`，以及可选 `value` |
| `properties_truncated` | boolean | 当 `max_properties` 导致本次属性返回不完整时为 `true` |
| `has_more_properties` | boolean | 是否仍有更多属性未返回 |
| `max_properties_applied` | int | 本次应用的属性返回上限 |
| `next_max_properties` | int | 截断时建议的下一次更大属性预算 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 159. update_project_resource_properties

更新单个现有项目资源的属性，并原地保存。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 要更新的现有资源路径，如 `res://resources/example.tres` |
| `properties` | Dictionary | 是 | 要写入的属性键值对；当前最小稳定 slice 仅保证标量、颜色和常见向量/矩形字典形状 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `resource_path` | string | 已保存的资源路径 |
| `class_name` | string | 更新资源的 Godot 类名 |
| `updated_properties` | array | 实际更新并保存的属性名列表 |
| `updated_property_count` | int | 本次成功更新的属性数量 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 160. duplicate_project_resource

复制单个现有 `.tres` / `.res` 资源到新路径，不修改源资源。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `source_path` | string | 是 | 现有源资源路径 |
| `destination_path` | string | 是 | 新的目标资源路径；必须与源路径不同，且目标文件不能已存在 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `source_path` | string | 源资源路径 |
| `destination_path` | string | 新生成的目标资源路径 |
| `class_name` | string | 复制后资源的 Godot 类名 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 161. delete_project_resource

删除单个现有 `.tres` / `.res` 项目资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 要删除的现有资源路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `resource_path` | string | 已删除的资源路径 |
| `removed` | boolean | 是否确认已删除 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 162. move_project_resource

移动或重命名单个现有 `.tres` / `.res` 项目资源到新路径。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `source_path` | string | 是 | 现有 `.tres` / `.res` 资源路径。 |
| `destination_path` | string | 是 | 将接收移动后资源的新 `.tres` / `.res` 路径。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `source_path` | string | 原始资源路径。 |
| `destination_path` | string | 移动后的目标资源路径。 |
| `moved` | boolean | 成功时恒为 `true`。 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 163. set_project_setting

设置单个项目设置值并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_name` | string | 是 | 现有项目设置键，或 `mcp/` 命名空间下的自定义键。 |
| `setting_value` | mixed | 是 | 新的标量值。当前最小 slice 仅支持布尔、整数、浮点和字符串。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `setting_name` | string | 被写入的设置键。 |
| `existed_before` | boolean | 写入前该设置是否已经存在。 |
| `value_type` | string | 持久化后值的 Godot 类型名。 |
| `previous_value` | mixed | 写入前的值；新建自定义键时为 `null`。 |
| `persisted_value` | mixed | 保存后重新读取到的值。 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 164. clear_project_setting

清除单个项目设置键并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_name` | string | 是 | 要清除的现有项目设置键，或 `mcp/` 命名空间下的自定义键。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `setting_name` | string | 被清除的设置键。 |
| `existed_before` | boolean | 清除前该设置是否存在。 |
| `removed` | boolean | 若设置实际被清除则为 `true`，不存在时为 `false`。 |
| `previous_value` | mixed | 清除前的值；若设置原本不存在则为 `null`。 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 165. upsert_project_autoload

创建或更新单条项目 autoload 并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `name` | string | 是 | Autoload 条目名称。 |
| `path` | string | 是 | Autoload 目标路径。当前最小 slice 支持 `.gd`、`.cs`、`.tscn`。 |
| `is_singleton` | boolean | 否 | 是否以 singleton 形式注册。默认 `true`。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 持久化后的 autoload 名称。 |
| `path` | string | 持久化后的 autoload 路径。 |
| `is_singleton` | boolean | 持久化后的 singleton 标志。 |
| `setting_name` | string | 对应的 `autoload/<name>` 项目设置键。 |
| `existed_before` | boolean | 写入前该 autoload 是否已经存在。 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`, `openWorldHint=false`

---

### 166. remove_project_autoload

删除单条项目 autoload 并保存 `project.godot`。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `name` | string | 是 | 要删除的 autoload 条目名称。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 被删除的 autoload 名称。 |
| `setting_name` | string | 对应的 `autoload/<name>` 项目设置键。 |
| `existed_before` | boolean | 删除前该 autoload 是否存在。 |
| `removed` | boolean | 若设置实际被删除则为 `true`，不存在时为 `false`。 |
| `path` | string | 删除前的 autoload 路径。若条目不存在则省略。 |
| `is_singleton` | boolean | 删除前的 singleton 标志。若条目不存在则省略。 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 167. set_project_plugin_enabled

启用或禁用单个已安装编辑器插件，并通过公开 editor API 回传结果启用状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `plugin_path` | string | 是 | 插件配置路径，必须是 `res://addons/.../plugin.cfg`。 |
| `enabled` | boolean | 是 | 目标启用状态；`true` 为启用，`false` 为禁用。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `plugin_path` | string | 持久化操作对应的插件配置路径。 |
| `plugin_name` | string | 从插件目录名推导出的 plugin 名称。 |
| `enabled_requested` | boolean | 本次请求的目标启用状态。 |
| `enabled` | boolean | 操作后通过 editor API 读回的实际启用状态。 |
| `existed_before` | boolean | 操作前该插件是否已经处于启用状态。 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 168. set_project_feature_profile

激活一个已存在的编辑器 feature profile，或切回默认 profile。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `profile_name` | string | 是 | 要激活的 feature profile 名称；传空字符串 `""` 可重置为默认 profile。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `profile_name_requested` | string | 本次请求的 profile 名称；默认重置时为空字符串。 |
| `previous_profile` | string | 切换前的当前 profile 名称；默认 profile 时为空字符串。 |
| `current_profile` | string | 切换后的当前 profile 名称；默认 profile 时为空字符串。 |
| `used_default` | boolean | 若本次请求是切回默认 profile，则为 `true`。 |
| `profile_path` | string | 非默认 profile 时解析到的 `%APPDATA%/Godot/feature_profiles/<name>.profile` 路径；默认重置时为空字符串。 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=false`

---

### 169. list_project_feature_profiles

列出 editor config 目录中可用的 feature profile，并标记当前激活的 profile。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `profiles` | array | 可用 feature profile 条目数组，每项包含 `name`、`profile_path`、`is_current`。 |
| `count` | integer | 当前发现的 feature profile 数量。 |
| `current_profile` | string | 当前激活的 profile 名称；默认 profile 时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 170. list_project_plugins

列出 `res://addons/*/plugin.cfg` 下发现的已安装编辑器插件，并标记当前 enabled 状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `plugins` | array | 插件条目数组，每项包含 `name`、`plugin_path`、`enabled`。 |
| `count` | integer | 当前发现的插件数量。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 171. get_project_configuration_summary

返回一个有界的 project configuration summary，汇总当前已安装插件、autoload 条目和可用 feature profile 的状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_items` | integer | 否 | 每类 summary 列表最多返回多少条目。默认 `10`，最小为 `1`。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `max_items_applied` | integer | 实际应用的每类列表预算。 |
| `plugin_count` | integer | 当前发现的已安装 editor plugin 总数。 |
| `enabled_plugin_count` | integer | 当前启用的 editor plugin 数量。 |
| `plugins` | array | 有界插件 summary 数组，每项包含 `name`、`plugin_path`、`enabled`。 |
| `plugins_truncated` | boolean | 插件 summary 是否因 `max_items` 被截断。 |
| `autoload_count` | integer | 当前配置的 autoload 总数。 |
| `autoloads` | array | 有界 autoload summary 数组，每项包含 `name`、`path`、`is_singleton`、`order`。 |
| `autoloads_truncated` | boolean | autoload summary 是否因 `max_items` 被截断。 |
| `feature_profile_count` | integer | 当前 editor config 目录下可用的 feature profile 总数。 |
| `current_feature_profile` | string | 当前激活的 feature profile 名称；默认 profile 时为空字符串。 |
| `feature_profiles` | array | 有界 feature profile summary 数组，每项包含 `name`、`profile_path`、`is_current`。 |
| `feature_profiles_truncated` | boolean | feature profile summary 是否因 `max_items` 被截断。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 172. inspect_project_plugin

检查一个已安装的 `plugin.cfg`，返回插件元数据和当前 live enabled 状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `plugin_path` | string | 是 | 插件配置路径，必须是 `res://addons/.../plugin.cfg`。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `plugin_path` | string | 回显的插件配置路径。 |
| `plugin_name` | string | 从插件目录名推导出的 plugin 名称。 |
| `display_name` | string | `plugin.cfg` 里 `[plugin] name` 的显示名称。 |
| `description` | string | `plugin.cfg` 里的描述。 |
| `author` | string | `plugin.cfg` 里的作者。 |
| `version` | string | `plugin.cfg` 里的版本。 |
| `script` | string | `plugin.cfg` 里的入口脚本路径。 |
| `enabled` | boolean | 当前 editor session 中该插件是否处于 enabled 状态。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 173. inspect_project_autoload

检查一个 autoload 条目，返回当前是否存在、解析后的路径、singleton 标记和设置键。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `name` | string | 是 | 要检查的 autoload 条目名称。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 回显的 autoload 名称。 |
| `setting_name` | string | 对应的 `autoload/<name>` 项目设置键。 |
| `exists` | boolean | 当前 autoload 条目是否存在。 |
| `path` | string | 解析后的 autoload 路径。条目不存在时省略。 |
| `is_singleton` | boolean | 当前 autoload 是否带 singleton 标记。条目不存在时省略。 |
| `order` | integer | 当前 autoload 项目设置顺序。条目不存在时省略。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 174. inspect_project_feature_profile

检查一个 feature profile，返回当前是否存在、解析后的 profile 路径，以及它是否正处于激活状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `profile_name` | string | 是 | 要检查的 feature profile 名称。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `profile_name` | string | 回显的 feature profile 名称。 |
| `profile_path` | string | 解析后的 `.profile` 文件路径。 |
| `exists` | boolean | 当前 profile 文件是否存在。 |
| `is_current` | boolean | 当前 profile 是否正处于激活状态。不存在时恒为 `false`。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 175. inspect_project_setting

检查一个 project setting key，返回当前是否存在、持久化值以及 Godot 类型名。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_name` | string | 是 | 现有项目设置键，或 `mcp/` 命名空间下的自定义键。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `setting_name` | string | 回显的设置键。 |
| `exists` | boolean | 当前项目设置是否存在。 |
| `value_type` | string | 持久化值的 Godot 类型名。设置不存在时省略。 |
| `persisted_value` | mixed | 当前持久化值。设置不存在时省略。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 176. inspect_project_input_action

检查一个 project InputMap action，返回当前是否存在、deadzone、事件数量和序列化事件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `action_name` | string | 是 | 要检查的 InputMap action 名称。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `action_name` | string | 回显的 action 名称。 |
| `exists` | boolean | 当前 action 是否存在。 |
| `deadzone` | number | 当前 action 的 deadzone。action 不存在时省略。 |
| `event_count` | integer | 当前 action 绑定的事件数量。action 不存在时省略。 |
| `events` | array | 当前 action 的序列化输入事件数组。action 不存在时省略。 |
| `setting_name` | string | 对应的 `input/<action_name>` 项目设置键。action 不存在时省略。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 177. inspect_project_global_class

检查一个 project global class 条目，返回标准化后的类元数据。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `class_name` | string | 是 | 要检查的 project global class_name。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `class_name` | string | 回显的 global class 名称。 |
| `exists` | boolean | 当前 global class 条目是否存在。 |
| `path` | string | global class 脚本路径。不存在时省略。 |
| `base` | string | global class 的基类名。不存在时省略。 |
| `language` | string | global class 所属语言。不存在时省略。 |
| `is_tool` | boolean | global class 是否为 tool 脚本。不存在时省略。 |
| `is_abstract` | boolean | global class 是否为 abstract。不存在时省略。 |
| `icon` | string | global class 关联 icon 路径。不存在时省略。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 178. get_editor_paths

读取稳定的编辑器路径状态，包括配置目录、数据目录、缓存目录、项目级 editor settings 路径，以及 self-contained 模式信息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `config_dir` | string | 用户级 Godot 编辑器配置目录绝对路径。 |
| `data_dir` | string | 用户级 Godot 编辑器数据目录绝对路径。 |
| `cache_dir` | string | 用户级 Godot 编辑器缓存目录绝对路径。 |
| `project_settings_dir` | string | 当前项目对应的 editor settings 相对路径，通常为 `res://.godot/editor`。 |
| `export_templates_dir` | string | 基于 `data_dir` 推导出的默认导出模板目录。 |
| `self_contained` | boolean | 当前编辑器实例是否处于 self-contained 模式。 |
| `self_contained_file` | string | 触发 self-contained 模式的标记文件绝对路径；未启用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 179. get_editor_shell_state

读取稳定的编辑器 shell 状态，包括主 shell 容器标识、当前有效编辑器缩放，以及多窗口模式是否启用。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `main_screen_name` | string | `EditorInterface.get_editor_main_screen()` 返回的 live 主 shell 控件名称。 |
| `main_screen_type` | string | 该主 shell 控件的 Godot 类名。 |
| `editor_scale` | number | 当前有效编辑器 UI 缩放比例，`1.0` 表示 100%。 |
| `multi_window_enabled` | boolean | 当前编辑器实例是否启用多窗口模式。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 180. get_editor_language

读取当前 Godot 编辑器 UI 配置使用的语言。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `editor_language` | string | `EditorInterface.get_editor_language()` 返回的当前编辑器语言标识。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 181. get_editor_play_state

读取当前编辑器是否正在运行场景，以及当前运行场景路径。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `is_playing_scene` | boolean | 当前编辑器是否处于播放场景状态。暂停中的场景也视为播放中。 |
| `playing_scene` | string | `EditorInterface.get_playing_scene()` 返回的当前运行场景路径；未运行时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 182. get_editor_3d_snap_state

读取 3D 编辑器当前是否启用吸附，以及平移、旋转、缩放吸附步长。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `snap_enabled` | boolean | 当前 3D 编辑器是否启用了吸附模式。 |
| `translate_snap` | number | 当前 3D 平移吸附步长。 |
| `rotate_snap` | number | 当前 3D 旋转吸附角度。 |
| `scale_snap` | number | 当前 3D 缩放吸附步长。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 183. get_editor_subsystem_availability

读取关键编辑器子系统当前是否可用，包括 command palette、toaster、resource filesystem 和 script editor。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `command_palette_available` | boolean | command palette handle 当前是否可用。 |
| `command_palette_type` | string | command palette handle 的 Godot 类名；不可用时为空字符串。 |
| `toaster_available` | boolean | editor toaster handle 当前是否可用。 |
| `toaster_type` | string | editor toaster handle 的 Godot 类名；不可用时为空字符串。 |
| `resource_filesystem_available` | boolean | resource filesystem handle 当前是否可用。 |
| `resource_filesystem_type` | string | resource filesystem handle 的 Godot 类名；不可用时为空字符串。 |
| `script_editor_available` | boolean | script editor handle 当前是否可用。 |
| `script_editor_type` | string | script editor handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 184. get_editor_previewer_availability

读取 editor resource previewer handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_previewer_available` | boolean | resource previewer handle 当前是否可用。 |
| `resource_previewer_type` | string | resource previewer handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 185. get_editor_undo_redo_availability

读取 editor undo/redo manager handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `undo_redo_available` | boolean | undo/redo manager handle 当前是否可用。 |
| `undo_redo_type` | string | undo/redo manager handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 186. get_editor_viewport_availability

读取 editor 2D viewport 与主 3D viewport handle 当前是否可用，以及它们的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `viewport_2d_available` | boolean | 2D editor viewport handle 当前是否可用。 |
| `viewport_2d_type` | string | 2D editor viewport handle 的 Godot 类名；不可用时为空字符串。 |
| `viewport_3d_available` | boolean | 主 3D editor viewport handle 当前是否可用。 |
| `viewport_3d_type` | string | 主 3D editor viewport handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 187. get_editor_base_control_availability

读取 editor base control handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `base_control_available` | boolean | base control handle 当前是否可用。 |
| `base_control_type` | string | base control handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 188. get_editor_file_system_dock_availability

读取 editor file system dock handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `file_system_dock_available` | boolean | file system dock handle 当前是否可用。 |
| `file_system_dock_type` | string | file system dock handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 189. get_editor_inspector_availability

读取 editor inspector handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `inspector_available` | boolean | inspector handle 当前是否可用。 |
| `inspector_type` | string | inspector handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 190. get_editor_current_location

读取 editor 当前正在查看的路径和当前目录摘要。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `current_path` | string | 当前正在查看的 FileSystem 路径。 |
| `current_directory` | string | 当前正在查看的目录；若当前为文件，则返回其基目录。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 191. get_editor_selected_paths_summary

读取当前在 FileSystem 中选中的路径列表及数量摘要。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `selected_paths` | array | 当前选中的文件或目录路径列表。 |
| `selected_count` | integer | 当前选中路径数量。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 192. get_editor_selection_availability

读取 editor selection handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `selection_available` | boolean | selection handle 当前是否可用。 |
| `selection_type` | string | selection handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 193. get_editor_command_palette_availability

读取 editor command palette handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `command_palette_available` | boolean | command palette handle 当前是否可用。 |
| `command_palette_type` | string | command palette handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 194. get_editor_toaster_availability

读取 editor toaster handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `toaster_available` | boolean | toaster handle 当前是否可用。 |
| `toaster_type` | string | toaster handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 195. get_editor_resource_filesystem_availability

读取 editor resource filesystem handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resource_filesystem_available` | boolean | resource filesystem handle 当前是否可用。 |
| `resource_filesystem_type` | string | resource filesystem handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 196. get_editor_script_editor_availability

读取 editor script editor handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_editor_available` | boolean | script editor handle 当前是否可用。 |
| `script_editor_type` | string | script editor handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 197. get_editor_open_script_summary

读取 editor 当前是否有活动脚本打开、当前脚本路径、当前脚本编辑器类型、全部打开脚本标签摘要，以及当前脚本编辑器断点列表。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_open` | boolean | 当前 editor 是否有活动脚本打开。 |
| `script_path` | string | 当前活动脚本的资源路径；没有活动脚本时为空字符串。 |
| `current_script_type` | string | `ScriptEditor.get_current_script()` 返回的当前活动脚本资源类名；没有活动脚本时为空字符串。 |
| `current_editor_type` | string | `ScriptEditor.get_current_editor()` 返回的当前 `ScriptEditorBase` 类名；不可用时为空字符串。 |
| `current_editor_breakpoints` | array | `ScriptEditor.get_current_editor().get_breakpoints()` 返回的当前活动 `ScriptEditorBase` 断点行号列表。 |
| `current_editor_breakpoint_count` | integer | 当前活动 `ScriptEditorBase` 断点行号数量。 |
| `open_script_paths` | array | 当前已打开脚本资源路径列表。 |
| `open_script_types` | array | `ScriptEditor.get_open_scripts()` 返回的当前打开脚本资源类名列表。 |
| `open_script_count` | integer | 当前已打开脚本数量。 |
| `open_script_editor_types` | array | `ScriptEditor.get_open_script_editors()` 返回的当前打开 `ScriptEditorBase` 类名列表。 |
| `open_script_editor_count` | integer | 当前打开的 `ScriptEditorBase` 标签数量。 |
| `breakpoints` | array | `ScriptEditor.get_breakpoints()` 返回的当前断点字符串列表。 |
| `breakpoint_count` | integer | 当前断点数量。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 198. get_editor_open_scene_summary

读取 editor 当前是否有活动场景打开，以及当前场景路径。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_open` | boolean | 当前 editor 是否有活动场景打开。 |
| `scene_path` | string | 当前活动场景的资源路径；没有活动场景时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 199. get_editor_open_scenes_summary

读取 editor 当前打开的场景路径列表、当前活动场景路径以及打开场景数量。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `open_scene_paths` | array | 当前打开的场景路径列表。 |
| `active_scene_path` | string | 当前活动场景的资源路径；没有活动场景时为空字符串。 |
| `open_scene_count` | integer | 当前打开场景的数量。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 200. get_editor_open_scene_roots_summary

读取 editor 当前打开场景根节点的名称/类型列表以及根节点数量。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `open_scene_roots` | array | 当前打开场景根节点的摘要列表，每项包含 `root_name` 和 `root_type`。 |
| `open_scene_root_count` | integer | 当前打开场景根节点的数量。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 201. get_editor_settings_availability

读取 editor settings handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `editor_settings_available` | boolean | editor settings handle 当前是否可用。 |
| `editor_settings_type` | string | editor settings handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 202. get_editor_theme_availability

读取 editor theme handle 当前是否可用，以及它的 live class name。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `editor_theme_available` | boolean | editor theme handle 当前是否可用。 |
| `editor_theme_type` | string | editor theme handle 的 Godot 类名；不可用时为空字符串。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 203. get_editor_current_feature_profile

读取 editor 当前激活的 feature profile 名称。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| 无 | - | - | 无需参数。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `current_feature_profile` | string | `EditorInterface.get_current_feature_profile()` 返回的当前激活 feature profile 名称；默认 profile 时为空字符串。 |
| `uses_default_profile` | boolean | 当前是否仍在使用默认 feature profile。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 204. get_editor_plugin_enabled_state

读取指定 editor plugin 当前是否处于 enabled 状态。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `plugin_name` | string | 是 | Editor plugin 目录名，例如 `gut` 或 `godot_mcp`。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `plugin_name` | string | 回显请求的 plugin 名称。 |
| `enabled` | boolean | `EditorInterface.is_plugin_enabled(plugin_name)` 返回的当前 enabled 真值。 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

---

### 205. get_editor_current_scene_dirty_state

读取当前活动场景是否被 editor 标记为已编辑（dirty），并可选地对当前活动场景根节点应用一个明确的 edited-state 覆盖。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `set_dirty` | boolean | 否 | 可选的 edited-state 覆盖。提供后会先对当前活动场景根节点调用 `EditorInterface.set_object_edited(edited_scene_root, set_dirty)`，再返回 live dirty-state 摘要。 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_open` | boolean | 当前 editor 是否有活动场景打开。 |
| `scene_path` | string | 当前活动场景的资源路径；没有活动场景时为空字符串。 |
| `scene_dirty` | boolean | `EditorInterface.is_object_edited(edited_scene_root)` 返回的当前 dirty 真值。 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`, `openWorldHint=false`

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

本手册详细说明了 Godot MCP Native 项目的所有核心工具及部分补充工具。项目共 **205 个工具**（46 核心 + 159 补充），所有工具均可通过 MCP 工具管理面板按分组动态启用/禁用。补充工具（`*-Advanced` 分组）默认不启用，需在工具管理面板中手动开启。

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
