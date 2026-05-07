---
name: design-phase
description: Use when starting a new feature, module, or system development and you need to analyze requirements, review external design documents (Figma/doc/pdf), and produce an approved design spec before coding begins; not for simple fixes or when design has already been approved
argument-hint: "<功能描述> [--context=<外部文档路径>]"
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent", "AskUserQuestion", "Write"]
---

# Design Phase - 需求分析 + 方案设计

将开发请求转化为经用户充分确认的设计方案。**禁止在用户批准设计前触发任何代码实现。**

目标耗时：8-15 分钟（含多轮用户交互）

---

## ⚠️ Iron Law

```
NO CODE WITHOUT APPROVED DESIGN SPEC
```

设计方案未经用户逐节确认 → 不得进入 Phase 3 实现阶段。

---

## 工作流程

```
Step 1: 读取项目上下文      → Phase 0 输出 + 外部文档
Step 2: 需求澄清（多轮）   → AskUserQuestion × N
Step 3: 外部文档解析        → Figma/doc/pdf 提取关键信息
Step 4: 生成候选方案        → Architect Agent → 2-3 方案
Step 5: 方案逐节确认        → AskUserQuestion × 方案维度
Step 6: 写设计规格文档      → design-spec.md
Step 7: 用户审阅规格文档    → 最终 AskUserQuestion
Step 8: 输出 Phase 1+2 JSON → 交接给 dev-flow Phase 3
```

---

## Step 0: 设计上下文初始化（前置）

在读取项目具体信息前，先调用 design-context skill 建立全局设计上下文：

```python
# 调用 design-context skill 检测 project.md 和外挂文件夹
design_context = Agent(
    subagent_type="edan-dev:design-context",
    prompt="检测 project.md 和外挂文件夹，输出设计上下文摘要"
)

# 结果注入后续步骤
project_md_info = design_context["project_md"]           # project.md 检测/读取结果
attachments_info = design_context["attachments"]         # 外挂文件夹扫描结果
```

> ⚠️ **注意**：若 project.md 不存在，design-context 会提示用户生成。
> 若用户选择跳过，必须在 Step 2 的需求澄清中额外确认架构假设。

---

## Step 1: 读取项目上下文

```python
# 1. 读取 Phase 0 输出（必须）
state = Read(f".dev-flow/{workflow_id}/.state.json")
phase_0 = Read(state["phase_status"][0]["output_files"][0])
project_info  = phase_0["output"]["project_info"]
arch_snapshot = phase_0["output"]["arch_snapshot"]   # 组件 + 依赖关系图
rules_info    = phase_0["output"]["rules_info"]

# 2. 合并 design-context 输出（project.md 摘要）
if project_md_info and project_md_info.get("exists"):
    project_summary = project_md_info.get("summary", "")
    # 将 project.md 摘要纳入需求分析上下文

# 3. 扫描用户提供的外部文档（详见 Step 3 和 docs/external-context-guide.md）
# 包括外挂文件夹中的文档 + 用户显式提供的路径
```

---

## Step 2: 需求澄清（多轮 AskUserQuestion）

**原则（参考 superpowers:brainstorming）**：
- 每次只问 **一个问题**，不捆绑提问
- 优先用**选项题**而非开放题
- 先问范围/目标，再问细节/约束

**必问清单**（按序，可根据用户答案跳过）：

```
Q1. 功能范围 — 本次只做哪些，明确不做哪些？
Q2. 功能入口 — 用户如何触发（入口页面/按钮/API）？
Q3. 数据依赖 — 依赖哪些现有数据/接口/服务？
Q4. 非功能需求 — 性能、离线、权限等特殊要求？
Q5. 成功标准 — 如何验证"做好了"？
```

**AskUserQuestion 示例**：

```python
AskUserQuestion(questions=[{
    "question": "这个功能的用户入口是哪里？",
    "header":   "需求澄清 (2/5)",
    "options": [
        {"label": "现有页面新增按钮", "description": "在已有界面中嵌入"},
        {"label": "独立新页面",        "description": "新建路由和页面"},
        {"label": "后台接口",          "description": "纯 API，无 UI"}
    ]
}])
```

**收到回答后**：更新需求理解，决定是否追问，继续下一个问题。

---

## Step 3: 外部文档解析（按需）

若用户提供了外部参考文档，由 Architect Agent 解析：

详见 `docs/external-context-guide.md`

### 3a. 自动发现外挂文件夹文档

在调用 Architect Agent 之前，先扫描外挂文件夹（来自 Step 0 的 design-context 输出）：

