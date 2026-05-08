# 工作流程详解

本文档详细说明各 Phase 执行流程。主 Agent 按需加载（执行特定 Phase 时）。

---

## Phase 0: 初始化

### 执行者
**Architect Agent**

### 任务
检测项目架构信息，输出项目信息文档，初始化工作流。

---

### 执行流程

#### 步骤0：检测未完成工作流（主 Agent）

```python
workflow_dirs = Glob(".dev-flow/*/")

if workflow_dirs:
    latest_workflow = sorted(workflow_dirs)[-1]
    state_file = f"{latest_workflow}/.state.json"

    if FileExists(state_file):
        state = Read(state_file)

        if state["status"] in ["in_progress", "pending_confirm", "fix_loop"]:
            # 发现未完成工作流，询问用户
            AskUserQuestion(...)
            # 用户选择：恢复工作流 / 重新开始 / 查看详情
```

---

#### 步骤1：检查项目信息缓存（主 Agent）

```python
project_info_file = ".dev-flow/Project.md"

if FileExists(project_info_file):
    # 项目信息已存在，跳过检测
    cache_used = True
else:
    # 执行完整检测流程
    cache_used = False
```

---

#### 步骤2：初始化工作流（主 Agent）

```python
workflow_id = GetCurrentTimestamp()  # "2026-04-11-16-10-00"

# 创建工作流目录
Bash(f"mkdir -p .dev-flow/{workflow_id}/outputs")

# 初始化 state 文件（使用模板）
import copy
template = Read("templates/state-template.json")
state = copy.deepcopy(template)
state["workflow_id"] = workflow_id

Write(f".dev-flow/{workflow_id}/.state.json", content=state)
```

---

#### 步骤3-7：项目检测（Architect Agent）

**步骤3：目录结构检测**
```python
source_dirs = Glob("src/**/")
qml_dirs    = Glob("qml/**/")
module_dirs = Glob("**/CMakeLists.txt") # 或者 Glob("**/*.pro")
```

**步骤4：语言/框架识别**
```python
# 语言识别规则：
# - 存在 *.cpp/*.h/*.qml 文件 → C++ / Qt
# - 存在 CMakeLists.txt 或 *.pro → C++ Build System
# 架构模式识别：
# - Grep "Q_PROPERTY" 或 "QAbstractItemModel" → Qt Model-View
# - Grep "QObject" → Qt 基于对象的架构
```

**步骤5：架构文档检查**
```python
readme    = Read("README.md")  if FileExists("README.md")
claude_md = Read("CLAUDE.md") if FileExists("CLAUDE.md")
```

**步骤5b：⚠️ 组件与依赖扫描（新增，必须执行）**

```python
# QT/C++ 项目：扫描模块清单 (CMake)
modules = Bash("grep -r \"add_subdirectory\" CMakeLists.txt 2>/dev/null")

# 扫描主要组件（类/对象级别）
components = Grep(r"^(class|struct) \w+", include="*.h", output_mode="filename+match")
# 提取 QML 组件
qml_components = Grep(r"^[A-Z]\w+\s*\{", include="*.qml", output_mode="filename+match")

# 外部依赖扫描 (CMake)
external_deps = Bash("grep -E \"find_package|target_link_libraries\" CMakeLists.txt 2>/dev/null | head -30")

# 构建 arch_snapshot
arch_snapshot = {
    "modules": [],      # 模块列表，详见输出格式
    "components": [],   # 关键组件列表 (C++ Models/Controllers, QML Views)
    "dependencies": {}, # 依赖关系
    "patterns": []      # 已识别的架构模式
}
```

**步骤6：Rules 路径检测（关键！）**

⚠️ **必须调用 detect_rules.sh 脚本**

```python
rules_output = Bash(
    f"bash scripts/detect_rules.sh {PROJECT_DIR}",
    description="检测 Rules 路径"
)
# 输出: RULES_PATH=... / RULES_TYPE=PLUGIN_CACHE / PLUGIN_VERSION=...
rules_info = parse_rules_output(rules_output)
```

