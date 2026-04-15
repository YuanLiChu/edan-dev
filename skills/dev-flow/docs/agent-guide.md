# Agent 调用指南

本文档提供 Agent 任务模板和调用示例。

---

## ⚠️ 核心规范（强制遵守）

### 工具使用规范

**写入文件必须使用 Write 工具**：

```python
# ✓ 正确：使用 Write 工具
Write(file_path, content=json_data)

# ❌ 错误：使用 Bash + cat + heredoc
Bash(f"cat > {file_path} << 'EOF'\n{json_data}\nEOF")

# ❌ 错误：使用 Bash + echo 重定向
Bash(f"echo '{json_data}' > {file_path}")
```

**原因**：
1. Write 工具会检查文件路径权限
2. Write 工具要求先 Read 文件（如果已存在）
3. Write 工具有更好的错误处理
4. heredoc 格式容易出错，不易调试
5. 绕过了工具的权限和验证机制

**禁止行为**：
- ❌ 使用 `cat > file << 'EOF'` 写入文件
- ❌ 使用 `echo > file` 写入文件
- ❌ 使用任何 Bash 命令写入文件内容

**例外情况**：
- ✓ 可以使用 Bash 创建目录（`mkdir -p`）
- ✓ 可以使用 Bash 执行验证脚本
- ✓ 可以使用 Bash 运行测试命令

---

## Agent 体系

详见 [SKILL.md](../SKILL.md) Agent 体系表格。

---

## Architect Agent

### Phase 0: 初始化

**任务**：项目检测、初始化工作流

详见 [workflow-phases.md](./workflow-phases.md) Phase 0 部分。

---

### Phase 2: 设计方案

#### 任务模板

```markdown
生成多方案设计。

需求分析摘要：[Phase 1输出]

项目上下文：[Phase 0项目信息]

任务：
1. 设计 2-3 个方案
2. 评估每个方案的优缺点
3. 生成 Mermaid 架构图
4. 输出方案对比表

MUST等待主Agent使用AskUserQuestion让用户确认
用户确认后才能继续 Phase 3
```

#### 输出格式示例

```
## 方案 A：[方案名称]

### 架构设计
[Mermaid 架构图]

### 实现要点
1. [要点1]
2. [要点2]

### 优点
- [优点1]

### 缺点
- [缺点1]

---

## 方案对比表

| 维度 | 方案A | 方案B | 方案C |
|------|-------|-------|-------|
| 实现复杂度 | 中 | 低 | 高 |
| 性能 | 高 | 中 | 高 |
| 可测试性 | 高 | 中 | 高 |
```

---

## Coder Agent

### Phase 3: 代码实现

#### ⚠️ 主 Agent 准备工作（关键！）

**调用前必须执行**：

```python
# 1. 读取 state 文件
state = Read(f".dev-flow/{workflow_id}/.state.json")

# 2. 读取 Phase 0 JSON 输出（不是 DevFlow.md）
phase_0_output_file = state["phase_status"][0]["output_files"][0]
phase_0_output = Read(phase_0_output_file)

# 3. 提取完整 rules_info
rules_type = phase_0_output["output"]["rules_info"]["rules_type"]
rules_paths = phase_0_output["output"]["rules_info"]["rules_paths"]

# 4. 提取项目信息
project_type = phase_0_output["output"]["project_info"]["project_type"]
language = phase_0_output["output"]["project_info"]["language"]

# 5. 读取 Phase 2 设计方案
phase_2_output_file = state["phase_status"][2]["output_files"][0]
phase_2_output = Read(phase_2_output_file)
selected_option = state["design"]["selected_option"]
design = phase_2_output["output"]["options"][selected_option]
```

**⚠️ 常见错误**：
- ❌ 只传递 `DevFlow.md` 文件路径（那是给用户看的）
- ❌ 没有读取 `phase-0-*.json` 文件（那是给 Agent 用的）
- ✓ **正确**：读取 JSON 文件，提取完整 rules_info 并嵌入 prompt

