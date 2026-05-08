# Visual Companion 详细使用指南

浏览器端的可视化辅助工具，用于 design-phase 中展示 mockups、diagrams 和 visual options。

---

## 使用时机

**按问题决策，非按会话。** 测试标准："用户通过看是否比通过读更容易理解？"

### 使用浏览器

- **UI mockup** — 线框图、布局、导航结构、组件设计
- **架构图** — 系统组件、数据流、关系图
- **并排视觉对比** — 比较两个布局、两个配色方案、两个设计方向
- **设计精修** — 关于外观、间距、视觉层级的问题
- **空间关系** — 状态机、流程图、实体关系图

### 使用终端

- **需求和范围问题** — "X 是什么意思？"、"哪些功能在范围内？"
- **概念性 A/B/C 选择** — 用文字描述的方法之间做选择
- **权衡列表** — 优缺点、对比表
- **技术决策** — API 设计、数据建模、架构方法选择
- **澄清问题** — 任何答案是文字而非视觉偏好的问题

关于 UI 话题的问题不一定是视觉问题。"需要什么样的向导？"是概念性的 → 用终端。"哪个向导布局感觉更好？"是视觉的 → 用浏览器。

---

## 工作原理

服务器监听一个目录中的 HTML 文件，将最新的文件提供给浏览器。你将 HTML 内容写入 `screen_dir`，用户在浏览器中看到它并可以点击选择选项。选择结果记录到 `state_dir/events`，你在下一轮读取。

**内容片段 vs 完整文档：** 如果你的 HTML 文件以 `<!DOCTYPE` 或 `<html` 开头，服务器会原样提供（仅注入 helper 脚本）。否则，服务器会自动将你的内容包装进 frame 模板 —— 添加 header、CSS 主题、选择指示器和所有交互基础设施。**默认写内容片段。** 仅当你需要完全控制页面时才写完整文档。

---

## 启动会话

```powershell
# 使用持久化存储（mockup 保存到项目中）
scripts/start-server.ps1 -ProjectDir /path/to/project

# Returns: {"type":"server-started","port":52341,"url":"http://localhost:52341",
#           "screen_dir":"/path/to/project/.edan-dev/brainstorm/12345-.../content",
#           "state_dir":"/path/to/project/.edan-dev/brainstorm/12345-.../state"}
```

保存 `screen_dir` 和 `state_dir`。告诉用户打开 URL。

**查找连接信息：** 服务器将启动信息写入 `$STATE_DIR/server-info`。如果你在后台启动了服务器且未捕获 stdout，读取该文件获取 URL 和端口。使用 `-ProjectDir` 时，检查 `<project>/.edan-dev/brainstorm/` 获取会话目录。

**注意：** 将项目根目录作为 `-ProjectDir` 传入，使 mockup 持久保存在 `.edan-dev/brainstorm/` 中，服务器重启后仍然保留。如果不传，文件会放入 `/tmp` 并在停止后被清理。提醒用户将 `.edan-dev/` 加入 `.gitignore`（如果尚未加入）。

**按平台启动服务器：**

**Windows PowerShell:**
```powershell
# Windows 自动检测并使用 foreground 模式，会阻塞工具调用。
# 在 Bash 工具调用中设置 run_in_background: true，使服务器跨对话轮次存活。
scripts/start-server.ps1 -ProjectDir /path/to/project
```

---

## 工作流程循环

1. **检查服务器是否存活**，然后**写 HTML**到新文件到 `screen_dir`：
   - 每次写入前，检查 `$STATE_DIR/server-info` 是否存在。如果不存在（或 `$STATE_DIR/server-stopped` 存在），服务器已关闭 —— 在继续前用 `start-server.ps1` 重启。服务器在 30 分钟无活动后自动退出。
   - 使用语义文件名：`platform.html`、`visual-style.html`、`layout.html`
   - **绝不复用文件名** — 每屏必须是新文件
   - 使用 Write 工具 — **禁止使用 cat/heredoc**（会在终端产生噪音）
   - 服务器自动提供最新文件

2. **告诉用户预期内容并结束本轮：**
   - 每步都提醒 URL（不只是第一次）
   - 简要文本摘要屏幕上有什么（例如"展示 3 个首页布局选项"）
   - 让他们在终端回复："看一看然后告诉我你的想法。如果想选择，点击一个选项。"

