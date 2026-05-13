# AGENTS.md - Godot MCP Project Guidelines

## Build & Run Commands
- **Run Godot Project**: Open project.godot in Godot Editor

## Code Style Guidelines

### GDScript (Godot)
- Use snake_case for variables, methods, and function names
- Use PascalCase for classes
- Use type hints where possible: `var player: Player`
- Follow Godot singleton conventions (e.g., `Engine`, `OS`)
- Prefer signals for communication between nodes

### General
- Use descriptive names
- Keep functions small and focused
- Add comments for complex logic
- Error handling: use assertions in GDScript

### 测试规范（强制）
每次修改代码必须在 `test/` 中更新或创建对应的测试用例：
- **直接测试**：覆盖本次改动的逻辑（正常路径 + 边界条件 + 错误处理）
- **影响范围测试**：识别并测试可能被本次改动影响的关联模块（如修改了公共方法签名、导出变量、信号、策略类等，需覆盖所有调用方）
- 禁止提交仅有代码改动而无测试更新的 commit

## New Tool Workflow

When creating a new MCP tool, you MUST complete ALL of the following steps:

### Step 1: Implement the tool handler
In the appropriate `*_tools_native.gd` file under `addons/godot_mcp/tools/`:
- Create `_register_<tool_name>(server_core)` and `_tool_<tool_name>(params) -> Dictionary` functions
- Call `server_core.register_tool()` with **8 arguments** (including category and group):
  ```
  server_core.register_tool(
      "tool_name",                    # 1. name
      "Description...",               # 2. description
      input_schema,                   # 3. input schema dict
      Callable(self, "_tool_..."),    # 4. callable
      output_schema,                  # 5. output schema dict
      annotations_dict,               # 6. annotations
      "core"/"supplementary",         # 7. category
      "Group-Name"                    # 8. group (use "X-Advanced" for supplementary)
  )
  ```
  - **core** tools: used for basic operations, always visible
  - **supplementary** tools: advanced features, require opt-in via tool management panel

### Step 2: Register in tool classifier
Edit `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd`:
- Add `{"name": "tool_name", "category": "core"/"supplementary", "group": "Group-Name"}` entry in `_build_classifications()` array
- Then update `test/unit/test_mcp_tool_classifier.gd`:
  - Update `test_all_205_tools_registered` with the new total count (increment by 1)
  - Update `test_core_tools_count_within_limit` or `test_supplementary_tools_count` accordingly
  - If supplementary, add `assert_true(_classifier.is_supplementary_tool("tool_name"), "...")` assertion

### Step 3: Add unit tests
In `test/unit/tools/` or `test/unit/`:
- Create or extend a test file following `extends "res://addons/gut/test.gd"`
- Use `load("res://addons/godot_mcp/tools/...").new()` instead of class_name (GUT CLI mode limitation)
- Cover: missing params → returns error, invalid params → returns error, edge cases
- Reference GUT patterns in `.trae/skills/gut-mcp-testing/SKILL.md`
- Run tests: `& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit`

### Step 4: Update tool documentation
Edit `docs/current/tools-reference.md`:
- Update the overview table with new tool count (adjust rows as needed)
- Add a new tool entry following the existing format:

### Step 4b: Update addon READMEs
Edit `addons/godot_mcp/README.md` and `addons/godot_mcp/README.zh.md`:
- Update the tool counts and descriptions in the overview section to match the new total
- If a new tool category group was added, add a corresponding section row in the feature table
- Ensure English and Chinese versions stay in sync

### Step 4c: Write the tool entry
  ```
  ### N. tool_name
  
  Description...
  
  **参数**：
  | 参数 | 类型 | 必需 | 描述 |
  ...
  
  **返回值**：
  | 字段 | 类型 | 描述 |
  ...
  
  **注解**：`readOnlyHint=...`, `destructiveHint=...`, `idempotentHint=...`, `openWorldHint=...`
  
  ---
  ```
- Update the summary line at the end with the correct total count

### Step 5: Verify
- Run full GUT test suite (command in Step 3)
- Verify 0 failures before committing

## PR 审查与合并流程