---

#### 任务模板

```markdown
任务：完整实现代码（在 Subagent 内部加载 Rules）

设计方案：[Phase 2 确认的方案]

项目上下文（完整JSON）：
{
  "project_type": "Android",
  "language": "Kotlin",
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [
      "/path/to/rules/common/coding-style.md",
      "/path/to/rules/common/patterns.md",
      "/path/to/rules/common/testing.md",
      "/path/to/rules/common/security.md"
    ],
    "language_specific": [
      "/path/to/rules/kotlin/coding-style.md",
      ...
    ]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ TOKEN 优化机制（关键！）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你必须在 Subagent 内部执行：

1. 加载代码规范（如果 rules_type != "NOT_FOUND"）：
   - Read: rules_paths.common[0]  # coding-style.md
   - Read: rules_paths.common[1]  # patterns.md
   - Read: rules_paths.common[2]  # testing.md
   - Read: rules_paths.common[3]  # security.md
   - Read: rules_paths.language_specific[...]

2. 实现功能代码：
   - 遵循 Rules 规范
   - 严格按设计方案实现
   - 业务逻辑独立、可 Mock

3. 输出摘要（简洁，约500字）：
   {
     "files_created": ["src/login/LoginViewModel.kt", ...],
     "files_modified": [...],
     "rules_applied": ["使用空安全", "遵循 Repository 模式"]
   }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 质量检查点

- ✓ 已读取代码规范文件（如果 rules_type != "NOT_FOUND"）
- ✓ 所有设计文件都已实现
- ✓ 代码符合规范检查
- ✓ 可测试性良好（业务逻辑独立）
- ✓ 边界情况已考虑
- ✓ 代码注释清晰

---

## Tester Agent

### Phase 4: 测试编写

#### ⚠️ 主 Agent 准备工作（关键！）

**调用前必须执行**：

```python
# 1. 读取 state 文件
state = Read(f".dev-flow/{workflow_id}/.state.json")

# 2. 读取 Phase 0 JSON 输出（不是 DevFlow.md）
phase_0_output_file = state["phase_status"][0]["output_files"][0]
phase_0_output = Read(phase_0_output_file)

# 3. 提取完整 rules_info
rules_type = phase_0_output["output"]["rules_info"]["rules_type"]
rules_paths = phase_0_output["output"]["rules_info"]["rules_paths"]

# 4. 提取测试框架
test_framework = phase_0_output["output"]["project_info"]["test_framework"]

# 5. 读取 Phase 3 实现文件列表
phase_3_output_file = state["phase_status"][3]["output_files"][0]
phase_3_output = Read(phase_3_output_file)
implementation_files = phase_3_output["output"]["files_created"] + phase_3_output["output"]["files_modified"]
```

**⚠️ 常见错误**：
- ❌ 只传递 `DevFlow.md` 文件路径（那是给用户看的）
- ❌ 没有读取 `phase-0-*.json` 文件（那是给 Agent 用的）
- ✓ **正确**：读取 JSON 文件，提取完整 rules_info 并嵌入 prompt

---

#### 任务模板

```markdown
任务：编写单元测试（在 Subagent 内部加载 Rules + 代码）

Coder Agent 已完成：
- 实现文件：["src/login/LoginViewModel.kt", ...]

