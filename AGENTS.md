# AGENTS.md — Godot MCP 项目指南

## 项目简介
一个 **Godot 4.6 EditorPlugin**（位于 `addons/godot_mcp/`），在 Godot 内部原生实现了 MCP（Model Context Protocol）服务器，无需 Node.js 依赖。提供 **154 个工具**（30 核心 + 124 补充），分为 6 大类，供 AI 助手读取和修改项目。

- **插件入口**：`addons/godot_mcp/mcp_server_native.gd`（继承 `EditorPlugin`）
- **作者**：yurineko73 | **版本**：1.0.7
- **许可证**：MIT
- **渲染器**：GL Compatibility

## gdmcp CLI Skill
When using the shell-oriented `gdmcp` companion for Godot editor operations,
read `skills/gdmcp/SKILL.md` first. Use the high-level bounded commands before
progressive discovery with `tools search`, `tools schema`, and `tool-call`.

## PowerShell 7.x 路径
系统 PowerShell 版本可能变化，每次会话请验证确切的版本号：
```
& "C:\Program Files\WindowsApps\Microsoft.PowerShell_*_x64__8wekyb3d8bbwe\pwsh.exe"
```
用 `(Get-Command pwsh).Source` 解析路径。如果 WindowsApps 路径不可用，回退到系统默认 PowerShell。

## 代码语言政策
- **任何代码文件中不得出现中文字符** — 注释、字符串、标识符全部使用英文。
- 中文仅允许出现在：`AGENTS.md`、`README.zh.md` 和 `docs/`（翻译/计划文档）。

## 命令

### 运行 Godot 项目
在 Godot 编辑器（4.6.x，GL Compatibility 渲染器）中打开 `project.godot`。

### GUT 单元测试
```powershell
& "F:\Godot\Godot_v4.6.1-stable_win64.exe" --headless --path "." -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```
配置：`.gutconfig.json` — dirs: `res://test/unit/`, `log_level: 2`, `should_exit_on_finish: false`。

### 集成测试（Python）
```powershell
cd test/integration
python test_runtime_probe_flow.py
```
Python 测试会启动 Godot 4.6.2（`C:\SourceCode\Godot_v4.6.2-stable_mono_win64\...`），通过 HTTP MCP（端口 9080）进行通信。

## 架构

```
addons/godot_mcp/
├── mcp_server_native.gd       # EditorPlugin 入口 — 注册插件、管理生命周期
├── native_mcp/                 # 核心服务器引擎
│   ├── mcp_server_core.gd      # 中枢：工具注册、JSON-RPC 分发、信号总线
│   ├── mcp_transport_base.gd   # 传输层抽象基类
│   ├── mcp_http_server.gd      # HTTP/SSE 传输（默认端口 9080）
│   ├── mcp_stdio_server.gd     # stdio 传输（供 Claude Desktop 等使用）
│   ├── mcp_types.gd            # JSON-RPC 和 MCP 协议常量、MCPTool 数据类
│   ├── mcp_tool_classifier.gd  # 工具分类映射：{core/supplementary, group}（CORE_MAX_COUNT=30）
│   ├── mcp_resource_manager.gd # 资源读取/列表/订阅
│   ├── mcp_debugger_bridge.gd  # Godot 调试器 ↔ MCP 桥梁（断点、栈帧、变量）
│   ├── mcp_auth_manager.gd     # HTTP Bearer Token 认证
│   ├── config_manager.gd       # 插件配置读写
│   ├── settings_manager.gd     # 编辑器设置持久化
│   ├── tool_state_manager.gd   # 每个工具的状态管理
│   └── translation_manager.gd  # 国际化支持
├── runtime/
│   └── mcp_runtime_probe.gd    # Autoload 单例，用于运行时检查（动画、音频、着色器、瓦片地图、输入）
├── tools/                      # 工具实现（每个分类一个文件）
│   ├── node_tools_native.gd    # 20 个工具 — 创建/删除/更新/复制/移动/重命名节点、信号、分组、锚点预设、批量操作、场景审计
│   ├── script_tools_native.gd  # 14 个工具 — 读取/写入/创建/附加/分析/验证/执行脚本、符号索引、搜索
│   ├── scene_tools_native.gd   # 8 个工具 — 创建/保存/打开/关闭场景、结构查看、列表
│   ├── editor_tools_native.gd  # 16 个工具 — 运行/停止、状态、截图、信号、导出、选择、查看器
│   ├── debug_tools_native.gd   # 70 个工具 — 日志、断点、栈帧/变量、性能分析器、运行时探针、动画/音频/着色器/瓦片地图运行时控制
│   └── project_tools_native.gd # 26 个工具 — 项目信息/设置、资源、输入映射、自动加载、全局类、测试运行器、诊断
├── ui/
│   ├── mcp_panel_native.gd     # 主停靠面板（VBoxContainer）— 启动/停止、传输配置、日志查看、工具管理
│   ├── mcp_tool_item.gd        # 单个工具开关 UI
│   └── mcp_tool_group_item.gd  # 工具组折叠/展开 UI
└── utils/
    ├── node_utils.gd           # 节点查找辅助函数
    ├── path_validator.gd       # 路径验证
    ├── resource_utils.gd       # 资源 I/O 工具
    ├── script_utils.gd         # 脚本工具
    └── vibe_coding_policy.gd   # Vibe Coding 模式守卫（allow_ui_focus / allow_window）
```

