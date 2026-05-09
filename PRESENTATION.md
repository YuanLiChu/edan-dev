# edan-dev 方案设计 Skill 介绍

> 面向团队内部的方案设计 Skill 分享  
> 分享人：YuanLiChu  
> 目标听众：研发团队、架构师、AI 辅助开发实践者

---

## 一、我们遇到了什么问题？

### 现状痛点

| 痛点 | 具体表现 |
|------|---------|
| AI 设计缺乏上下文 | 每次让 AI 设计新功能，它都像第一次听说这个项目，从零开始理解技术栈和架构 |
| 设计文档散落在对话中 | 设计结果在 AI 对话里，没有沉淀，换一轮对话就丢了 |
| 需求文档、UI 截图反复上传 | 每次都要重新发一遍 Figma 链接、PRD 文档、UI 截图 |
| 设计方案与现有架构脱节 | AI 设计的新功能和现有代码风格、架构模式不兼容 |
| 无法直观对比方案 | 架构图、UI mockup 只能在终端用文字描述，效果差 |

### 一个真实场景

产品经理：我们要做报警限智能建议功能。

开发同学打开 AI 助手：
1. AI：请描述一下这个项目的技术栈？
2. 开发：C++17 + Qt5.15，MVVM 架构...
3. AI：报警系统现有的模块结构是怎样的？
4. 开发：有 AlarmEngine、PatientContext...
5. AI：请上传需求文档和 UI 截图。
6. 开发：重新发送 PRD 和 Figma 截图...

结果：15 分钟过去了，AI 才刚搞清楚项目背景，还没开始设计。

---

## 二、我们的解决方案：edan-dev 方案设计 Skill

### 核心理念

    设计不是从零开始，而是基于已有上下文的增量创造。

edan-dev 方案设计 Skill 是一套让 AI 在进入设计前，先自动建立完整项目上下文的 AI 工作流规范。

---

## 三、三层文档架构（L1 / L2 / L3）

这是我们方案的最大创新点：把项目知识结构化分层，让 AI 按需读取。

    L1: 系统总览 (docs/project.md)
    |-- 子系统索引表 -> AI 知道报警系统文档在 docs/alarm.md
    |-- 技术栈、架构模式
    |-- 文档分层规范
    |
    L2: 子系统文档 (docs/alarm.md / docs/network.md...)
    |-- 核心业务流程（5 个流程图）
    |-- 数据模型、接口定义
    |-- 模块边界（什么归我管、什么不归我管）
    |-- 与其他子系统的交互矩阵
    |
    L3: 功能规格 (test/{feature}/design-spec.md)
    |-- 具体功能的实现方案
    |-- Mermaid 架构图、接口定义
    |-- TDD 测试用例
    |-- 工作量评估

### 为什么分层？

| 场景 | 没有分层 | 有分层 |
|------|---------|--------|
| 做新功能设计 | AI 从零理解报警系统 | AI 读取 docs/alarm.md，5 分钟掌握业务流程 |
| 做架构重构 | AI 不知道各模块边界 | AI 读取 L2 文档，清楚每个子系统的职责范围 |
| 新人 onboarding | 问老员工报警怎么工作的 | 直接读 docs/alarm.md |
| 设计评审 | 口头描述，容易遗漏 | L3 design-spec 就是评审材料 |

---

## 四、Skill 体系

我们的方案由 3 个 Skill 协同工作：

    开始新功能设计
         |
         v
    [design-context Skill]  -- 检测 project.md / 扫描 attachments / 解析子系统索引
         |
         v
    [design-phase Skill]    -- 需求分析 -> 方案设计 -> 生成 design-spec.md
         |
         +-- 需要可视化对比 --> [visual-brainstorming Skill] -- 浏览器展示架构图对比

### 4.1 design-context Skill：建立上下文

功能：
1. 检测 project.md -> 不存在则提示生成，存在则读取摘要
2. 扫描外挂文件夹 attachments/ -> 自动分类需求文档、UI 截图、API 规范
3. 解析子系统索引 -> 定位相关子系统文档（如 docs/alarm.md）