**步骤7：构建系统检测**
```bash
# Qt/C++: cmake --version; qmake -v
```

---

#### 步骤8：保存项目信息（主 Agent）

Project.md 格式已规范化，必须包含组件和依赖信息：

```markdown
# 项目架构检测报告

生成时间: {timestamp}

## 基础信息
| 字段 | 值 |
|------|----|
| 项目类型 | Qt Desktop / Embedded / ... |
| 主要语言 | C++ / QML |
| 框架 | Qt 5/6 |
| 构建系统 | CMake / qmake |
| 测试框架 | GTest / QTest |

## 模块结构
| 模块名 | 路径 | 职责说明 |
|--------|------|----------|
| GUI | src/gui/ | 界面表示层，含 QML 资源 |
| Core | src/core/ | 业务核心逻辑，C++ Models |
| ...    | ...  | ... |

## 关键组件
| 组件名 | 类型 | 所属模块 | 关键职责 |
|--------|------|---------|----------|
| PatientModel | QAbstractListModel | Core | 患者列表状态管理 |
| DatabaseService | Service | Core | 数据库访问与存储 |
| MainView | QML Item | GUI | 主界面容器 |
| ...            | ...        | ...  | ... |

## 依赖关系
```
[Mermaid graph 展示模块间依赖]
GUI --> Core
Core --> Database
```

## 外部依赖（关键库）
| 库名 | 版本 | 用途 |
|------|------|------|
| QtNetwork | Qt5/6 | 网络通信 |
| QtSql | Qt5/6 | 数据库支持 |
| ... | ... | ... |

## 关键目录
| 目录类型 | 路径 |
|---------|------|
| 源代码 | src/ |
| QML界面 | qml/ |
| 测试代码 | tests/ |

## 架构模式
{已识别模式：Model-View / Controller / MVC / ...}
```

```python
Write(".dev-flow/Project.md", content=project_info_md)
```

---

#### 步骤9：输出 Phase 0 JSON（主 Agent）

**⚠️ 必须包含 arch_snapshot 字段（新增）**，供 design-phase skill 使用：

```python
phase_0_output = {
    "phase_number": 0,
    "phase_name":   "初始化",
    "output": {
        "project_info": {
            "project_type":  "Qt Desktop/Embedded",
            "language":       "C++ / QML",
            "architecture":   "Model-View",
            "framework":      "Qt 5",
            "build_system":   "CMake",
            "test_framework": "GTest",
            "key_directories": {
                "source": "src/",
                "qml":    "qml/",
                "test":   "tests/",
                "config": "CMakeLists.txt"
            }
        },

        # ⚠️ 新增：架构快照，供 design-phase 使用
        "arch_snapshot": {
            "modules": [
                {"name": "GUI",   "path": "src/gui/",   "role": "UI 入口"},
                {"name": "Core",  "path": "src/core/",  "role": "业务核心"},
                {"name": "Data",  "path": "src/data/",  "role": "数据存储层"}
            ],
            "components": [
                {"name": "PatientModel",    "type": "C++ Model",   "module": "Core",  "file": "src/core/PatientModel.h"},
                {"name": "DatabaseService", "type": "Service",     "module": "Data",  "file": "src/data/DatabaseService.h"},
                {"name": "PatientView",     "type": "QML Component","module": "GUI",   "file": "qml/PatientView.qml"}
            ],
            "dependencies": {
                "module_graph": "GUI → Core → Data",
                "external_key": ["Qt5Core", "Qt5Qml", "Qt5Sql"]
            },
            "patterns": ["Model-View", "Singleton Services"]
        },

        "rules_info": rules_info  # ⚠️ 必须包含步骤6检测结果
    }
}

Write(f".dev-flow/{workflow_id}/outputs/phase-0-initialization.json",
      content=phase_0_output)

# 更新 state
state["phase_status"].append({
    "phase_number":    0,
    "phase_name":      "初始化",
    "status":          "completed",
    "start_time":      start_time,
    "end_time":        end_time,
    "output_files":    [f".dev-flow/{workflow_id}/outputs/phase-0-initialization.json"],
    "execution_notes": f"项目检测完成，缓存使用：{cache_used}，组件数：{len(components)}"
})

Write(f".dev-flow/{workflow_id}/.state.json", content=state)

# ⚠️ 强制验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 0")
Bash(f"bash scripts/validate-state-format.sh {workflow_id}")
```

