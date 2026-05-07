---
name: visual-brainstorming
description: Use during design-phase when presenting candidate solutions, UI mockups, architecture diagrams, or side-by-side visual comparisons that benefit from browser-based interactive display. Available as a tool — not a mode. Decides per-question whether to use browser or terminal. 中文触发词：视觉伴侣、浏览器展示、架构图对比、UI mockup、交互原型、方案可视化
argument-hint: "[--project-dir=<path>] [--host=<bind-host>]"
allowed-tools: ["Read", "Glob", "Bash", "Write"]
---

# Visual Brainstorming - 视觉伴侣

浏览器端的可视化辅助工具，用于在设计阶段展示架构图、UI mockup、方案对比等视觉内容。**这是 design-phase 的可选增强工具，按需启用。**

目标耗时：1-2 分钟启动服务器 + 每屏 30 秒-2 分钟

---

## ⚠️ Core Principle

```
BROWSER = INTERACTIVE DISPLAY
TERMINAL = CONVERSATION CHANNEL
```

浏览器用于展示视觉内容，终端用于对话交流。TUI 始终不被阻塞。

---

## 何时使用视觉伴侣

**按问题决策，非按会话。** 核心测试："用户通过看是否比通过读更容易理解？"

### ✅ 使用浏览器

| 场景 | 示例 |
|------|------|
| **架构图对比** | 展示 2-3 个候选方案的 Mermaid 组件关系图，支持点击选择 |
| **UI mockup** | 线框图、布局方案、导航结构、组件设计 |
| **设计对比** | A/B 颜色方案、布局方案、交互方式的并排对比 |
| **状态机演示** | 动态高亮状态流转，展示模块间的数据扭转 |
| **交互原型** | 可点击的选项卡片、表单原型、流程演示 |

### ❌ 使用终端

| 场景 | 示例 |
|------|------|
| 需求澄清 | "这个功能的目标用户是谁？" |
| 概念性选择 | "数据存储用 SQLite 还是 JSON 文件？" |
| 权衡列表 | 优缺点对比（纯文本表格） |
| 技术决策 | API 设计、数据建模 |
| 范围确认 | "哪些组件在本次不做？" |

> **关键判断**：一个关于 UI 的问题不一定是视觉问题。"向导需要几步？"是概念性的 → 用终端。"哪个向导布局感觉更好？"是视觉的 → 用浏览器。

---

## 征求用户同意

在预计需要视觉内容的问题前，**单独发一条消息**征求用户同意：

```
接下来的方案对比涉及架构图和 UI 布局，我可以在浏览器中展示可视化对比，
支持点击选择和交互反馈。是否启用视觉伴侣？
（需要打开本地 URL，建议在第二个显示器或分屏中查看）
```

**此征求必须是独立消息**，不能与其他内容合并。等待用户回复后再继续。

若用户拒绝，全程使用文本-only 方式继续。

---

## 工作流程

```
Step 1: 启动服务器      → start-server.ps1 [--project-dir]
Step 2: 写 HTML 屏幕    → Write 工具写入 content/*.html
Step 3: 提示用户查看    → 告知 URL + 屏幕内容摘要
Step 4: 用户浏览器交互  → 点击选择，事件写入 state/events
Step 5: 读取 events     → 下一轮合并浏览器事件 + 终端输入
Step 6: 迭代或前进      → 新屏幕 = 新文件，返回终端时推 waiting 屏
Step 7: 停止服务器      → stop-server.ps1 $SESSION_DIR
```

---

## Step 1: 启动服务器

```powershell
# Windows (PowerShell)
scripts/start-server.ps1 -ProjectDir $PWD

# Returns JSON:
# {
#   "type": "server-started",
#   "port": 52341,
#   "url": "http://localhost:52341",
#   "screen_dir": "C:/.../.edan-dev/brainstorm/12345-.../content",
#   "state_dir": "C:/.../.edan-dev/brainstorm/12345-.../state"
# }
```

**保存 `screen_dir` 和 `state_dir`**，后续步骤需要用到。

**环境适配**：
- **Windows PowerShell**: 脚本自动使用 foreground 模式。若通过 AI 工具调用，设置 `run_in_background: true`。
- **远程/容器环境**: 使用 `-Host 0.0.0.0` 绑定非回环地址。

**查找连接信息**: 服务器启动信息写入 `$STATE_DIR/server-info`。若后台启动未捕获输出，读取该文件获取 URL 和端口。

---

## Step 2: 写 HTML 屏幕

### 内容片段 vs 完整文档

**默认写内容片段**（推荐）：

```html
<h2>方案 A vs 方案 B：架构对比</h2>
<p class="subtitle">点击选择你认为更合理的架构</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>分层架构</h3>
      <p>GUI → Core → Data，职责清晰，测试友好</p>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>事件驱动架构</h3>
      <p>松耦合，异步处理，适合高并发场景</p>
    </div>
  </div>
</div>
```

服务器会自动将片段包装进 `frame-template.html`，添加主题、选择指示器和交互基础设施。

**仅当需要完全控制页面时才写完整文档**（以 `<!DOCTYPE` 或 `<html` 开头）。

### 文件命名规范

- 使用语义名称：`architecture.html`、`layout.html`、`ui-mockup.html`
- **绝不复用文件名** — 每屏必须是新文件
- 迭代版本：`layout-v2.html`、`layout-v3.html`
- 服务器通过 **mtime** 自动 serve 最新文件

### 写文件工具

**必须使用 Write 工具**，禁止使用 Bash + cat/echo/heredoc：

```python
Write(".edan-dev/brainstorm/.../content/architecture.html", content=html_content)
```