Iron Law:

    NO DESIGN WITHOUT PROJECT CONTEXT

### 4.2 design-phase Skill：方案设计流水线

7 步工作流：

    Step 0: design-context 初始化  -> 读取 project.md + 子系统文档 + attachments
    Step 1: 读取项目上下文         -> Phase 0 输出 + 子系统业务上下文
    Step 2: 需求澄清（多轮）       -> AskUserQuestion x N
    Step 3: 外部文档解析           -> PRD / UI 截图 / Figma
    Step 4: 生成候选方案           -> Architect Agent -> 2-3 方案 + Reviewer 审查
    Step 5: 方案逐节确认           -> 方案选择 -> 组件边界 -> 技术决策 -> 测试策略
    Step 6: 写设计规格文档         -> design-spec.md
    Step 7: 用户审阅规格文档       -> 最终确认

Iron Law:

    NO CODE WITHOUT APPROVED DESIGN SPEC

### 4.3 visual-brainstorming Skill：视觉伴侣

功能：浏览器端的可视化辅助工具

适用场景：
- 展示 2-3 个候选方案的架构图对比
- UI mockup 并排展示
- 状态机动态演示
- 交互原型（可点击的选项卡片）

技术实现：
- 零依赖 Node.js HTTP/WebSocket 服务器（手写 RFC 6455）
- Agent 写 HTML 到目录，浏览器自动刷新
- 用户点击选择，事件回写到文件，AI 下一轮读取

---

## 五、完整演示：报警限智能建议功能

### 5.1 准备阶段

    test/alarm-limit-suggest/
    |-- project.md                  <- L1 上下文（功能级）
    |-- attachments/
    |   |-- requirements/prd.md     <- PRD 需求文档
    |   |-- ui/mockup-description.md <- UI 草图
    |-- design-spec.md              <- L3 输出（最终设计规格）

### 5.2 design-context 执行

    AI: 检测到 docs/project.md
        -> 发现 6 个子系统
        -> 当前功能"报警限建议"关联：报警系统
        -> 读取 docs/alarm.md
        -> 扫描到 attachments/requirements/prd.md
        -> 扫描到 attachments/ui/mockup-description.md

    项目上下文摘要：
       项目：监护仪嵌入式软件平台（C++17/Qt5.15/MVVM）
       子系统：报警系统（docs/alarm.md）- 包含 5 个核心业务流程
       外部文档：PRD（9 条需求）+ UI Mockup（弹窗布局）

    报警系统业务流程（来自 docs/alarm.md）：
       1. 报警触发流程（3s 去抖 -> 分级报警音）
       2. 报警限设置流程（权限检查 -> 合理性校验）
       3. 报警限智能建议流程 <- 本次设计的目标
       4. 报警暂停与恢复流程
       5. 报警历史查询流程

### 5.3 design-phase 执行

Step 2：需求澄清

    Q1: 功能范围 -- 本次只做 v1.0 基础规则，v2.0 趋势预测不做？
        -> 用户：确认

    Q2: 触发时机 -- 主动点击 + 被动触发 + 定时扫描都要？
        -> 用户：先做主动点击

    Q3: UI 形式 -- 模态弹窗还是非模态悬浮？
        -> 用户：非模态，不阻塞操作

Step 4：生成候选方案

Architect Agent 基于以下上下文生成方案：
- docs/alarm.md 中的 SuggestionEngine 模块边界
- docs/alarm.md 中的 RuleEvaluator 接口
- docs/alarm.md 中的 PatientContextModel 数据模型
- PRD 中的 4 条基础规则
- UI Mockup 中的弹窗布局

输出 2 个候选方案 + Reviewer 评分 94 分

Step 5：方案确认

    5a. 选择方案 -> 方案 A（分层架构，与现有 AlarmEngine 集成）
    5b. 组件边界 -> 确认影响范围：AlarmConfigDialog + 新增 SuggestionEngine
    5c. 技术决策 -> JSON 热重载规则文件
    5d. 测试策略 -> 核心业务逻辑 100% 覆盖