---

### ⚠️ Phase 0 完成检查清单

主 Agent 必须验证：
1. ✓ JSON 输出文件已生成
2. ✓ state 文件 phase_status 为数组格式
3. ✓ rules_info 来自步骤6检测结果（不是手动构建）
4. ✓ 验证脚本执行通过

---

### 时间预估
- **首次运行（无缓存）**：~2 分钟
- **后续运行（使用缓存）**：~10 秒

---

## Phase 1 + Phase 2: 需求分析 + 设计方案

### ⚠️ 重要：Phase 1 和 Phase 2 由独立的 design-phase skill 执行

**主 Agent 在此阶段的职责**：
1. 读取 Phase 0 输出
2. 调用（或提示用户使用）`edan-dev:design-phase` skill
3. 等待 design-phase skill 完成并输出 Phase 1 + Phase 2 JSON
4. 验证输出后进入 Phase 3

---

### 主 Agent 调用 design-phase

```python
# 读取 Phase 0 输出
state       = Read(f".dev-flow/{workflow_id}/.state.json")
phase_0     = Read(state["phase_status"][0]["output_files"][0])
project_info  = phase_0["output"]["project_info"]
arch_snapshot = phase_0["output"]["arch_snapshot"]   # 组件+依赖快照
rules_info    = phase_0["output"]["rules_info"]

# 调用 design-phase skill（可并行进行用户对话）
# design-phase 内部会执行多轮 AskUserQuestion
# 完成后输出两个文件：
#   .dev-flow/{workflow_id}/outputs/phase-1-requirement-analysis.json
#   .dev-flow/{workflow_id}/outputs/phase-2-design-solutions.json
#   .dev-flow/{workflow_id}/outputs/design-spec.md
```

---

### Phase 1 JSON 输出格式（由 design-phase 写入）

```json
{
  "phase_number": 1,
  "phase_name":   "需求分析",
  "output": {
    "core_requirements": [
      {"id": "R1", "description": "用户可以通过邮箱密码登录", "priority": "must"},
      {"id": "R2", "description": "支持记住密码（7天）",       "priority": "should"}
    ],
    "non_functional_requirements": {
      "performance":  "登录响应 < 2s",
      "offline":      "不需要离线支持",
      "permissions":  "无特殊权限",
      "security":     "密码加密传输"
    },
    "success_criteria": [
      "登录成功后跳转到上次访问页面",
      "连续失败3次锁定账号30秒"
    ],
    "external_context": {
      "source_type": "figma_export",
      "source_file": "docs/design/login.png",
      "ui_components": ["LoginView", "EmailInput", "PasswordInput"],
      "business_rules": ["密码最少8位"],
      "acceptance_criteria": ["错误提示具体说明原因"]
    },
    "clarification_rounds": 3
  }
}
```

---

### Phase 2 JSON 输出格式（由 design-phase 写入）