项目上下文（完整JSON）：
{
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [...],
    "language_specific": [...]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ TOKEN 优化机制（关键！）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你必须在 Subagent 内部执行：

1. 加载测试规范（如果 rules_type != "NOT_FOUND"）：
   - Read: rules_paths.common[2]  # testing.md
   - Read: rules_paths.language_specific[2]

2. 读取实现代码：
   - Read: Coder 输出的所有文件

3. 编写测试：
   - 覆盖主要功能（≥80%）
   - 包括边界和错误场景

4. 输出摘要（简洁，约500字）：
   {
     "test_files": ["test/LoginViewModelTest.kt", ...],
     "coverage_estimate": 85
   }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 测试质量要求

- ✓ 覆盖率≥80%
- ✓ 正常+边界+异常场景
- ✓ Mock友好

---

## Runner Agent

### Phase 5: 测试执行

#### 任务模板

```markdown
任务：执行测试命令

项目测试框架：[Phase 0检测结果]

测试文件路径：[Tester Agent输出]

任务：
1. 运行测试命令（使用Bash工具）
2. 捕获完整输出
3. 解析结果为JSON格式
4. 返回标准化测试结果

测试命令（根据项目类型）：
- Android: ./gradlew testDebugUnitTest
- Web: npm test
- Python: pytest

参数设置：
- timeout=300s
- 捕获完整输出（stdout + stderr）

输出 JSON 格式：
{
  "status": "pass/fail",
  "total_tests": N,
  "passed_tests": N,
  "failed_tests": N,
  "coverage_percent": N.N,
  "execution_time_seconds": N.N,
  "failures": [
    {
      "test_name": "testMethodName",
      "error_message": "具体错误信息",
      "file_path": "TestFile.kt",
      "line_number": 123,
      "error_type": "assertion/compilation/runtime"
    }
  ]
}
```

---

## Fixer Agent

### Phase 6: 错误分析与增量修复

#### 任务模板

```markdown
任务：分析测试失败原因并增量修复代码

测试失败列表：[Phase 5 Runner Agent输出的failures数组]

实现代码路径：[Coder Agent输出]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 增量修复原则（关键！）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

第一步：错误分析
1. 读取失败测试代码（Read工具）
2. 读取对应实现代码（Read工具）
3. 分析根本原因
4. 分类错误类型：
   - 编译错误：语法、类型、导入错误
   - 逻辑错误：断言失败、结果不符预期
   - 边界错误：空值异常、索引越界
   - 架构错误：多测试失败、模块耦合

第二步：增量修复
- 仅修改 affected_files 中的文件
- 最小改动，不重构其他代码
- 保持代码风格一致

禁止：顺便优化、重构模块、完整重做

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 输出格式

```json
{
  "error_type": "编译/逻辑/边界/架构",
  "root_cause": "根本原因说明",
  "affected_files": ["文件路径"],
  "fix_suggestion": "修复建议",
  "priority": "high/medium/low"
}
```

---

## Agent 调用示例

### Phase 3-4 串行调用

#### Phase 3: Coder Agent

```xml
<function_calls>
<invoke name="Agent">
<parameter name="description">Coder Agent - 实现代码</parameter>
<parameter name="prompt">任务：完整实现代码

设计方案：[Phase 2 确认的方案详情]

项目上下文：
{
  "project_type": "Android",
  "language": "Kotlin",
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [
      "/path/to/rules/common/coding-style.md",
      "/path/to/rules/common/patterns.md",
      "/path/to/rules/common/testing.md",
      "/path/to/rules/common/security.md"
    ],
    "language_specific": [
      "/path/to/rules/kotlin/coding-style.md",
      "/path/to/rules/kotlin/patterns.md",
      "/path/to/rules/kotlin/testing.md",
      "/path/to/rules/kotlin/security.md"
    ]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ TOKEN 优化说明
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你必须在 Subagent 内部执行：

1. 加载代码规范（如果 rules_type != "NOT_FOUND"）：
   - Read: rules_paths.common[0]  # coding-style.md
   - Read: rules_paths.common[1]  # patterns.md
   - Read: rules_paths.common[2]  # testing.md
   - Read: rules_paths.common[3]  # security.md
   - Read: rules_paths.language_specific[...]
   
   ⚠️ 这些 Read 操作在你的 Subagent 内部执行
   ⚠️ Rules token 累积在你的 Subagent 内（不累积到 Main）

2. 实现功能代码：
   - 遵循 Rules 规范
   - 严格按设计方案实现
   - 业务逻辑独立、可 Mock

3. 输出摘要（简洁，约500字）：
   {
     "files_created": ["src/login/LoginViewModel.kt", ...],
     "files_modified": [...],
     "rules_applied": ["使用空安全", "遵循 Repository 模式"]
   }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</parameter>
<parameter name="subagent_type">edan-dev:coder</parameter>
</invoke>
</function_calls>
```

---

#### Phase 4: Tester Agent

```xml
<function_calls>
<invoke name="Agent">
<parameter name="description">Tester Agent - 编写测试</parameter>
<parameter name="prompt">任务：编写单元测试

Coder Agent 已完成：
- 实现文件：["src/login/LoginViewModel.kt", ...]

项目上下文：
{
  "rules_type": "PLUGIN_CACHE",
  "rules_paths": {
    "common": [...],
    "language_specific": [...]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ TOKEN 优化说明
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

你必须在 Subagent 内部执行：

1. 加载测试规范（如果 rules_type != "NOT_FOUND"）：
   - Read: rules_paths.common[2]  # testing.md
   - Read: rules_paths.language_specific[2]

2. 读取实现代码：
   - Read: Coder 输出的所有文件
   
   ⚠️ 这些 Read 操作在你的 Subagent 内部执行

3. 编写测试：
   - 覆盖主要功能（≥80%）
   - 包括边界和错误场景

4. 输出摘要（简洁，约500字）：
   {
     "test_files": ["test/LoginViewModelTest.kt", ...],
     "coverage_estimate": 85
   }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</parameter>
<parameter name="subagent_type">edan-dev:tester</parameter>
</invoke>
</function_calls>
```

---

### Token 优化效果对比

| Phase | 传统方式 | 优化后 | 节省 |
|-------|---------|--------|------|
| Phase 3 (Coder) | ~20k token | ~2k token | 90% |
| Phase 4 (Tester) | ~25k token | ~2k token | 92% |
| **合计** | ~45k token | ~4k token | 91% |

---

## 调用次数控制

### 理想次数
- Architect: 2 次（Phase 0 + Phase 2）
- Coder: ≤2 次（首次实现 + 增量修复）
- Tester: 1 次
- Runner: 2 次（Phase 5 + Phase 6）
- Fixer: ≤5 次（修复循环上限）

### 超次警告
- Coder >2 次：首次实现质量不足，考虑重新设计
- Fixer >5 次：设计有根本问题，必须重新设计

---

## 常见问题

**Q: Rules 路径如何传递？**
A: 
1. 主 Agent 读取 `phase-0-*.json` 文件（不是 `DevFlow.md`）
2. 提取 `rules_info` JSON 对象（完整数据，不是文件路径）
3. 将 `rules_type` 和 `rules_paths` 嵌入 Agent prompt
⚠️ **禁止**：只传递 md 文件路径

**Q: 为什么不能只传递 DevFlow.md？**
A: 
- `DevFlow.md` 是给用户看的文档（markdown 格式）
- `phase-0-*.json` 才是给 Agent 用的数据文件（JSON 格式，包含完整 rules_info）
- 主 Agent 需要读取 JSON 文件提取结构化数据

**Q: Subagent 内部如何读取 Rules？**
A: Subagent 使用 Read 工具读取 Rules 文件，token 累积在 Subagent 内部，销毁后 token 也销毁。

**Q: Agent 间如何传递数据？**
A: 通过 Phase 输出的 JSON 数据，主 Agent 将完整 JSON 嵌入 Agent prompt。

**Q: 串行调用如何执行？**
A: 主 Agent 先调用 Coder，等待完成后再调用 Tester，不使用 run_in_background。

**Q: 如果主 Agent 没有读取 JSON 文件会怎样？**
A: Subagent 收不到 rules 信息，无法加载规范文件，导致：
- 代码不符合项目规范
- 测试不遵循测试规范
- 违反 token 优化机制