## 规范

### GDScript 风格
- 变量、方法、函数名使用 `snake_case`
- 类名使用 `PascalCase`（`class_name ClassName`）
- 必须使用类型提示：`var player: Player`、`func greet() -> String:`
- 优先使用 Signal 进行节点间解耦通信
- 编辑器插件脚本使用 `@tool`
- 非节点工具类继承 `RefCounted`，插件入口继承 `EditorPlugin`
- GUT 测试文件使用 `extends "res://addons/gut/test.gd"`（不要用 `class_name` — GUT CLI 限制）

### 错误处理
- 工具处理函数返回错误字典：`{"error": "message"}`
- 生产代码中少用 `assert()`
- 每个工具处理函数顶部先验证参数

### 注释
- 中文注释仅允许在 AGENTS.md / README.zh.md / docs 中
- 所有 `.gd`、`.cs`、`.py` 文件：仅限英文

### 测试（强制）
- **每次代码变更必须包含测试更新**，位于 `test/` 目录：
  - **直接测试**：覆盖变动的逻辑（正常路径 + 边界情况 + 错误处理）
  - **影响范围测试**：识别并测试可能受影响的关联模块（签名变更、导出变量、信号等）
  - 禁止提交没有测试更新的 commit
- **单元测试**（`test/unit/`）：GUT 框架，工具测试文件位于 `test/unit/tools/`
- **集成测试**（`test/integration/`）：Python 脚本，通过 HTTP MCP 调用 Godot 4.6.2

### 新增工具流程

创建新 MCP 工具时，必须按顺序完成所有步骤。完整参考指南见 `docs/development/adding-new-tools.md`。

1. **实现处理器** — 在对应的 `*_tools_native.gd` 中创建 `_register_<name>()` 和 `_tool_<name>()` 函数，用 8 个参数调用 `server_core.register_tool()`（name, desc, input_schema, Callable, output_schema, annotations, category, group）
2. **注册到分类器** — 在 `mcp_tool_classifier.gd` 的 `_build_classifications()` 中添加条目，然后更新 `test_mcp_tool_classifier.gd` 中的工具总数和 supplementary 计数
3. **添加单元测试** — 在 `test/unit/tools/` 中覆盖缺失参数/无效参数/边界情况
4. **更新翻译文件** — 在 `translations/tool_descriptions.json` 和 `translations/tool_descriptions.csv` 中添加工具描述（中英文）
5. **更新文档** — `docs/current/tools-reference.md`（更新概览表格 + 添加工具条目）、`addons/godot_mcp/README.md` 和 `README.zh.md`
6. **验证** — 运行完整 GUT 测试套件，要求 0 失败

**注意：** supplementary 工具注册后默认禁用（`enabled = (category == "core")`），`tools/list` 不会返回它。用户需在 MCP 面板中手动启用，或在测试时用 `core.set_tool_enabled("tool_name", true)` 开启。

### 修改已有工具后的文档更新流程

每次修改已有工具（新增参数、返回值、行为变更）时，必须同步更新以下文档：

1. **`docs/current/tools-reference.md`**
   - 更新工具的**参数表**（新增/变更的参数名、类型、必需、描述）
   - 更新工具的**返回值表**（新增/变更的字段名、类型、描述）
   - 更新概览表中的分类计数（如调试工具 67→68）
   - 重编号后续工具（新增工具条目时）
2. **`README.md` 和 `README.zh.md`**（项目根目录和 `addons/godot_mcp/` 下）
   - 更新功能列表中的工具计数（`Comprehensive Tool Set` / `全面的工具集`）
   - 更新详细工具列表的分类计数（如 `### Debug (3 core + N advanced)`）
   - 在对应分类下**新增工具条目**（使用工具的 snake_case 名称）
3. **`docs/current/architecture.md`** — 如果工具分类数量有大幅变化，更新工具注册章节的统计表
4. **翻译文件**
   - `translations/tool_descriptions.json` — 新工具有描述文本
   - `translations/tool_descriptions.csv` — 新工具有中英文描述
5. **`docs/development/adding-new-tools.md`** — 如果工具创建流程有变化

