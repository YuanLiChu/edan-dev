# 外部文档解析指南

本文档说明如何在设计阶段（Phase 1/2）解析外部参考文档（Figma 导出图、Word/PDF、截图等）。

---

## 使用时机

**在 design-phase Step 3 中**，当用户提供了以下任意类型的外部文档时调用本指南：

- Figma 导出图（PNG/SVG/JPG）
- 设计文档（Word 导出 .docx、PDF 导出 .txt/.md）
- PRD/需求文档（Markdown/TXT）
- UI 截图/参考图
- 流程图导出图片

此外，**design-context skill 会自动扫描外挂文件夹**（`attachments/` 或 `.attachments/`）中的文档，无需用户显式指定路径即可自动发现。

---

## 外挂文件夹自动发现

### 机制

design-context skill（design-phase Step 0 前置步骤）会自动：

1. 检测 `attachments/` 或 `.attachments/` 目录是否存在
2. 递归扫描其中的所有文件
3. 按类型分类：UI截图、需求文档、API规范、其他
4. 将分类结果输出到 `design_context.attachments.files`

### 目录结构规范

推荐的外挂文件夹结构：

```
attachments/
├── requirements/    ← 需求文档、PRD、Word/PDF 导出
│   ├── prd.md
│   └── user-story.txt
├── ui/              ← UI 截图、设计图、流程图
│   ├── login-screen.png
│   └── dashboard-mockup.jpg
├── api/             ← API 规范、Swagger/OpenAPI 文件
│   └── openapi.yaml
└── figma/           ← Figma 导出图
    └── main-flow.png
```

### 自动发现 vs 显式提供

| 方式 | 适用场景 | 处理方式 |
|------|---------|---------|
| **自动发现** | 文件已放入 `attachments/` 目录 | design-context Step 0 自动扫描，Step 3 自动纳入 |
| **显式提供** | 文件在其他位置，或临时提供 | 用户在对话中提供路径，Step 3b 单独处理 |

### 注意事项

- **文件格式限制**：`.docx` 和 `.pdf` 需要用户预先导出为 `.txt` 或 `.md`，Agent 无法直接读取二进制格式
- **图片大小**：建议截图压缩至 1920px 宽度以内，避免传输过大
- **敏感信息**：如包含机密设计图，建议将 `attachments/` 加入 `.gitignore`
- **命名规范**：使用英文文件名，避免空格（用 `-` 或 `_` 代替）

---

## 解析流程

### 1. 确认文档位置

```python
# 方式A：从用户对话中提取路径或 MCP 服务地址/端口
source_info = extract_from_user_message(user_input)

# 方式B：主动询问
AskUserQuestion(questions=[{
    "question": "请提供设计文档的位置或 MCP 服务信息",
    "header": "外部文档",
    "options": [
        {"label": "Figma MCP 服务",          "description": "请输入 MCP 地址和端口"},
        {"label": "Figma 导出图/截图 (PNG)", "description": "请输入图片路径"},
        {"label": "Word/PDF 文档",           "description": "请提供文件路径"},
        {"label": "暂时没有外部文档",         "description": "跳过此步骤"}
    ]
}])
```

### 2. 按文档类型选择解析策略

#### Figma 设计（MCP 服务或截图）

如果用户提供了 MCP 服务地址和端口：
```python
# 1. 尝试连接用户提供的 MCP 服务读取 Figma 数据
try:
    figma_content = ReadFromMCP(address, port)
except Exception:
    # 2. 如果无法访问或报错，立刻提示用户提供截图
    AskUserQuestion(questions=[{
        "question": "Figma MCP 服务无法访问，请提供设计图的截图路径",
        "header": "服务访问失败"
    }])
    figma_content = Read(screenshot_path)

# 如果用户直接提供的是截图（PNG/SVG/JPG）
# figma_content = Read(figma_image_path)
```