3. **在你的下一轮** — 用户在终端回复后：
   - 读取 `$STATE_DIR/events`（如果存在）— 包含用户的浏览器交互（点击、选择）作为 JSON lines
   - 与用户的终端文本合并，获取完整画面
   - 终端消息是主要反馈；`state_dir/events` 提供结构化交互数据

4. **迭代或前进** — 如果反馈改变当前屏幕，写新文件（例如 `layout-v2.html`）。仅当当前步骤验证完成后再进入下一个问题。

5. **返回终端时卸载** — 当下一步不需要浏览器时（例如澄清问题、权衡讨论），推送 waiting 屏幕清除过时内容：

   ```html
   <!-- filename: waiting.html (或 waiting-2.html 等) -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

   这防止用户在对话已经继续时还盯着已解决的选择。当下一个视觉问题出现时，像往常一样推送新内容文件。

6. 重复直到完成。

---

## 编写内容片段

只写放入页面内部的内容。服务器会自动用 frame 模板包装（header、主题 CSS、选择指示器和所有交互基础设施）。

**最小示例：**

```html
<h2>哪个布局更好？</h2>
<p class="subtitle">考虑可读性和视觉层级</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>单列</h3>
      <p>干净、专注的阅读体验</p>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>双列</h3>
      <p>侧边导航加主内容区</p>
    </div>
  </div>
</div>
```

就这样。不需要 `<html>`、CSS 或 `<script>` 标签。服务器提供所有基础设施。

---

## CSS 类参考

Frame 模板为你的内容提供以下 CSS 类：

### Options（A/B/C 选择）

```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>标题</h3>
      <p>描述</p>
    </div>
  </div>
</div>
```

**多选：** 在容器上添加 `data-multiselect` 允许用户选择多个选项。每次点击切换项目。指示器栏显示计数。

```html
<div class="options" data-multiselect>
  <!-- 相同的 option 标记 — 用户可以选择/取消选择多个 -->
</div>
```

### Cards（视觉设计）

```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup content --></div>
    <div class="card-body">
      <h3>名称</h3>
      <p>描述</p>
    </div>
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

### Split view（并排）

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
<div style="display: flex;">
  <div class="mock-sidebar">Navigation</div>
  <div class="mock-content">Main content area</div>
</div>
<button class="mock-button">Action Button</button>
<input class="mock-input" placeholder="Input field">
<div class="placeholder">Placeholder area</div>
```

### 排版和区块

- `h2` — 页面标题
- `h3` — 区块标题
- `.subtitle` — 标题下方的次要文本
- `.section` — 带底部间距的内容块
- `.label` — 小写大写标签文本

---

## 浏览器事件格式

当用户在浏览器中点击选项时，交互记录到 `$STATE_DIR/events`（每行一个 JSON 对象）。推送新屏幕时文件自动清空。

```jsonl
{"type":"click","choice":"a","text":"Option A - Simple Layout","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Complex Grid","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid","timestamp":1706000115}
```

完整的事件流展示用户的探索路径 —— 他们可能在确定前点击多个选项。最后一条 `choice` 事件通常是最终选择，但点击模式可以揭示犹豫或值得追问的偏好。

如果 `$STATE_DIR/events` 不存在，用户没有与浏览器交互 —— 仅使用他们的终端文本。

---

## 设计技巧

- **按问题调整保真度** — 布局用线框图，精修问题用精修设计
- **每页解释问题** — "哪个布局感觉更专业？" 而不是 "选一个"
- **前进前迭代** — 如果反馈改变当前屏幕，写新版本
- **每屏最多 2-4 个选项**
- **重要时使用真实内容** — 对于摄影作品集，使用实际图片（Unsplash）。占位内容会掩盖设计问题。
- **保持 mockup 简单** — 聚焦布局和结构，而非像素级完美设计

---

## 文件命名

- 使用语义名称：`platform.html`、`visual-style.html`、`layout.html`
- 绝不复用文件名 — 每屏必须是新文件
- 迭代：附加版本后缀如 `layout-v2.html`、`layout-v3.html`
- 服务器通过修改时间提供最新文件

---

## 清理

```powershell
scripts/stop-server.ps1 $SESSION_DIR
```

如果会话使用了 `-ProjectDir`，mockup 文件持久保存在 `.edan-dev/brainstorm/` 供后续参考。只有 `/tmp` 会话在停止时被删除。