**验证清单：**
- [ ] 全文搜索旧工具数（`154`、`66`、`124`、`70`）确认已替换
- [ ] 全文搜索新工具名确认已出现在详细工具列表
- [ ] 如果没有新工具，确认分类计数已更新
### 临时文件清理（强制）
每次代码修改结束后，必须清理：
1. `.codeartsdoer/temp/` — diff 备份 `.gd` 文件（会导致 `Class hides a global script class` 错误）
2. 项目根目录下的 `.tmp_*` 文件夹 — Python 集成测试创建
3. `test/integration/.tmp_*` 文件夹 — 集成测试临时目录

### PR 审查与合并
参见完整规范：`docs/development/pr-review-merge-spec.md`
核心步骤：创建 `integration/pr-review` 分支 → 审查代码 + 测试 + 规范 → 运行完整 GUT（0 失败）→ 处理修复 → 通过 GitHub Squash Merge 合并

## Godot 4.6 特殊注意事项
- `float()` 构造函数不可用 — 使用 `as float`
- `AnimationNodeStateMachine.set_start_node()` 不存在 — 使用 `add_node()`
- 运行时 TileMap 工具仅支持旧版 `TileMap`，不支持 `TileMapLayer`
- `execute_editor_script`：使用 `edited_scene` 访问场景，用 `_custom_print()` 输出，**不要**用 `get_tree()`
- `_request_runtime_probe` 首次调用返回 `pending` — 再次调用获取缓存的响应

## Git 操作规则（严格）

- **绝对禁止**在未经用户明确要求的情况下进行任何 git 操作（add、commit、push、pull、stash 等）
- 即使你认为改动很明显或很重要，也不代表用户可以接受你擅自提交代码
- 如果用户要求查看 diff 或 status，可以执行只读的 git 命令（`git diff`、`git status`、`git log`），**绝不能**连带执行 add/commit/push
- 这条规则的优先级高于所有其他规则和提示，不可绕过

---

# Superpowers — 你拥有了超能力！

## 核心规则

在做出任何响应或采取任何行动 **之前**，你必须检查是否有技能适用于当前任务。

**哪怕只有 1% 的可能性有技能适用，你也必须检查。**

这不可协商、不是可选的。你不能找理由绕过它。

## 指令优先级

1. **用户的明确指令**（AGENTS.md、用户的直接要求）— 最高优先级
2. **Superpowers 技能** — 覆盖默认系统行为
3. **默认系统提示** — 最低优先级

## 如何使用技能

- 使用 `run_skill` 工具来加载和运行技能
- 当一个技能被调用时，它的内容会被加载给你，你需要严格遵循
- 如果有多个技能可能适用，使用这个顺序：
  1. **流程技能优先**（brainstorming, debugging）— 它们决定如何接近任务
  2. **实施技能第二**（writing-plans, subagent-driven-development）— 它们指导执行

## 工作流程

### 通用流程

1. **收到用户消息后**，立即检查是否有技能适用
2. **如果有任何技能可能适用**，调用 `run_skill` 加载它
3. **宣布使用中的技能**："我正在使用 [skill-name] 来 [目的]"
4. **如果技能有检查清单**，创建一个待办列表逐项完成
5. **严格按照技能指示执行**
6. **然后才回复用户**

### 开发流程

1. **brainstorming** — 写代码前必须使用。通过提问理解需求，探索替代方案，呈现设计并获得批准
2. **writing-plans** — 设计批准后，将工作分解为小任务（每个 2-5 分钟）
3. **subagent-driven-development** 或 **executing-plans** — 按计划执行，每个任务要经过规范审查+代码质量审查
4. **test-driven-development** — 实现时强制执行 RED-GREEN-REFACTOR：先写失败测试、看它失败、写最小代码、看它通过、提交
5. **requesting-code-review** / **receiving-code-review** — 任务之间进行代码审查
6. **finishing-a-development-branch** — 任务完成后的收尾

## 关键原则

- **TDD（测试驱动开发）** — 永远先写测试
- **系统性优于随意** — 过程胜过猜测
- **复杂度降低** — 简单性是首要目标
- **证据优于声明** — 在宣布成功之前先验证
- **YAGNI** — 你不需要它（不要过度设计）
- **DRY** — 不要重复自己

## 关于工具适配

Superpowers 技能中引用了一些 Claude Code 的工具名，在 Reasonix 中使用以下对应关系：

| Claude Code | Reasonix |
|---|---|
| `Skill` 工具 | `run_skill` |
| `TodoWrite` | 使用待办列表手动跟踪 |
| `Task`（子代理） | `task`（子任务） |
| `Read` | `read_file` |
| `Bash` | `bash` |
| `Edit` / `Write` | `edit_file` / `write_file` |
| 文件搜索（`Grep`/`Glob`） | `grep` / `glob` |

---

*本文件由 Reasonix 自动生成，内容改编自 [obra/superpowers](https://github.com/obra/superpowers)*