```json
{
  "phase_number": 2,
  "phase_name":   "设计方案",
  "output": {
    "options": [
      {
        "id":          "A",
        "name":        "C++ Model + QML View",
        "summary":     "新增 LoginModel C++ 类处理逻辑，暴露属性和 Invokable 方法给 QML",
        "mermaid":     "graph TD; LoginView.qml --> LoginModel.cpp --> AuthService.cpp",
        "pros":        ["UI 与逻辑分离", "原生性能良好"],
        "cons":        ["需增加 QML 与 C++ 间绑定代码"],
        "complexity":  "低",
        "affected_components": ["LoginView.qml（新增）", "LoginModel.cpp/h（新增）", "main.qml（修改导航）"]
      }
    ],
    "selected_option": 0,
    "design_spec_file": ".dev-flow/{workflow_id}/outputs/design-spec.md",
    "tech_decisions": {
      "data_storage": "QSettings（记住密码）",
      "networking":   "QNetworkAccessManager",
      "di":           "Singleton Service Locator"
    },
    "affected_components": [
      {"component": "LoginView.qml", "operation": "新增", "module": "GUI"},
      {"component": "LoginModel",    "operation": "新增", "module": "Core"},
      {"component": "main.qml",      "operation": "修改", "module": "GUI", "change": "新增登录路由"}
    ],
    "test_strategy": {
      "type":       "GTest (逻辑) + Qt UI 测试",
      "coverage":   80,
      "key_cases":  ["登录成功", "密码错误", "网络超时", "账号锁定"]
    },
    "impact_analysis": {
      "direct":   ["LoginView.qml", "LoginModel", "AuthService"],
      "indirect": ["main.qml（导航）", "UserContext（状态）"],
      "risks":    ["Navigation 路由层级变更可能影响返回键行为"]
    }
  }
}
```

---

### 进入 Phase 3 前的验证（主 Agent）

```python
# ⚠️ 强制验证两个 Phase 的输出
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 1")
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 2")

# 确认 design-spec.md 存在
spec_file = f".dev-flow/{workflow_id}/outputs/design-spec.md"
assert FileExists(spec_file), "设计规格文档必须存在才能进入 Phase 3"

# 确认 selected_option 已设置
phase_2 = Read(f".dev-flow/{workflow_id}/outputs/phase-2-design-solutions.json")
assert phase_2["output"]["selected_option"] is not None, "必须有用户确认的方案"
```

---

### 时间预估
- **Phase 1（需求澄清）**：5-8 分钟（含多轮用户交互）
- **Phase 2（方案设计+确认）**：8-12 分钟（含 Architect + 多轮确认）
- **合计**：13-20 分钟

---

## Phase 3: 代码实现

### 执行者
**Coder Agent**

### 任务
根据设计方案完整实现功能代码。

---

### ⚠️ 主 Agent 准备工作（关键！）

```python
# 1. 读取 state 文件
state = Read(f".dev-flow/{workflow_id}/.state.json")

# 2. ⚠️ 读取 Phase 0 JSON 输出（不是 DevFlow.md）
phase_0_output_file = state["phase_status"][0]["output_files"][0]
phase_0_output = Read(phase_0_output_file)

# 3. 提取完整 rules_info
rules_type = phase_0_output["output"]["rules_info"]["rules_type"]
rules_paths = phase_0_output["output"]["rules_info"]["rules_paths"]

# 4. 读取 Phase 2 设计方案
phase_2_output_file = state["phase_status"][2]["output_files"][0]
phase_2_output = Read(phase_2_output_file)
design = phase_2_output["output"]["options"][selected_option]
```

---

### Token 优化调用

```xml
<invoke name="Agent">
<parameter name="subagent_type">edan-dev:coder</parameter>
<parameter name="prompt">
任务：完整实现代码

设计方案：[从 Phase 2 JSON 提取]

项目上下文：
{
  "project_type": "...",
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [
      "/path/to/rules/common/coding-style.md",
      "/path/to/rules/common/patterns.md"
    ],
    "language_specific": [...]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ TOKEN 优化机制
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

在 Subagent 内部执行：
1. 加载 Rules（Read rules_paths）
2. 实现功能代码
3. 输出摘要（~500字）

输出格式：
{
  "files_created": [...],
  "files_modified": [...],
  "rules_applied": [...]
}
</parameter>
</invoke>
```

---

### 保存输出（主 Agent）

