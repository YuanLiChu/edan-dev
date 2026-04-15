---
name: dev-flow
description: "完整开发流水线 —— 从架构检测到测试修复的全流程自动化。TRIGGER when: 用户提到 '开发'/'实现'/'添加' + '功能'/'模块'/'系统'，且需要 '完整流程'/'测试'/'设计'。DO NOT TRIGGER when: '简单'/'快速'/'临时'修改、'修复bug'/'调试'、'理解'/'查看'代码、'小脚本'/'简单工具'。"
argument-hint: "<功能描述> [--max-retries=N]"
allowed-tools: ["Bash", "Read", "Glob", "Grep", "Agent", "AskUserQuestion", "Write"]
---

# Dev Flow - 完整开发流水线

主 Agent 协调 + 专业 Agent 执行，完成架构检测→需求分析→设计→实现→测试→修复流程，测试覆盖率≥80%。

目标耗时：10-12 分钟

---

## 何时使用

**适用场景**：
- 需要完整开发流程（设计→实现→测试→修复）
- 需要测试覆盖率保证（≥80%）
- 需要多方案设计对比

**不适用**：
- 简单脚本、临时修改（无测试需求）
- 修复 bug、调试代码
- 理解代码、查看文档

---

## 工作流程

```
Phase 0: 初始化        → 项目检测、初始化 state
Phase 1: 需求分析      → 解析功能描述、确认需求
Phase 2: 设计方案      → 多方案对比 → 用户确认
Phase 3: 代码实现      → Coder Agent 完整实现
Phase 4: 测试编写      → Tester Agent 编写测试
Phase 5: 测试执行      → Runner Agent 运行测试
Phase 6: 修复循环      → Fixer + Runner 最多5次
Phase 7: 输出报告      → 完成报告、统计信息
```

---

## Agent 体系

| Agent | 调用时机 | 核心职责 |
|-------|---------|---------|
| **Architect** | Phase 0, 2 | 项目检测、多方案对比 |
| **Coder** | Phase 3 | 加载 Rules、完整实现 |
| **Tester** | Phase 4 | 覆盖主要功能（≥80%） |
| **Runner** | Phase 5, 6 | 执行测试、返回 JSON 结果 |
| **Fixer** | Phase 6 | 分析失败原因、增量修复 |

---

## ⚠️ 核心规范（强制遵守）

### 1. 工具使用规范

**写入文件必须使用 Write 工具**：
```python
# ✓ 正确
Write(file_path, content=json_data)

# ❌ 错误：使用 Bash + cat + heredoc
Bash(f"cat > {file_path} << 'EOF'\n{json_data}\nEOF")
```

**禁止行为**：
- ❌ Bash 命令写入文件内容（cat、echo、printf）
- ❌ 绕过 Write 工具权限验证

**允许例外**：
- ✓ `mkdir -p`（创建目录）
- ✓ `bash scripts/*.sh`（验证脚本）
- ✓ `./gradlew test`（执行测试）

---

### 2. 强制验证机制

**每个 Phase 结束后必须验证**：
```python
# Phase 输出验证
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} {phase_number}")

# State 格式验证（Phase 0）
Bash(f"bash scripts/validate-state-format.sh {workflow_id}")

# 验证失败 → 立即停止工作流
```

**验证内容**：
- ✓ JSON 输出文件是否存在
- ✓ state 文件 phase_status 格式（数组）
- ✓ 必需字段完整（phase_number、output_files 等）
- ✓ JSON 输出内容完整

---

### 3. Rules 加载原则

**主 Agent 调用 Subagent 时**：
1. 读取 `phase-0-*.json` 文件（不是 DevFlow.md）
2. 提取 `rules_info` JSON 对象
3. 将 `rules_type` 和 `rules_paths` 嵌入 Agent prompt

**Subagent 内部读取 Rules**：
- Rules token 累积在 Subagent 内（不累积到 Main）
- Subagent 销毁后，Rules token 也销毁

**Token 优化效果**：节省 91% token

详见：`docs/agent-guide.md`

---

### 4. Phase 2 用户确认

**设计方案必须用户确认**：
- Architect Agent 生成多方案对比
- 主 Agent 使用 AskUserQuestion 提交方案
- 用户选择后才能继续 Phase 3

**禁止跳过确认**：不能代用户决定方案

---

## 状态管理

### 文件结构

```
.dev-flow/
├── Project.md                    # 项目信息（跨工作流共享）
└── {workflow_id}/                # YYYY-MM-DD-HH-MM-SS
    ├── .state.json               # 工作流状态
    └── outputs/
        ├── phase-0-*.json        # 各 Phase JSON 输出
        ├── phase-1-*.json
        └── ...
```

### 项目信息缓存

- **首次运行**：Phase 0 完整检测 → Project.md（~2分钟）
- **后续运行**：读取 Project.md → 跳过检测（~10秒）
- **架构变更**：删除 Project.md 重新检测

### 会话恢复

skill 启动时自动检测未完成工作流，询问用户：
- 恢复工作流（从 current_phase 继续）
- 重新开始（备份旧工作流）
- 查看详情（输出执行记录）

详见：`docs/workflow-phases.md`

---

## 质量标准

**完成标准**：
- ✓ 设计方案经用户确认
- ✓ 测试覆盖率 ≥ 80%
- ✓ 所有测试通过
- ✓ 代码规范检查通过

**警告信号**：
- 修复循环 > 5 次 → 停止，重新设计
- Coder 调用 > 2 次 → 检查设计问题
- 时间压力不降低测试覆盖率标准

---

## 文档资源（按需加载）

执行特定 Phase 时按需加载：

- **docs/workflow-phases.md** - Phase 详细流程、状态管理、恢复机制
- **docs/agent-guide.md** - Agent 任务模板、调用示例、Rules 加载
- **templates/state-template.json** - State 文件模板（Phase 0）
- **templates/phase-output-template.json** - Phase 输出模板
- **scripts/validate-phase-output.sh** - Phase 输出验证脚本
- **scripts/validate-state-format.sh** - State 格式验证脚本

---

## 主 Agent 职责

**做**：
- ✓ 分析需求
- ✓ 协调 Agent（串行调用）
- ✓ 决策（测试结果判断）
- ✓ 状态管理（读写 state）
- ✓ 用户交互（Phase 2 确认）
- ✓ 验证输出完整性

**不做**：
- ❌ 编写源代码（Coder Agent）
- ❌ 编写测试（Tester Agent）
- ❌ 运行测试（Runner Agent）
- ❌ 修复代码（Fixer Agent）

**原则**：主 Agent 协调，专业 Agent 执行