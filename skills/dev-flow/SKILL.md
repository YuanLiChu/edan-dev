---
name: dev-flow
description: "Use when implementing a new feature, module, or system that needs full development pipeline: design approval, implementation, testing ≥80% coverage, and bug fixing. NOT for simple fixes, debugging, code reading, or quick scripts. 中文触发词：开发新功能/模块/系统、完整开发流程。"
argument-hint: "<功能描述> [--max-retries=N]"
allowed-tools: ["Bash", "Read", "Glob", "Grep", "Agent", "AskUserQuestion", "Write"]
---

# Dev Flow - 完整开发流水线

主 Agent 协调 + 专业 Agent 执行。工作流分为**两个独立阶段**，第一阶段（设计）完成并获用户批准后才进入第二阶段（实现）。

---

## 工作流程

### 阶段一：设计（design-phase skill）

```
Phase 0: 初始化        → Architect 扫描项目，输出 arch_snapshot
Phase 1: 需求分析      → 多轮 AskUserQuestion 澄清需求（含外部文档解析）
Phase 2: 方案设计      → Architect 生成方案 → 逐节 AskUserQuestion 确认
                        → 用户批准 design-spec.md → 才能进入阶段二
```

### 阶段二：实现（dev-flow 继续执行）

```
Phase 3: 代码实现      → Coder Agent（加载 Rules + 小步实现）
Phase 4: 测试编写      → Tester Agent（覆盖率 ≥ 80%）
Phase 5: 测试执行      → Runner Agent 运行 + 编译检查
Phase 6: 修复循环      → Fixer + Runner 最多5次
Phase 7: 输出报告      → 变更影响分析 + 统计
```

> 🔒 **阶段门控**：design-spec.md 未经用户批准 → Phase 3 不得启动

---

## Agent 体系

| Agent | 调用阶段 | 核心职责 |
|-------|---------|----------|
| **Architect** | Phase 0, Phase 2 | 扫描 arch_snapshot；读外部文档；设计多方案 |
| **Coder** | Phase 3 | 加载 Rules（验证读取），小步实现 |
| **Tester** | Phase 4 | 编写测试，覆盖率 ≥ 80% |
| **Runner** | Phase 5, 6 | 运行测试 + 编译验证，返回 JSON |
| **Fixer** | Phase 6 | 根因分析，增量修复 |
| **Compiler** | Phase 3, 4 | 每次改动后验证编译通过 |

---

## ⚠️ 核心规范（强制遵守）

### 1. 工具使用规范

**写入文件必须使用 Write 工具**（禁止 Bash + cat/echo/heredoc 写文件）。

**允许例外**：`mkdir -p`、`bash scripts/*.sh`、`./gradlew test`

详见：`docs/agent-guide.md`

---

### 2. 强制验证机制

**每个 Phase 结束后必须验证**：

```python
Bash(f"bash scripts/validate-phase-output.sh {workflow_id} {phase_number}")
```

验证失败 → 立即停止工作流。详见：`docs/workflow-phases.md`

---

### 3. Rules 加载原则（Token 优化）

Subagent 内部读取 Rules（不累积到主 Agent）→ 节省 91% token。

**主 Agent 必须**：读取 `phase-0-*.json` → 提取 `rules_info` → 嵌入 Subagent prompt。

详见：`docs/agent-guide.md`

---

### 4. 设计阶段门控

```
设计规格（design-spec.md）未经用户批准 → Phase 3 不得启动
```

- design-phase skill 负责多轮 AskUserQuestion，直到用户明确批准
- Phase 3 启动前必须验证 `design-spec.md` 存在且 `selected_option` 非空

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