---
name: design-context
description: Use when starting any design or development task to establish the project design context; automatically detects project.md and external attachments folder, reads current design if available, or prompts user to generate one if missing. Also scans and catalogs external documents (requirements, UI screenshots, etc.) for AI parsing. 中文触发词：开始设计、开始开发、新项目、查看项目设计、检测project.md、外挂文件夹
argument-hint: "[--project-dir=<path>] [--attachments-dir=<path>]"
allowed-tools: ["Read", "Glob", "AskUserQuestion", "Write", "Bash"]
---

# Design Context - 设计上下文初始化

在任何设计或开发任务开始前，自动建立项目的设计上下文。**这是 design-phase 和 dev-flow 的前置步骤。**

目标耗时：1-3 分钟

---

## ⚠️ Iron Law

```
NO DESIGN WITHOUT PROJECT CONTEXT
```

不知道项目整体设计 → 不得进行具体功能设计。

---

## 工作流程

```
Step 0a: 检测 project.md         → 读取或提示生成
Step 0b: 检测外挂文件夹           → 扫描附件文档
Step 0c: 输出设计上下文摘要        → 供后续 skill 使用
```

---

## Step 0a: 检测 project.md

### 检测路径（按优先级）

| 优先级 | 路径 | 说明 |
|--------|------|------|
| 1 | `./project.md` | 项目根目录（推荐）|
| 2 | `./Project.md` | 大写版本（兼容）|
| 3 | `./.dev-flow/Project.md` | dev-flow 工作流目录 |

```python
# 检测逻辑
candidates = ["project.md", "Project.md", ".dev-flow/Project.md"]
project_md_path = None

for candidate in candidates:
    if file_exists(candidate):
        project_md_path = candidate
        break
```

### 情况 A: project.md 存在

**读取并摘要展示**：

```python
content = Read(project_md_path)

# 输出摘要给用户
summary = extract_summary(content)
# 提取：项目目标、技术栈、核心架构、关键模块
# 长度：不超过 20 行，便于快速浏览
```

**展示格式**：

```
📋 当前项目设计概览（来自 {project_md_path}）:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{summary}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 情况 B: project.md 不存在

**提示用户生成**：

```python
AskUserQuestion(questions=[{
    "question": "项目根目录未检测到 project.md（项目设计总览文档）。是否立即生成？",
    "header": "设计上下文缺失",
    "options": [
        {
            "label": "✅ 生成 project.md（推荐）",
            "description": "基于当前项目结构自动生成设计总览模板，后续可手动完善"
        },
        {
            "label": "📝 我先手动创建",
            "description": "告知用户路径规范和模板位置，跳过自动生成"
        },
        {
            "label": "⏭️ 跳过，直接进入功能设计",
            "description": "不推荐：缺少项目上下文可能导致设计偏离整体架构"
        }
    ]
}])
```

**若用户选择生成**（选项1）：

1. 扫描项目结构（参考 architect.md Phase 0 的扫描命令）
2. 读取模板 `skills/design-context/templates/project.md`
3. 填充已知信息（检测到的技术栈、模块结构等）
4. 写入 `./project.md`
5. 展示生成内容，提示用户后续完善

```python
# 扫描项目结构
tech_stack = detect_tech_stack()   # 检测语言/框架/构建系统
modules = scan_modules()           # 扫描目录结构

# 读取模板
template = Read("skills/design-context/templates/project.md")

# 填充
generated = template.replace("[在此处填写项目名称]", "[待填写]")
generated = generated.replace("[在此处插入模块结构图或文字描述]", modules_tree)

# 写入
Write("project.md", content=generated)
```

**若用户选择手动创建**（选项2）：

提示用户：
```
请在项目根目录创建 project.md，参考模板：
  skills/design-context/templates/project.md

project.md 应包含：
  - 项目目标和范围
  - 技术栈和架构模式
  - 核心模块和职责
  - 关键设计决策
```

---

## Step 0b: 检测外挂文件夹（Attachments）

### 检测路径（按优先级）

| 优先级 | 路径 | 说明 |
|--------|------|------|
| 1 | `./attachments/` | 项目根目录（推荐，便于版本控制）|
| 2 | `./.attachments/` | 隐藏目录（适合不纳入版本控制的文件）|
| 3 | 用户指定路径 | 通过 `--attachments-dir=<path>` 传入 |

```python
attachment_dirs = ["attachments", ".attachments"]
attachments_dir = None

for d in attachment_dirs:
    if is_dir(d):
        attachments_dir = d
        break

# 若用户指定了路径
if args.attachments_dir:
    attachments_dir = args.attachments_dir
```

### 情况 A: 外挂文件夹存在

**扫描并分类文档**：

```python
# 递归扫描所有文件（排除隐藏文件和已知二进制大文件）
files = Glob(f"{attachments_dir}/**/*")