参见完整规范文档：
- **Skill 文件：** `.cursor/skills/pr-review-merge/SKILL.md`
- **规范文档：** `docs/development/pr-review-merge-spec.md`

核心步骤：
1. 创建集成分支 `integration/pr-review`，合并 PR 代码
2. 逐文件审查代码、测试覆盖、规范
3. 运行 GUT 全量测试（0 failures 为硬性要求）
4. 阻断问题 → Request Changes 退回 PR 作者；小修复 → 直接推送到 PR head 分支
5. 修复后重新验证，记录审查文档
6. 通过 GitHub Squash Merge 合并 PR（PR 自动关闭）
7. 清理本地集成分支

注意：`_debounce_save()` 必须在 UI toggle handler 中调用，否则设置无法持久化。

## Repository Baseline

- All text files created or modified in this repository must be saved as UTF-8 without BOM.
- This applies in particular to source files, Godot text resources, configs, docs, tests, fixtures, and automation files such as `.gd`, `.tscn`, `.tres`, `.cfg`, `.md`, `.json`, `.yaml`, `.yml`, `.py`, `.sh`, `.toml`, `.ts`, `.tsx`, `.js`, `.cs`, `.cpp`, and `.h`.
- Do not introduce UTF-8 with BOM, UTF-16, GBK, ANSI, or editor-default legacy encodings unless the repository already requires a different encoding and the user explicitly asks you to preserve it.

- The repository encoding baseline is `.editorconfig`, `.gitattributes`, `scripts/check_utf8_bom.py`, and `.pre-commit-config.yaml` or CI enforcement.
- Check and repair that baseline once at the first write opportunity in a repository work session or `/goal`; do not re-check the same baseline after every small task.
- If any baseline component is missing, add the smallest compatible repository-local version.
- Prefer extending existing enforcement over creating parallel mechanisms.
- Do not replace stronger existing repository policy with a weaker baseline.

- For non-goal tasks, if Codex changed text files, run an appropriate encoding verification before claiming completion:
  - Prefer scripts/check_utf8_bom.py when cheap.
  - Otherwise run a changed-files encoding check over modified, staged, and untracked text files.
  - Include untracked files; git diff alone is not sufficient for newly created files.

- During `/goal` execution, treat encoding enforcement as a goal-level gate:
  - Do not run repo-wide `scripts/check_utf8_bom.py` after every small task.
  - Worker tasks must still write any touched text files as UTF-8 without BOM.
  - Run a changed-files encoding check only when a task bulk-generates text, changes encoding policy/checkers, migrates many text resources, or receives an explicit verify command for it.
  - Before marking the full goal complete, run `scripts/check_utf8_bom.py` or an equivalent check against the full changed set, including untracked files; a repo-wide run is acceptable when cheap.
- Do not create manual per-task file ledgers solely for encoding checks; use Git (`git diff`, `git diff --cached`, and `git ls-files --others --exclude-standard`) when changed-file discovery is needed.

## Token-Efficiency Rules

- Treat MCP token efficiency as a repository-wide development rule for existing tools, new tools, docs, tests, and future capability-gap work.
- Default responses may be smaller, but they must never silently imply completeness when data is omitted.
- Any bounded or partial result must expose explicit continuation metadata such as `truncated`, `has_more`, `next_cursor`, `next_max_results`, or another domain-appropriate equivalent.
- Prefer bounded output and progressive disclosure from the start: `max_items`, `max_results`, `max_depth`, `count/offset`, summary/detail shapes, and stable rerun hints should be part of tool design when results can grow large.
- Do not force unnecessary extra round trips for small results. Small complete results should still return directly.
- High-risk writes, destructive actions, and final judgments must fetch fuller detail when summary data is insufficient.
- When retrofitting an existing tool, keep exact-fit pages truthful: reaching a limit is not enough to claim `has_more=true` unless there is concrete evidence that more data exists.
- Tool docs and tests must stay aligned with these rules. Any new truncation, pagination, summary/detail, or rerun-hint contract must be reflected in `docs/current/tools-reference.md` and covered by focused regression tests.