```python
# 获取 design-context 扫描到的附件列表
attachment_files = attachments_info.get("files", {})

# 自动纳入解析的文件
auto_discovered = []
for category, files in attachment_files.items():
    if category in ["ui_screenshots", "requirements", "figma_exports", "api_specs"]:
        auto_discovered.extend(files)

# 向用户报告自动发现的文档
if auto_discovered:
    print(f"📎 从外挂文件夹自动发现 {len(auto_discovered)} 个外部文档，将纳入设计分析。")
```

### 3b. 用户显式提供的外部文档

| 格式 | 解析方式 | 提取内容 |
|------|---------|---------|
| Figma MCP 服务 | 访问 MCP 接口读取，若失败则退回请求用户提供截图 | 组件结构、交互状态、色彩规格 |
| Figma 截图 (PNG) | Read 直接读取，描述 UI 布局 | 组件结构、交互状态、色彩规格 |
| Word/PDF 导出 txt/md | Read 读取文本内容 | 功能描述、验收标准、业务规则 |
| Markdown 文档 | Read 直接读取 | 接口定义、数据模型 |
| 截图 PNG | Read 读取，分析 UI | 布局参考、组件位置 |

**解析输出格式**（纳入需求分析）：

```json
{
  "external_context": {
    "source_type": "figma_export | doc | pdf | screenshot",
    "source_file": "path/to/file",
    "ui_components": ["登录按钮", "表单", "导航栏"],
    "interaction_flows": ["点击登录 → 验证 → 跳转首页"],
    "business_rules": ["密码至少8位", "邮箱唯一性校验"],
    "acceptance_criteria": ["登录失败显示具体错误信息"]
  }
}
```

---

## Step 4: 生成候选方案（Architect Agent）

```python
# 调用 Architect Agent，传入完整上下文
architect_output = Agent(
    subagent_type="edan-dev:architect",
    prompt=f"""
任务：生成 2-3 个候选设计方案

需求摘要：
{requirements_summary}

项目架构快照：
{json.dumps(arch_snapshot, ensure_ascii=False)}

外部文档提取（如有）：
{json.dumps(external_context, ensure_ascii=False)}

输出要求：
1. 每个方案必须包含：
   - 方案名称和核心思路（1-2句）
   - Mermaid 组件关系图
   - 影响的现有组件（与 arch_snapshot 对应）
   - 新增/修改的文件列表（估算）
   - 优缺点（各2-3条）
   - 预估实现复杂度：低/中/高

2. 方案对比表（维度：实现复杂度/可测试性/对现有代码影响/性能）

3. 架构师推荐方案及理由
"""
)

# -----------------
# 注入：自动审查闭环逻辑
# -----------------
loop_count = 0
max_retries = 3

while loop_count < max_retries:
    # 唤起 Reviewer 专家对架构师设计的方案进行计分和短板筛查
    review_context = Agent(
        subagent_type="edan-dev:design-reviewer",
        prompt=f"【要求检查如下内容】：\n架构原始需求: {requirements_summary}\n生成的候选方案内容: {architect_output}\n请按JSON格式输出评估。"
    )
    
    score = review_context.get("score", 0)
    if score >= 90:
        print(f"✅ Reviewer: 方案得分 {score}，架构质量已闭环通过审查。")
        break
        
    print(f"⚠️ Reviewer: 方案得分 {score}，驳回，重新唤醒架构师修正...")
    # 把意见返回给 Architect 进行修补
    architect_output = Agent(
        subagent_type="edan-dev:architect",
        prompt=f"上次的方案被打回。Reviewer给出的遗漏条目：{review_context.get('unclosed_requirements')}。改进建议：{review_context.get('improvement_suggestions')}。请在这个基础上全面优化并重新输出候选方案！"
    )
    loop_count += 1
```

---

## Step 5: 方案逐节确认（多轮 AskUserQuestion）

**不可跳过、不可合并**，按顺序逐节：

### 5a. 选择候选方案

```python
AskUserQuestion(questions=[{
    "question": "请选择基础方案（后续可细化）",
    "header":   "方案选择",
    "options": [
        {"label": f"方案A: {option_a_name}", "description": option_a_summary, "preview": option_a_mermaid},
        {"label": f"方案B: {option_b_name}", "description": option_b_summary, "preview": option_b_mermaid},
        {"label": "方案C: ...",              "description": "..."},
        {"label": "都不满意，请调整",         "description": "告诉我调整方向"}
    ]
}])
```

### 5b. 确认组件边界

```python
AskUserQuestion(questions=[{
    "question": f"方案{selected}将影响以下现有组件，确认范围是否合理？",
    "header":   "组件影响确认",
    "options": [
        {"label": "确认，范围合理",       "description": "继续"},
        {"label": "范围太大，需要收窄",   "description": "告诉我哪些组件不该动"},
        {"label": "还需要影响其他组件",   "description": "说明额外需求"}
    ]
}])
```

### 5c. 确认关键技术决策

