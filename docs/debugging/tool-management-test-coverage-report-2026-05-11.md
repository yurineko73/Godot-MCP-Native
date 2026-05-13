# MCP 工具管理测试覆盖率报告

> Historical snapshot: this report reflects the tool surface at the time of the 2026-05-11 run and does not describe the current live 205-tool / 14-resource catalog. Use `docs/current/tools-reference.md` or MCP `tools/list` for current counts.


**日期**: 2026-05-11
**总览**: 22 个测试脚本, 391 个测试用例, 714 个断言, **全部通过**

---

## 测试结果摘要

| 指标 | 值 |
|------|-----|
| 测试脚本数 | 22 |
| 测试用例数 | 391 |
| 通过数 | 391 |
| 失败数 | 0 |
| 断言数 | 714 |
| 耗时 | 3.934s |

---

## 修改/新增脚本 vs 测试覆盖映射

### 新增文件（4个新增 .gd 脚本）

| 源文件 | 测试文件 | 覆盖状态 |
|--------|----------|---------|
| `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd` | `test/unit/test_mcp_tool_classifier.gd` | ✅ 新建 - 21 个测试 |
| `addons/godot_mcp/native_mcp/tool_state_manager.gd` | `test/unit/test_tool_state_manager.gd` | ✅ 新建 - 13 个测试 |
| `addons/godot_mcp/ui/mcp_tool_group_item.gd` | ❌ 无测试 (UI 组件) | ⚠️ UI 组件, 需 Godot 场景树 |
| `addons/godot_mcp/ui/mcp_tool_item.gd` | ❌ 无测试 (UI 组件) | ⚠️ UI 组件, 需 Godot 场景树 |

### 修改文件（13个修改的 .gd 脚本）

| 源文件 | 对应测试文件 | 测试更新 | 覆盖内容 |
|--------|------------|---------|---------|
| `mcp_server_core.gd` | `test/unit/test_mcp_server_core.gd` | ✅ 更新 | register_tool 带 category/group, set_group_enabled, notify_tool_list_changed, load/save tool states, classifier/state_manager getter, dirty flag |
| `mcp_types.gd` | `test/unit/test_mcp_types.gd` | ✅ 更新 | MCPTool.category 和 group 字段默认值, getter/setter |
| `mcp_server_native.gd` | `test/unit/test_mcp_server_native.gd` | ✅ 更新 | load_tool_states 在 _enter_tree 中的调用顺序 |
| `mcp_transport_base.gd` | `test/unit/test_mcp_transport_base.gd` | ✅ 更新 | send_raw_message 方法存在性 |
| `mcp_http_server.gd` | `test/unit/test_mcp_http_server.gd` | ✅ 更新 | send_raw_message 方法存在性及调用 |
| `mcp_stdio_server.gd` | `test/unit/test_mcp_stdio_server.gd` | ✅ 更新 | send_raw_message 方法存在性及输出 |
| `mcp_panel_native.gd` | ❌ 无测试 (UI 面板) | ⚠️ UI 组件, 需 Godot Editor |
| `node_tools_native.gd` | `test/unit/tools/test_node_tools*.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |
| `script_tools_native.gd` | `test/unit/tools/test_script_tools*.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |
| `scene_tools_native.gd` | `test/unit/tools/test_scene_tools.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |
| `editor_tools_native.gd` | `test/unit/tools/test_editor_tools.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |
| `debug_tools_native.gd` | `test/unit/tools/test_debug_tools.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |
| `project_tools_native.gd` | `test/unit/tools/test_project_tools.gd` | ✅ 已有测试覆盖 | register_tool 参数变更无接口破坏 |

---

## 新建测试文件

### `test/unit/test_mcp_tool_classifier.gd` (21 tests)
- 测试 MCPToolClassifier 初始化全部 50 个工具
- 测试核心/补充工具分类计数 (46 core / 4 supplementary)
- 测试各组工具归属 (Node-Read, Node-Write, Script, Scene, Editor, Editor-Advanced, Debug, Debug-Advanced, Project)
- 测试工具分类查询 (get_tool_category, get_tool_group, is_core_tool, is_supplementary_tool)
- 测试所有分组不重复、所有工具不重复
- 测试未知工具默认值

### `test/unit/test_tool_state_manager.gd` (13 tests)
- 测试状态管理器初始化
- 测试无状态文件时加载空状态
- 测试保存/加载工具状态
- 测试 apply_states_to_server 应用状态到服务器
- 测试未注册工具被忽略
- 测试 capture_states_from_server 捕获服务器状态
- 测试 validate_core_tool_limit 校验
- 测试存储路径、版本常量、校验和持久化
- 测试配置完整性验证

---

## 修改的测试文件（新增测试内容）

### `test/unit/test_mcp_types.gd` (+4 tests)
- MCPTool.category 默认值为 "core"
- MCPTool.group 默认值为 ""
- MCPTool.category 和 group 可设置
- MCPTool.category 和 group 不影响有效性

### `test/unit/test_mcp_server_core.gd` (+12 tests)
- register_tool 带 category/group 参数
- register_tool 默认 category/group
- set_tool_enabled 设置 dirty flag
- clear_tool_list_dirty
- set_group_enabled 启用/禁用/未知组
- notify_tool_list_changed
- get_classifier / get_state_manager
- load_tool_states / save_tool_states

### `test/unit/test_mcp_server_native.gd` (+1 test)
- _enter_tree 中 load_tool_states 在 _create_main_screen_panel 之前调用

### `test/unit/test_mcp_transport_base.gd` (+3 tests)
- Transport base 有 send_raw_message 方法
- HTTP server 有 send_raw_message 方法
- Stdio server 有 send_raw_message 方法

### `test/unit/test_mcp_http_server.gd` (+2 tests)
- send_raw_message 方法存在
- send_raw_message 无 SSE 连接时调用不崩溃

### `test/unit/test_mcp_stdio_server.gd` (+2 tests)
- send_raw_message 方法存在
- send_raw_message 输出 JSON-RPC 消息

---

## 源文件修复（测试驱动）

在测试过程中发现的修复：

| 文件 | 修复 | 原因 |
|------|------|------|
| `mcp_tool_classifier.gd:120` | `get_all_tools()` 返回类型 `Array[String]` → `Array` | typed array 在 headless CLI 模式下运行时类型检查失败 |

---

## 遗留问题

| 问题 | 说明 | 优先级 |
|------|------|--------|
| UI 组件无测试 | `mcp_tool_group_item.gd`, `mcp_tool_item.gd`, `mcp_panel_native.gd` 需要 Godot 场景树/Editor | 低 |
| Trae CN 客户端通知不可达 | `notifications/tools/list_changed` 在 Trae CN 上未生效 | 低 |
| 核心工具计数超 40 | 当前 46 个核心工具，计划目标 ≤40（需后续版本将工具降级到补充） | 中 |

---

## 参考资料

- [测试完整输出](tool-management-test-results-2026-05-11.txt)
- [工具管理优化计划](../architecture/tool-management-optimization-plan.md)
- [UI 修复报告](../testing/tool-management-ui-fix-2026-05-11.md)