```python
phase_3_output = {
    "phase_number": 3,
    "output": coder_output
}

Write(f".dev-flow/{workflow_id}/outputs/phase-3-code-implementation.json",
      content=phase_3_output)

state["phase_status"].append({...})
Write(f".dev-flow/{workflow_id}/.state.json", content=state)

# ⚠️ 强制验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 3")
```

---

### ⚠️ Phase 3 完成检查清单

1. ✓ 已读取 `phase-0-*.json` 文件
2. ✓ 已提取完整 `rules_info` JSON 对象
3. ✓ JSON 输出文件已生成
4. ✓ 验证脚本执行通过

---

### 时间预估
~3 分钟

---

## Phase 4: 测试编写

### 执行者
**Tester Agent**

### 任务
读取 Coder 实现的代码，编写完整的单元测试。

---

### ⚠️ 主 Agent 准备工作

```python
# 1. 读取 Phase 0 JSON 输出
phase_0_output = Read(state["phase_status"][0]["output_files"][0])

# 2. 提取 rules_info
rules_info = phase_0_output["output"]["rules_info"]

# 3. 读取 Phase 3 实现文件列表
phase_3_output = Read(state["phase_status"][3]["output_files"][0])
implementation_files = phase_3_output["output"]["files_created"]
```

---

### Token 优化调用

```xml
<invoke name="Agent">
<parameter name="subagent_type">edan-dev:tester</parameter>
<parameter name="prompt">
任务：编写单元测试

Coder Agent 已完成：
- 实现文件：[完整文件路径数组]

项目上下文：
{
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [...],
    "language_specific": [...]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
在 Subagent 内部执行：
1. 加载测试规范（Read rules_paths）
2. 读取实现代码
3. 编写测试（覆盖率 ≥80%）
4. 输出摘要

输出格式：
{
  "test_files": [...],
  "coverage_estimate": 85
}
</parameter>
</invoke>
```

---

### 保存输出（主 Agent）

```python
Write(f".dev-flow/{workflow_id}/outputs/phase-4-test-writing.json",
      content=phase_4_output)

state["phase_status"].append({...})
Write(f".dev-flow/{workflow_id}/.state.json", content=state)

# ⚠️ 强制验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 4")
```

---

### 时间预估
~2 分钟

---

## Phase 5: 测试执行

### 执行者
**Runner Agent**

### 任务
运行测试命令，返回 JSON 结果。

---

### 执行流程

```python
# 读取 Phase 0 和 Phase 4 输出
test_framework = phase_0_output["output"]["project_info"]["test_framework"]
test_files = phase_4_output["output"]["test_files"]
```

---

### 调用 Runner Agent

```xml
<invoke name="Agent">
<parameter name="subagent_type">edan-dev:runner</parameter>
<parameter name="prompt">
任务：执行测试命令

项目测试框架：[JUnit/Jest/pytest]

测试文件路径：[完整文件路径数组]

任务：
1. 运行测试命令（Bash工具）
2. 捕获完整输出
3. 解析结果为JSON格式

测试命令：
- Android: ./gradlew testDebugUnitTest
- Web: npm test
- Python: pytest

参数：timeout=300s

输出 JSON 格式：
{
  "status": "pass/fail",
  "total_tests": N,
  "passed_tests": N,
  "failed_tests": N,
  "coverage_percent": N.N,
  "failures": [
    {
      "test_name": "...",
      "error_message": "...",
      "file_path": "...",
      "line_number": 123
    }
  ]
}
</parameter>
</invoke>
```

---

### 保存输出与决策逻辑（主 Agent）

```python
Write(f".dev-flow/{workflow_id}/outputs/phase-5-test-execution.json",
      content=runner_output)

state["phase_status"].append({...})
Write(f".dev-flow/{workflow_id}/.state.json", content=state)

# ⚠️ 强制验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 5")

# 决策：根据测试结果判断
if runner_output["status"] == "pass" and runner_output["coverage_percent"] >= 80:
    # 测试通过 → Phase 7（输出报告）
else:
    # 测试失败 → Phase 6（修复循环）
```