Step 6：输出 design-spec.md

12,605 字节，包含：
- Mermaid 组件关系图 + Sequence Diagram
- C++ 数据结构定义
- JSON 规则 Schema
- 5 个单元测试 + 3 个集成测试
- 工作量评估：17 人天

### 5.4 结果

    设计完成，输出 test/alarm-limit-suggest/design-spec.md

    与现有架构的兼容性：
      - 复用 AlarmConfigDialog（扩展按钮）
      - SuggestionEngine 复用 PatientContextModel（已有数据模型）
      - 规则 JSON 格式与现有配置系统一致

---

## 六、价值总结

### 对开发同学

| 价值 | 说明 |
|------|------|
| 省时间 | AI 自动读取项目上下文，不用每次从零解释技术栈 |
| 设计质量高 | 基于子系统文档设计，不破坏现有架构 |
| 文档即代码 | design-spec.md 就是设计文档，可评审、可追溯 |
| 需求不丢 | PRD / UI 截图放到 attachments/，AI 自动读取 |

### 对架构师

| 价值 | 说明 |
|------|------|
| 架构知识沉淀 | docs/alarm.md 就是报警系统的权威知识库 |
| 设计一致性 | 所有功能设计必须符合子系统文档定义的边界 |
| 评审有依据 | L3 design-spec 就是评审材料，Reviewer Agent 量化评分 |

### 对团队

| 价值 | 说明 |
|------|------|
| 知识不随人走 | 老员工离职，文档在 docs/ 里 |
| 新人快速上手 | 读 docs/project.md -> docs/alarm.md -> test/xxx/design-spec.md |
| AI 辅助标准化 | 所有设计走同一套 skill 流程，输出格式统一 |

---

## 七、如何开始使用？

### 第一步：创建项目总览

    在项目根目录创建 docs/project.md
    参考模板：skills/design-context/templates/project.md

### 第二步：创建子系统文档

    为每个子系统创建 docs/{subsystem}.md
    描述核心业务流程、数据模型、模块边界

    docs/
    |-- project.md      # 系统总览 + 子系统索引
    |-- alarm.md        # 报警子系统
    |-- network.md      # 网络通信子系统
    |-- patient.md      # 患者管理子系统
    |-- ...

### 第三步：开始功能设计

    创建功能目录
    test/alarm-limit-suggest/
    |-- attachments/
    |   |-- requirements/prd.md
    |   |-- ui/mockup.png
    |-- project.md      # 功能级上下文（可选）

    AI 自动执行：
    1. 读取 docs/project.md -> 发现报警系统 -> 读取 docs/alarm.md
    2. 扫描 attachments/ -> 读取 PRD 和 UI
    3. 生成 design-spec.md

---

## 八、Q & A

Q: 这和直接让 AI 设计有什么区别？
   直接让 AI 设计 = 每次从零开始。
   用 skill = AI 先读 project.md 和子系统文档，站在已有架构上做增量设计。
   设计质量和一致性都更好。

Q: 维护这些文档成本高吗？
   L1 project.md 只在新增子系统时更新。
   L2 子系统文档只在业务流程变更时更新。
   L3 design-spec 是设计过程的副产品，不额外成本。

Q: 视觉伴侣必须每次都开浏览器吗？
   不是。视觉伴侣是"按需启用"的工具，
   只有展示架构对比、UI mockup 时才启动。
   文字类问题继续在终端解决。

Q: 这个方案适合非 Qt/C++ 项目吗？
   完全适合。project.md 模板中的技术栈、架构模式都是可配置的。
   子系统文档的结构是通用的。

---

## 附录：仓库地址

- 个人仓库: https://github.com/YuanLiChu/edan-dev
- PR 地址: https://github.com/DawnGlowShen/edan-dev/pulls

核心文件:
  - skills/design-context/SKILL.md
  - skills/design-phase/SKILL.md
  - skills/visual-brainstorming/SKILL.md
  - docs/project.md
  - docs/alarm.md
