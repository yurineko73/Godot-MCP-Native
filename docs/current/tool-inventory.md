# 当前工具清单

本文档按源码注册表核对 `addons/godot_mcp/tools/*_native.gd` 中当前暴露的 MCP 工具。更详细的参数说明仍以 `tools/list` 返回的 JSON Schema 和 [工具参考手册](tools-reference.md) 为准。

## 汇总

Godot MCP Native 当前注册 **146 个工具**，分为 6 个已启用工具模块：

| 类别 | 数量 | 源文件 | 覆盖范围 |
|------|------|--------|----------|
| Node Tools | 20 | `addons/godot_mcp/tools/node_tools_native.gd` | 编辑器场景树节点创建、修改、批处理、继承/持久化审计、信号和分组 |
| Script Tools | 14 | `addons/godot_mcp/tools/script_tools_native.gd` | 脚本读写、符号索引/引用/重命名、跳转、附加、校验和全文搜索 |
| Scene Tools | 8 | `addons/godot_mcp/tools/scene_tools_native.gd` | 项目场景、当前场景、打开标签页、场景结构和保存/关闭 |
| Editor Tools | 15 | `addons/godot_mcp/tools/editor_tools_native.gd` | 编辑器状态、运行控制、选择/聚焦、截图、Inspector、导出预设和项目重载 |
| Debug Tools | 63 | `addons/godot_mcp/tools/debug_tools_native.gd` | 日志、脚本执行、调试器会话、DAP 风格线程/栈/变量、运行时探针、截图、输入、动画、音频、TileMap、材质、主题和断言 |
| Project Tools | 26 | `addons/godot_mcp/tools/project_tools_native.gd` | 项目信息、资源依赖/UID/import、输入映射、Autoload、全局类、测试、健康检查和 C# 支持检测 |

`addons/godot_mcp/tools/resource_tools_native.gd` 目前存在文件但不注册工具。

## Node Tools

- `add_resource`
- `audit_scene_inheritance`
- `audit_scene_node_persistence`
- `batch_scene_node_edits`
- `batch_update_node_properties`
- `connect_signal`
- `create_node`
- `delete_node`
- `disconnect_signal`
- `duplicate_node`
- `find_nodes_in_group`
- `get_node_groups`
- `get_node_properties`
- `get_scene_tree`
- `list_nodes`
- `move_node`
- `rename_node`
- `set_anchor_preset`
- `set_node_groups`
- `update_node_property`

## Script Tools

- `analyze_script`
- `attach_script`
- `create_script`
- `find_script_symbol_definition`
- `find_script_symbol_references`
- `get_current_script`
- `list_project_script_symbols`
- `list_project_scripts`
- `modify_script`
- `open_script_at_line`
- `read_script`
- `rename_script_symbol`
- `search_in_files`
- `validate_script`

## Scene Tools

- `close_scene_tab`
- `create_scene`
- `get_current_scene`
- `get_scene_structure`
- `list_open_scenes`
- `list_project_scenes`
- `open_scene`
- `save_scene`

## Editor Tools

- `get_editor_screenshot`
- `get_editor_state`
- `get_inspector_properties`
- `get_selected_nodes`
- `get_signals`
- `inspect_export_templates`
- `list_export_presets`
- `reload_project`
- `run_export`
- `run_project`
- `select_file`
- `select_node`
- `set_editor_setting`
- `stop_project`
- `validate_export_preset`

## Debug Tools

- `add_debugger_capture_prefix`
- `assert_runtime_condition`
- `await_debugger_state`
- `await_runtime_condition`
- `call_runtime_node_method`
- `clear_output`
- `clear_runtime_theme_override`
- `create_runtime_node`
- `debug_print`
- `delete_runtime_node`
- `evaluate_debug_expression`
- `evaluate_runtime_expression`
- `execute_editor_script`
- `execute_script`
- `expand_debug_variable`
- `get_debug_output`
- `get_debug_scopes`
- `get_debug_stack_frames`
- `get_debug_stack_variables`
- `get_debug_state_events`
- `get_debug_threads`
- `get_debug_variables`
- `get_debugger_messages`
- `get_debugger_sessions`
- `get_editor_logs`
- `get_performance_metrics`
- `get_runtime_animation_state`
- `get_runtime_animation_tree_state`
- `get_runtime_audio_bus`
- `get_runtime_info`
- `get_runtime_material_state`
- `get_runtime_memory_trend`
- `get_runtime_performance_snapshot`
- `get_runtime_scene_tree`
- `get_runtime_screenshot`
- `get_runtime_shader_parameters`
- `get_runtime_theme_item`
- `get_runtime_tilemap_cell`
- `inspect_runtime_node`
- `install_runtime_probe`
- `list_runtime_animations`
- `list_runtime_audio_buses`
- `list_runtime_input_actions`
- `list_runtime_tilemap_layers`
- `play_runtime_animation`
- `remove_runtime_input_action`
- `remove_runtime_probe`
- `request_debug_break`
- `send_debug_command`
- `send_debugger_message`
- `set_debugger_breakpoint`
- `set_runtime_animation_tree_active`
- `set_runtime_shader_parameter`
- `set_runtime_theme_override`
- `set_runtime_tilemap_cell`
- `simulate_runtime_input_action`
- `simulate_runtime_input_event`
- `stop_runtime_animation`
- `toggle_debugger_profiler`
- `travel_runtime_animation_tree`
- `update_runtime_audio_bus`
- `update_runtime_node_property`
- `upsert_runtime_input_action`

## Project Tools

- `audit_project_health`
- `compare_render_screenshots`
- `create_resource`
- `detect_broken_scripts`
- `fix_resource_uid`
- `get_class_api_metadata`
- `get_import_metadata`
- `get_project_info`
- `get_project_settings`
- `get_project_structure`
- `get_resource_dependencies`
- `get_resource_uid_info`
- `inspect_csharp_project_support`
- `inspect_tileset_resource`
- `list_project_autoloads`
- `list_project_global_classes`
- `list_project_input_actions`
- `list_project_resources`
- `list_project_tests`
- `reimport_resources`
- `remove_project_input_action`
- `run_project_test`
- `run_project_tests`
- `scan_cyclic_resource_dependencies`
- `scan_missing_resource_dependencies`
- `upsert_project_input_action`

## 免打扰模式相关参数

默认启用 `vibe_coding_mode`。在该模式下，可能抢占编辑器焦点、切换选中项或打开/控制运行窗口的工具会被策略拦截。

- 对会改变编辑器焦点或选择的工具，单次调用可传入 `allow_ui_focus=true`。
- 对会打开或控制运行窗口的工具，单次调用可传入 `allow_window=true`。
- 需要持续人工调试时，可以在 MCP 面板关闭 `Vibe Coding / 免打扰模式`。