```python
# 根据方案内容动态生成，最多2-3个关键决策点
# 例如：数据存储方式、接口协议、状态管理方式
AskUserQuestion(questions=[{
    "question": "数据持久化方式选择哪个？",
    "header":   "技术决策 (1/2)",
    "options": [
        {"label": "本地数据库（QSqlDatabase / SQLite）", "description": "适合大量结构化数据"},
        {"label": "本地配置文件（QSettings  / JSON）",  "description": "适合轻量级设置项"},
        {"label": "跟随现有方案",                    "description": "保持一致"}
    ]
}])
```

### 5d. 确认测试策略

```python
AskUserQuestion(questions=[{
    "question": "测试重点放在哪里？",
    "header":   "测试策略确认",
    "options": [
        {"label": "核心业务逻辑（单元测试）",    "description": "覆盖率 ≥ 80%"},
        {"label": "UI 交互（截图/集成测试）",    "description": "验证界面流程"},
        {"label": "两者兼顾",                   "description": "全面覆盖"}
    ]
}])
```

---

## Step 6: 写设计规格文档

> [!CAUTION]
> **先确认完所有问题，再写文档！**
> 必须确保 Step 2 (需求澄清) 和 Step 5 (方案逐节确认) 中的所有问题都已通过 AskUserQuestion 得到用户的实质性回复和确认。绝对禁止在用户未完整回复前直接输出设计规格。如果你缺少任何必要信息，必须退回提问环节。

所有维度确认后，读取模板文件 `skills/design-phase/templates/design-template.md`，然后进行填充与写入：
写入至：`.dev-flow/{workflow_id}/outputs/design-spec.md`

```python
# 读取模板内容
template_content = Read("skills/design-phase/templates/design-template.md")

# ... Architect Agent 结合以下内容：
# 1. 前序阶段梳理出的需求（Step 2）
# 2. 外部文档解析结果（Step 3）
# 3. 最终确认的技术方案、边界、测试策略（Step 5）
# 
# 将以上内容系统地填充到模板中所有“[在此处填写...]”以及“{...}”的占位符中 ...

# 输出最终的方案设计规格文档
Write(f".dev-flow/{workflow_id}/outputs/design-spec.md", content=final_content)
```

---

## Step 7: 用户审阅规格文档

```python
AskUserQuestion(questions=[{
    "question": f"设计规格已写入 `.dev-flow/{workflow_id}/outputs/design-spec.md`，请确认后继续实现阶段",
    "header":   "规格确认",
    "options": [
        {"label": "✅ 确认，开始实现", "description": "进入 dev-flow Phase 3"},
        {"label": "📝 需要修改", "description": "说明需要调整的内容"},
        {"label": "🔄 重新设计方案", "description": "返回 Step 4"}
    ]
}])
```

若用户要求修改 → 更新 design-spec.md → 重新展示 → 再次确认。

---

## Step 8: 输出 Phase 1+2 JSON

```python
# Phase 1 输出
phase_1_output = {
    "phase_number": 1,
    "phase_name": "需求分析",
    "output": {
        "core_requirements":          requirements_list,
        "non_functional_requirements": nfr_dict,
        "success_criteria":           criteria_list,
        "external_context":           external_context,  # Figma/doc 提取结果
        "clarification_rounds":       N   # 澄清轮数统计
    }
}

# Phase 2 输出
phase_2_output = {
    "phase_number": 2,
    "phase_name": "设计方案",
    "output": {
        "options":          options_list,
        "selected_option":  selected_index,
        "design_spec_file": f".dev-flow/{workflow_id}/outputs/design-spec.md",
        "tech_decisions":   tech_decisions_dict,
        "affected_components": affected_list,
        "test_strategy":    test_strategy,
        "impact_analysis": {
            "direct":   direct_impact_list,
            "indirect": indirect_impact_list,
            "risks":    risk_list
        }
    }
}
```

---

## 🚩 Red Flags - 立即停止

| 如果你正在... | 应该做... |
|-------------|---------|
| 跳过某个澄清问题直接假设 | 停止，使用 AskUserQuestion 澄清 |
| 在提问环节未结束时提前生成设计文档 | 停止，必须等待所有问题明确确认完毕后再输出设计文档 |
| 合并多个问题一次性提问 | 拆开，每次只问一个 |
| 代用户选择方案 | 停止，必须等用户回答 |
| 跳过 Step 7 规格确认 | 停止，规格必须用户最终确认 |
| 在规格未确认时就开始写代码 | 停止，这是 Iron Law 违反 |
| 因为"方案很简单"而跳过设计 | 停止，EVERY feature goes through design |

---

## 文档资源

- **docs/external-context-guide.md** — Figma/doc/pdf 解析指南
- **docs/workflow-phases.md** — Phase 1/2 详细流程
- **docs/agent-guide.md** — Architect Agent 调用模板
