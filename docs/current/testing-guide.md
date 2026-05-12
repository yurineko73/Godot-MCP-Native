# 测试指南

本指南详细说明 Godot MCP Native 项目的测试策略、测试工具和最佳实践。

## 目录

1. [测试概述](#测试概述)
2. [单元测试](#单元测试)
3. [集成测试](#集成测试)
4. [性能测试](#性能测试)
5. [端到端测试](#端到端测试)
6. [测试覆盖率](#测试覆盖率)
7. [持续集成](#持续集成)
8. [测试最佳实践](#测试最佳实践)

---

## 测试概述

### 测试金字塔

```
           __
          /  \
         / E2E \   端到端测试（少量，关键路径）
        /______\
       /        \
      / Integration\ 集成测试（中量，API 级别）
     /__________\
    /            \
   /   Unit Tests   \  单元测试（大量，函数级别）
  /________________\
```

### 测试类型

| 测试类型 | 用途 | 工具 | 覆盖率目标 |
|----------|------|------|------------|
| 单元测试 | 测试单个 GDScript 类、工具模块和策略类 | Godot/GUT 风格 GDScript 测试 | 关键工具和边界条件优先 |
| 集成测试 | 通过 MCP/HTTP 流程验证工具组合 | Python | 关键流程 100% |
| 静态检查 | 验证策略、文档或源码约束 | Python | 规则命中 100% |
| 端到端/运行时测试 | 验证运行时探针、输入、截图、动画、音频等完整流程 | Python + Godot HTTP MCP Server | 核心运行时能力 100% |

### 测试目录结构

```
test/
├── quiet_mode_static_check.py          # 免打扰模式静态检查
├── integration/                        # Python 集成流程测试
│   ├── test_batch_scene_node_edits_flow.py
│   ├── test_debug_execution_control_flow.py
│   ├── test_runtime_probe_flow.py
│   ├── test_runtime_viewport_capture_flow.py
│   ├── test_script_symbol_index_flow.py
│   └── ...                             # 资源、输入、动画、音频、TileMap、导出、项目测试等流程
└── unit/                               # GDScript 单元测试
    ├── test_mcp_server_core.gd
    ├── test_mcp_server_native.gd
    ├── test_vibe_coding_policy.gd
    └── tools/
        ├── test_debug_tools.gd
        ├── test_editor_tools.gd
        ├── test_node_tools.gd
        ├── test_project_tools.gd
        ├── test_scene_tools.gd
        └── test_script_tools.gd
```

---

## 单元测试

### GDScript 单元测试

**工具**：GUT (Godot Unit Test) 9.6.0

**配置文件**：`.gutconfig.json`（项目根目录）

```json
{
  "dirs": ["res://test/unit/"],
  "include_subdirs": true,
  "log_level": 2,
  "should_maximize": false,
  "should_exit_on_finish": false,
  "ignore_pause": true,
  "suffix": ".gd",
  "panel_options": {
    "font_size": 14
  }
}
```

**测试目录结构**：
```
test/unit/
├── test_http_parsing.gd
├── test_mcp_auth_manager.gd
├── test_mcp_http_server.gd
├── test_mcp_resource_manager.gd
├── test_mcp_server_core.gd
├── test_mcp_server_native.gd
├── test_mcp_stdio_server.gd
├── test_mcp_transport_base.gd
├── test_mcp_types.gd
├── test_node_tools_convert.gd
├── test_path_validator.gd
├── test_vibe_coding_policy.gd
└── tools/
    ├── test_debug_tools.gd
    ├── test_editor_tools.gd
    ├── test_node_tools.gd
    ├── test_node_tools_enhanced.gd
    ├── test_project_tools.gd
    ├── test_resource_tools.gd
    ├── test_scene_tools.gd
    ├── test_script_editor_debug_tools_enhanced.gd
    └── test_script_tools.gd
```

**当前测试规模**会随新增工具持续变化；以 `test/unit/` 和 `test/integration/` 下的实际文件为准。

**运行测试**：
```powershell
# 命令行运行 GUT 测试
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

**示例测试** (`test/unit/tools/test_node_tools_enhanced.gd`)：
```gdscript
extends "res://addons/gut/test.gd"

var _node_tools: RefCounted = null

func before_each():
    _node_tools = load("res://addons/godot_mcp/tools/node_tools_native.gd").new()

func after_each():
    _node_tools = null

func test_duplicate_node_missing_node_path():
    var result: Dictionary = _node_tools._tool_duplicate_node({})
    assert_has(result, "error", "Should return error for missing node_path")

func test_rename_node_basic():
    var node: Node = Node.new()
    node.name = "OldName"
    add_child_autofree(node)
    node.name = "NewName"
    assert_eq(str(node.name), "NewName", "Node name should be updated")

func test_connect_signal_basic():
    var emitter: Button = Button.new()
    emitter.name = "Button"
    add_child_autofree(emitter)
    var signal_list: Array = emitter.get_signal_list()
    var has_pressed: bool = false
    for sig in signal_list:
        if sig.get("name", "") == "pressed":
            has_pressed = true
            break
    assert_true(has_pressed, "Button should have 'pressed' signal")
```

**GUT 断言方法**：
| 方法 | 用途 |
|------|------|
| `assert_true(condition)` | 断言条件为真 |
| `assert_false(condition)` | 断言条件为假 |
| `assert_eq(a, b)` | 断言相等 |
| `assert_ne(a, b)` | 断言不等 |
| `assert_gt(a, b)` | 断言大于 |
| `assert_lt(a, b)` | 断言小于 |
| `assert_has(dict, key)` | 断言字典包含键 |
| `assert_contains(str, substr)` | 断言字符串包含子串 |

**GUT 注意事项**：
- 使用 `add_child_autofree(node)` 将节点添加到场景树并自动释放
- 不要手动调用 `node.free()`，`add_child_autofree` 会自动处理
- 使用 `load("res://path/to/script.gd").new()` 而非 `ClassName.new()`（CLI 模式下 class_name 不可用）
- `assert_has` 仅适用于 Dictionary 和 Array，不适用于 String

---

## 集成测试

### HTTP 模式集成测试

**工具**：Python + `requests`

当前集成测试集中在 `test/integration/`，覆盖批量节点编辑、脚本符号索引/引用/重命名、项目诊断、资源流水线、运行时探针、运行时输入、截图、动画、音频、TileMap、主题、材质、导出和项目测试运行器等流程。Stdio 传输目前处于开发阶段，集成验证优先使用 HTTP 模式。

**示例测试** (`test/http/test_mcp_http.py`)：
```python
#!/usr/bin/env python3
"""测试 MCP 服务器的 HTTP 模式"""

import requests
import json

BASE_URL = "http://localhost:9080/mcp"
AUTH_TOKEN = "test-token-1234567890"

def test_tools_list():
    """测试 tools/list 端点"""
    response = requests.post(
        BASE_URL,
        json={
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        },
        headers={
            "Authorization": f"Bearer {AUTH_TOKEN}"
        }
    )
    
    assert response.status_code == 200, f"Unexpected status code: {response.status_code}"
    
    data = response.json()
    assert "result" in data, "Missing result in response"
    assert "tools" in data["result"], "Missing tools in result"
    assert len(data["result"]["tools"]) >= 146, "Not enough tools"
    
    print("✓ test_tools_list passed")

def test_unauthorized():
    """测试未授权请求"""
    response = requests.post(
        BASE_URL,
        json={
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        }
        # 不包含 Authorization 头
    )
    
    assert response.status_code == 401 or "error" in response.json(), "Should return 401 or error"
    
    print("✓ test_unauthorized passed")

def test_sse_endpoint():
    """测试 SSE 端点"""
    import sseclient
    
    response = requests.get(
        BASE_URL,
        headers={
            "Accept": "text/event-stream",
            "Authorization": f"Bearer {AUTH_TOKEN}"
        },
        stream=True
    )
    
    assert response.status_code == 200, "SSE connection failed"
    
    client = sseclient.SSEClient(response)
    for event in client.events():
        assert event.event == "connected", "Unexpected event"
        assert "session_id" in event.data, "Missing session_id"
        break  # 仅测试第一个事件
    
    print("✓ test_sse_endpoint passed")

if __name__ == "__main__":
    # 确保服务器正在运行
    test_tools_list()
    test_unauthorized()
    test_sse_endpoint()
    print("\n✓ All HTTP integration tests passed")
```

**运行测试**：
```bash
# 首先启动 HTTP 服务器
godot --path . --mcp-server --http

# 然后运行测试
python test/integration/test_runtime_probe_flow.py
```

---

## 性能测试

### Godot 性能测试

**示例** (`test/benchmark/performance_test.gd`)：
```gdscript
extends SceneTree

# 性能测试配置
const TEST_ITERATIONS: int = 100
const MAX_AVERAGE_TIME_MS: float = 10.0

func _ready() -> void:
	print("=== Godot-MCP Performance Tests ===")
	
	# 测试 1: create_node 性能
	_test_create_node_performance()
	
	# 测试 2: list_nodes 性能
	_test_list_nodes_performance()
	
	# 测试 3: get_node_properties 性能
	_test_get_node_properties_performance()
	
	print("\n✓ All performance tests passed")
	quit()

func _test_create_node_performance() -> void:
	print("\nTest: create_node performance")
	print("  Iterations: " + str(TEST_ITERATIONS))
	
	var tool_instance: NodeToolsNative = NodeToolsNative.new()
	tool_instance.initialize(get_editor_interface())
	
	var total_time: int = 0
	
	for i in range(TEST_ITERATIONS):
		var start_time: int = Time.get_ticks_msec()
		
		var result: Dictionary = tool_instance.create_node({
			"parent_path": "/root",
			"node_type": "Node2D",
			"node_name": "PerfTest" + str(i)
		})
		
		var elapsed: int = Time.get_ticks_msec() - start_time
		total_time += elapsed
		
		assert(result["status"] == "success", "Node creation failed")
	
	var avg_time: float = total_time / float(TEST_ITERATIONS)
	var min_time: int = 0  # TODO: 追踪最小值
	var max_time: int = 0  # TODO: 追踪最大值
	
	print("  Average time: " + str(avg_time) + "ms")
	print("  Total time: " + str(total_time) + "ms")
	
	assert(avg_time < MAX_AVERAGE_TIME_MS, "Performance degradation detected")
	print("  ✓ create_node performance")

func _test_list_nodes_performance() -> void:
	print("\nTest: list_nodes performance")
	# ... 类似实现

func _test_get_node_properties_performance() -> void:
	print("\nTest: get_node_properties performance")
	# ... 类似实现
```

**运行性能测试**：
```bash
"Godot.exe" --path "F:\gitProjects\Godot-MCP" --script "test/benchmark/performance_test.gd"
```

### 负载测试

**工具**：Python + `threading`

**示例** (`test/load/test_concurrent_requests.py`)：
```python
#!/usr/bin/env python3
"""并发负载测试"""

import threading
import requests
import time

BASE_URL = "http://localhost:9080/mcp"
AUTH_TOKEN = "test-token-1234567890"
NUM_THREADS = 10
NUM_REQUESTS_PER_THREAD = 100

def worker(thread_id: int):
    """工作线程函数"""
    results = {"success": 0, "fail": 0}
    
    for i in range(NUM_REQUESTS_PER_THREAD):
        try:
            response = requests.post(
                BASE_URL,
                json={
                    "jsonrpc": "2.0",
                    "method": "tools/list",
                    "id": thread_id * 1000 + i
                },
                headers={
                    "Authorization": f"Bearer {AUTH_TOKEN}"
                },
                timeout=5
            )
            
            if response.status_code == 200:
                results["success"] += 1
            else:
                results["fail"] += 1
        
        except Exception as e:
            results["fail"] += 1
    
    return results

def test_concurrent_requests():
    """测试并发请求"""
    threads = []
    results = []
    
    start_time = time.time()
    
    # 创建并启动线程
    for i in range(NUM_THREADS):
        thread = threading.Thread(target=worker, args=(i,))
        threads.append(thread)
        thread.start()
    
    # 等待所有线程完成
    for thread in threads:
        thread.join()
    
    elapsed = time.time() - start_time
    
    # 汇总结果
    total_success = 0
    total_fail = 0
    
    for result in results:
        total_success += result["success"]
        total_fail += result["fail"]
    
    total_requests = total_success + total_fail
    requests_per_second = total_requests / elapsed
    
    print(f"=== Concurrent Requests Test ===")
    print(f"Threads: {NUM_THREADS}")
    print(f"Requests per thread: {NUM_REQUESTS_PER_THREAD}")
    print(f"Total requests: {total_requests}")
    print(f"Success: {total_success}")
    print(f"Fail: {total_fail}")
    print(f"Elapsed time: {elapsed:.2f}s")
    print(f"Requests/second: {requests_per_second:.2f}")
    
    assert total_fail == 0, "Some requests failed"
    print("✓ Concurrent requests test passed")

if __name__ == "__main__":
    test_concurrent_requests()
```

---

## 测试覆盖率

### GDScript 覆盖率

Godot 没有内置的覆盖率工具，但可以使用以下方法：

**手动追踪**：
```gdscript
var _coverage: Dictionary = {}

func _track_coverage(function_name: String) -> void:
    if not _coverage.has(function_name):
        _coverage[function_name] = 0
    _coverage[function_name] += 1

func _get_coverage_report() -> String:
    var report: String = "Coverage Report:\n"
    for func_name in _coverage:
        report += "  " + func_name + ": " + str(_coverage[func_name]) + " calls\n"
    return report
```

**使用第三方工具**：
- [Gut](https://github.com/bitwes/Gut)：Godot 单元测试框架，包含覆盖率报告

---

## 持续集成

### GitHub Actions 配置

**示例** (`.github/workflows/test.yml`)：
```yaml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        godot-version: ["4.5", "4.6"]

    steps:
      - uses: actions/checkout@v3

      - name: Setup Godot ${{ matrix.godot-version }}
        uses: azure/godot-builds@v1
        with:
          version: ${{ matrix.godot-version }}

      - name: Run GDScript unit tests
        run: |
          godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit

      - name: Run static checks
        run: |
          python test/quiet_mode_static_check.py

      - name: Run HTTP integration tests
        run: |
          # 启动 Godot HTTP MCP 服务器（后台）
          godot --path . --mcp-server --http &
          sleep 5
          for script in test/integration/test_*_flow.py; do
            python "$script"
          done
```

---

## 测试最佳实践

### 1. 测试命名

**好的做法**：
```typescript
describe("createNode", () => {
  it("should create a new node when valid parameters are provided", () => {
    // ...
  });

  it("should return error when node type is invalid", () => {
    // ...
  });
});
```

**避免**：
```typescript
describe("createNode", () => {
  it("test1", () => {
    // ...
  });

  it("test2", () => {
    // ...
  });
});
```

### 2. 测试独立性

**好的做法**：
```typescript
beforeEach(() => {
  // 每个测试前重置状态
  mockGodot.reset();
});

it("should create node", () => {
  // 不依赖其他测试
});
```

**避免**：
```typescript
it("should create node", () => {
  // 依赖前一个测试创建的节点
});
```

### 3. Mock 外部依赖

**好的做法**：
```typescript
// 使用 Mock
const mockGodot = {
  createNode: vi.fn().mockReturnValue({ status: "success" }),
};

const result = await createNode(mockGodot, "/root", "Node2D", "Player");
expect(mockGodot.createNode).toHaveBeenCalled();
```

**避免**：
```typescript
// 依赖真实的 Godot 服务器
const realGodot = new GodotConnection();
const result = await createNode(realGodot, "/root", "Node2D", "Player");
```

### 4. 测试边界条件

**示例**：
```typescript
it("should handle empty string", () => {
  const result = await createNode(mockGodot, "", "Node2D", "Player");
  expect(result.status).toBe("error");
});

it("should handle null", () => {
  const result = await createNode(mockGodot, null, "Node2D", "Player");
  expect(result.status).toBe("error");
});

it("should handle very long node name", () => {
  const longName = "A".repeat(1000);
  const result = await createNode(mockGodot, "/root", "Node2D", longName);
  expect(result.status).toBe("error");
});
```

### 5. 测试错误信息

**示例**：
```typescript
it("should return descriptive error message", async () => {
  const result = await createNode(mockGodot, "/root", "InvalidType", "Test");
  
  expect(result.status).toBe("error");
  expect(result.message).toContain("Invalid node type");
  expect(result.message).toContain("InvalidType");
});
```

---

## 总结

测试是确保代码质量的关键环节。Godot MCP Native 项目采用多层次的测试策略，包括单元测试、集成测试、性能测试和端到端测试。遵循本指南中的最佳实践，可以编写出高质量、可维护的测试代码。

如有任何问题或建议，欢迎在 GitHub Issues 中提出。

**Happy Testing！** 🧪