---

### 时间预估
~2 分钟

---

## Phase 6: 修复循环

### 执行者
**Fixer Agent** + **Runner Agent**

### 任务
分析测试失败原因，增量修复代码，最多循环5次。

---

### 修复循环流程

```python
iteration = 0
max_iterations = 5

while iteration < max_iterations:
    # 1. 调用 Fixer Agent
    fixer_output = Agent(...)

    # 2. 调用 Runner Agent（重测）
    runner_output = Agent(...)

    # 3. 保存 Phase 6 输出（当前循环）
    Write(f".dev-flow/{workflow_id}/outputs/phase-6-fix-loop-{iteration}.json", ...)

    # 4. 判断结果
    if runner_output["status"] == "pass":
        break

    iteration += 1

# 判断是否达到上限
if iteration >= max_iterations:
    print("修复循环达到上限，建议重新设计")
```

---

### 调用 Fixer Agent

```xml
<invoke name="Agent">
<parameter name="subagent_type">edan-dev:fixer</parameter>
<parameter name="prompt">
任务：分析测试失败原因并增量修复代码

测试失败列表：[Phase 5 failures 数组]

实现代码路径：[Coder Agent 输出]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 增量修复原则（关键！）

第一步：错误分析
1. 读取失败测试代码
2. 读取对应实现代码
3. 分析根本原因
4. 分类错误类型：
   - 编译错误
   - 逻辑错误
   - 边界错误
   - 架构错误

第二步：增量修复
- 仅修改 affected_files
- 最小改动，不重构
- 保持代码风格一致

禁止：顺便优化、重构模块

输出格式：
{
  "error_type": "编译/逻辑/边界/架构",
  "root_cause": "...",
  "affected_files": [...],
  "fix_suggestion": "..."
}
</parameter>
</invoke>
```

---

### 时间预估
- **单次循环**：~1.5 分钟
- **多次循环（≤5次）**：正常修复

---

## Phase 7: 输出报告

### 执行者
**主 Agent**

### 任务
输出最终完成报告，更新 state 为完成状态。

---

### 执行流程

```python
# 1. 读取 state 和所有前序 Phase 输出
state = Read(f".dev-flow/{workflow_id}/.state.json")

# 2. 从 phase_status 读取所有 Phase 输出
phase_outputs = {}
for phase_record in state["phase_status"]:
    phase_file = phase_record["output_files"][0]
    phase_outputs[phase_record["phase_number"]] = Read(phase_file)

# 3. 读取报告模板
template = Read("templates/completion-report.md")

# 4. 输出最终报告
phase_7_output = {
    "phase_number": 7,
    "output": {
        "status": "success",
        "workflow_id": state["workflow_id"],
        "summary": {...},
        "files_created": state["implementation"]["files_created"],
        "test_results": state["testing"],
        "agent_statistics": state["agent_calls"]
    }
}

Write(f".dev-flow/{workflow_id}/outputs/phase-7-completion-report.json",
      content=phase_7_output)

# 5. 更新 state 文件为完成状态
state["status"] = "completed"
state["phase_status"].append({...})
Write(f".dev-flow/{workflow_id}/.state.json", content=state)

# ⚠️ 强制验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} 7")
```

---

### 时间预估
~1 分钟

---

## 会话恢复机制

详见：`docs/session-recovery.md`

---

## 关键原则

### Phase 2 用户确认
- 设计方案必须用户确认
- 不能代用户决定，不能跳过确认

### Phase 6 增量修复
- Fixer 只修复具体错误，不重构其他代码
- 每次修复遵循最小改动原则

### Rules 加载
- 所有 Agent 执行前读取 rules 文件（如果存在）
- Rules 路径在 Subagent 内部使用 Read 加载

### 强制验证
- 每个 Phase 结束后必须验证
- 验证失败立即停止工作流