# Architect Agent 内部执行图片分析
# 提取以下信息：
analysis_prompt = """
分析这张 Figma 设计图，提取以下信息：

1. UI 组件列表（按层级）：
   - 页面/屏幕名称
   - 主要功能区域
   - 交互组件（按钮、表单、列表等）

2. 交互流程：
   - 用户操作序列
   - 状态变化（空态/加载态/成功/失败）
   - 导航关系

3. 视觉规格（如清晰可见）：
   - 关键颜色值
   - 字体大小层级
   - 间距规律

4. 业务规则（从标注推断）：
   - 字段验证规则
   - 权限控制
   - 数据约束
"""
```

#### Word/PDF 文档

**说明**：Agent 工具不能直接读取二进制 .docx/.pdf，需要用户预先导出为文本格式。

```python
# 检查文件格式
if doc_path.endswith(('.txt', '.md', '.markdown')):
    # 可以直接 Read
    content = Read(doc_path)
elif doc_path.endswith('.pdf'):
    # 尝试用 Bash 提取文本（需系统有 pdftotext 或类似工具）
    text_output = Bash(f"pdftotext '{doc_path}' - 2>/dev/null || cat '{doc_path}'")
    content = text_output
elif doc_path.endswith('.docx'):
    # 告知用户需要转换
    # AskUserQuestion 请用户提供导出的 txt/md 版本
    pass
```

**提取内容**：
```python
doc_analysis_prompt = """
分析以下文档内容，提取：

1. 功能需求列表（按优先级）
2. 业务规则和约束
3. 验收标准（AC/DoD）
4. 数据字段定义
5. 接口/API 说明（如有）
6. 已知限制或不做的事项

文档内容：
{content}
"""
```

#### Markdown/TXT 文档

```python
# 直接读取，传入 Architect Agent 分析
content = Read(doc_path)
# 同 Word 文档的提取逻辑
```

---

## 标准化输出格式

无论何种文档类型，解析结果统一输出为：

```json
{
  "external_context": {
    "source_type": "figma_export",
    "source_file": "docs/design/login-screen.png",
    "analyzed_at": "2026-04-21T10:00:00Z",

    "ui_components": [
      {
        "name": "LoginForm",
        "type": "表单容器",
        "children": ["EmailInput", "PasswordInput", "LoginButton"],
        "states": ["默认", "加载中", "错误"]
      }
    ],

    "interaction_flows": [
      "用户输入邮箱和密码 → 点击登录 → 显示加载状态 → 成功跳转首页 / 失败显示错误提示"
    ],

    "business_rules": [
      "邮箱格式必须合法",
      "密码最少8位",
      "连续失败3次锁定账号30秒"
    ],

    "acceptance_criteria": [
      "登录成功后跳转到上次访问页面",
      "错误提示具体说明是邮箱还是密码错误",
      "支持记住密码（7天）"
    ],

    "field_definitions": [
      {"field": "email",    "type": "String",  "validation": "email format"},
      {"field": "password", "type": "String",  "validation": "min 8 chars"}
    ],

    "notes": "图中标注了深色模式适配，需要在实现中考虑"
  }
}
```

---

| 情况 | 处理方式 |
|------|---------|
| MCP 服务无法连接/超时 | AskUserQuestion 请用户直接提供截图 |
| 图片分辨率太低，无法识别文字 | AskUserQuestion 请用户描述关键内容 |
| 无法读取二进制文件 | AskUserQuestion 请用户导出为 txt/md |
| 文档内容与需求描述不一致 | AskUserQuestion 请用户确认以哪个为准 |
| 文档缺少关键信息 | 记录为 "待确认"，在 Step 2 的 Q 中补充澄清 |

---

## 与需求分析的整合

外部文档解析结果 → 合并到 Phase 1 输出的 `external_context` 字段  
→ Architect Agent 在生成方案时参考  
→ 设计规格文档中引用具体来源

**优先级**：用户口述需求 > 外部文档 > 推断假设