---

## Step 3: 提示用户查看

每次写新屏幕后，告知用户：

```
📺 视觉伴侣已更新
URL: http://localhost:52341

当前展示：2 个架构方案的对比
- 方案 A：分层架构（GUI → Core → Data）
- 方案 B：事件驱动架构（Pub/Sub + 状态机）

请打开 URL 查看，点击选择后回到终端告诉我你的决定。
```

**每轮都提醒 URL**，不只是第一次。

---

## Step 4 & 5: 用户交互与事件读取

用户点击带 `data-choice` 属性的元素后，事件通过 WebSocket 回传服务器，追加写入 `$STATE_DIR/events`（JSON Lines 格式）：

```jsonl
{"type":"click","choice":"a","text":"分层架构","timestamp":1706000101}
{"type":"click","choice":"b","text":"事件驱动架构","timestamp":1706000108}
```

**下一轮读取**：

```python
events = Read(".edan-dev/brainstorm/.../state/events")
# 解析 JSON Lines，合并到用户终端输入中做决策
```

- `events` 文件不存在 = 用户未在浏览器交互，仅依赖终端文本
- 最后一条 `choice` 事件通常是最终选择
- 点击模式可揭示犹豫或偏好

---

## Step 6: 迭代或前进

**若反馈改变当前屏幕**，写新文件迭代：

```python
Write(".edan-dev/brainstorm/.../content/architecture-v2.html", content=new_html)
```

**若返回终端对话**（下一步不需要浏览器），推 waiting 屏清除过时内容：

```html
<!-- waiting.html -->
<div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
  <p class="subtitle">Continuing in terminal...</p>
</div>
```

---

## Step 7: 停止服务器

```powershell
scripts/stop-server.ps1 $SESSION_DIR
```

- 若使用 `-ProjectDir`，mockup 文件持久化在 `.edan-dev/brainstorm/` 供后续回顾
- 若使用临时目录，`/tmp` 会话会被自动清理
- 服务器也会在 30 分钟空闲后自动退出

---

## CSS 组件库

`frame-template.html` 提供的预制 CSS 类：

### Options（A/B/C 单选/多选）

```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">...</div>
</div>
<!-- 多选：添加 data-multiselect -->
<div class="options" data-multiselect>
  <div class="option" data-choice="a" onclick="toggleSelect(this)">...</div>
</div>
```

### Cards（视觉设计卡片）

```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup content --></div>
    <div class="card-body"><h3>Name</h3><p>Description</p></div>
  </div>
</div>
```

### Mockup container

```html
<div class="mockup">
  <div class="mockup-header">Preview: Dashboard Layout</div>
  <div class="mockup-body"><!-- your mockup HTML --></div>
</div>
```

### Split view（左右对比）

```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons

```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>Benefit</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>Drawback</li></ul></div>
</div>
```

### Mock elements（线框构建块）

```html
<div class="mock-nav">Logo | Home | About | Contact</div>
<div class="mock-sidebar">Navigation</div>
<div class="mock-content">Main content area</div>
<button class="mock-button">Action</button>
<input class="mock-input" placeholder="Input field">
<div class="placeholder">Placeholder area</div>
```

---

## 与 design-phase 的集成

### 集成点 1：Step 5a 方案选择

在展示 2-3 个候选方案时，若方案适合可视化，启动视觉伴侣：

```python
# 方案 A/B/C 已有 Mermaid 组件关系图
# 用视觉伴侣渲染为可交互的架构预览
html = f"""
<h2>候选方案对比</h2>
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>{option_a_name}</h3>
      <p>{option_a_summary}</p>
      <pre class="mermaid">{option_a_mermaid}</pre>
    </div>
  </div>
  ...
</div>
"""
Write(f"{screen_dir}/solution-comparison.html", content=html)
```

### 集成点 2：Step 5b 组件边界确认

用高亮架构图展示受影响组件：

```html
<div class="mockup">
  <div class="mockup-header">受影响组件范围</div>
  <div class="mockup-body">
    <!-- 架构图，受影响组件标红 -->
    <p>红色高亮 = 本次需要修改的组件</p>
  </div>
</div>
```

### 集成点 3：UI 设计阶段

展示 Figma 截图和 UI 层级树：

```html
<div class="split">
  <div class="mockup">
    <div class="mockup-header">Figma 设计稿</div>
    <div class="mockup-body">
      <img src="/files/figma-login.png" style="max-width:100%">
    </div>
  </div>
  <div class="mockup">
    <div class="mockup-header">QML 组件层级</div>
    <div class="mockup-body">
      <!-- 层级树状图 -->
    </div>
  </div>
</div>
```

---

## 🚩 Red Flags

| 如果你正在... | 应该做... |
|-------------|---------|
| 所有问题都走浏览器 | 停止，按需决策，文本问题用终端 |
| 复用 HTML 文件名 | 停止，每屏必须是新文件 |
| 用 Bash + echo 写 HTML | 停止，必须使用 Write 工具 |
| 未征求同意就启动服务器 | 停止，必须先单独征求用户同意 |
| 浏览器内容和终端对话不同步 | 推 waiting 屏或写新屏幕 |
| 在远程环境未绑定 0.0.0.0 | 用户可能无法访问 URL |

---

## 文档资源

- **scripts/server.cjs** — 零依赖 Node.js HTTP/WebSocket 服务器
- **scripts/frame-template.html** — 页面框架模板（CSS 设计系统参考）
- **scripts/helper.js** — 客户端交互脚本
- **scripts/start-server.ps1** — Windows 启动脚本
- **scripts/stop-server.ps1** — Windows 停止脚本