# 分类
docs = {
    "ui_screenshots": [],      # .png, .jpg, .jpeg, .svg, .bmp, .gif
    "requirements":   [],      # .md, .txt, .docx, .pdf
    "figma_exports":  [],      # .fig, .png (figma/)
    "api_specs":      [],      # .yaml, .yml, .json (swagger/openapi)
    "other":          []
}

for f in files:
    ext = get_extension(f).lower()
    if ext in [".png", ".jpg", ".jpeg", ".svg", ".bmp", ".gif"]:
        docs["ui_screenshots"].append(f)
    elif ext in [".md", ".txt"]:
        docs["requirements"].append(f)
    elif ext in [".docx", ".pdf"]:
        docs["requirements"].append(f)
    elif ext in [".yaml", ".yml", ".json"] and "api" in f.lower():
        docs["api_specs"].append(f)
    else:
        docs["other"].append(f)
```

**向用户报告扫描结果**：

```
📎 外挂文件夹检测到（{attachments_dir}/）：

  UI 截图:      {N} 个  → 设计阶段将自动解析组件和交互
  需求文档:      {N} 个  → 设计阶段将提取业务规则和验收标准
  API 规范:      {N} 个  → 设计阶段将纳入接口定义
  其他文件:      {N} 个

这些文档将在 design-phase Step 3 中自动纳入外部上下文解析。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 情况 B: 外挂文件夹不存在

**提示用户**：

```python
AskUserQuestion(questions=[{
    "question": "未检测到外挂文件夹（attachments/）。是否需要创建以存放需求文档、UI截图等？",
    "header": "外部文档",
    "options": [
        {
            "label": "✅ 创建 attachments/ 文件夹",
            "description": "在项目根目录创建，便于后续存放需求文档和截图"
        },
        {
            "label": "📁 我使用其他位置",
            "description": "告知用户可通过 --attachments-dir 指定自定义路径"
        },
        {
            "label": "⏭️ 跳过",
            "description": "当前没有外部文档需要挂载"
        }
    ]
}])
```

**若用户选择创建**（选项1）：

```bash
mkdir -p attachments/requirements attachments/ui attachments/api attachments/figma
```

提示：
```
已创建 attachments/ 文件夹结构：

  attachments/
  ├── requirements/    ← 需求文档、PRD、Word/PDF 导出
  ├── ui/              ← UI 截图、设计图、流程图
  ├── api/             ← API 规范、Swagger/OpenAPI 文件
  └── figma/           ← Figma 导出图

建议：将 attachments/ 加入 .gitignore（如包含敏感设计图）
```

---

## Step 0c: 输出设计上下文摘要

将 Step 0a 和 Step 0b 的结果整合为结构化输出，供后续 skill 使用：

```json
{
  "design_context": {
    "project_md": {
      "exists": true,
      "path": "project.md",
      "summary": "项目概述摘要..."
    },
    "attachments": {
      "exists": true,
      "path": "attachments/",
      "files": {
        "ui_screenshots": ["attachments/ui/login.png"],
        "requirements": ["attachments/requirements/prd.md"],
        "api_specs": ["attachments/api/openapi.yaml"]
      }
    },
    "ready_for_design": true
  }
}
```

---

## 与后续 Skill 的衔接

### design-phase 调用方式

在 design-phase Step 1 之前，自动调用 design-context：

```python
# design-phase Step 1 之前
design_context = Agent(
    subagent_type="edan-dev:design-context",
    prompt="检测 project.md 和外挂文件夹，输出设计上下文摘要"
)

# 将结果注入 Step 1
project_info = design_context["project_md"]
external_files = design_context["attachments"]["files"]
```

### dev-flow 调用方式

在 dev-flow Phase 0 之后，若 Project.md 不存在或已过时，调用 design-context：

```python
# Phase 0 输出 arch_snapshot 后
if not file_exists("project.md"):
    Agent(
        subagent_type="edan-dev:design-context",
        prompt="基于 Phase 0 的 arch_snapshot 生成 project.md"
    )
```

---

## 🚩 Red Flags

| 如果你正在... | 应该做... |
|-------------|---------|
| 跳过 project.md 检测直接进入功能设计 | 停止，先完成设计上下文初始化 |
| 发现 project.md 内容严重过时 | 提示用户更新，或基于当前代码重新生成 |
| attachments 中的文件无法读取 | 记录错误，继续；在 design-phase Step 3 中处理 |
| 用户拒绝生成 project.md | 记录原因，继续；但在设计阶段需额外确认架构假设 |
| 将敏感文件放入未加密的 attachments/ | 提示用户将 attachments/ 加入 .gitignore |

---

## 文档资源

- **templates/project.md** — project.md 标准模板
- **design-phase/docs/external-context-guide.md** — 外部文档详细解析指南
