# Project Design Overview

## 项目信息

| 字段 | 内容 |
|------|------|
| 项目名称 | 监护仪报警限智能建议系统 |
| 项目目标 | 基于患者实时生理数据和临床规则，智能推荐合理的报警限设置，减少误报和漏报 |
| 目标用户 | 临床医护人员（护士、医生） |
| 当前阶段 | 设计 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 语言/框架 | C++17 + Qt5.15 + QML |
| 构建系统 | CMake 3.20+ |
| 数据库 | SQLite（本地配置缓存） |
| 测试框架 | GTest + Qt Test |
| 算法引擎 | 嵌入式规则引擎 + 轻量 ML 推理（ONNX Runtime） |

---

## 架构概述

### 核心架构模式
MVVM + Repository Pattern

### 模块结构

```
alarm-limit-suggest/
├── src/
│   ├── gui/
│   │   ├── qml/              # QML 弹窗和列表视图
│   │   └── viewmodels/       # AlarmLimitSuggestViewModel
│   ├── core/
│   │   ├── models/           # AlarmLimitModel, PatientContextModel
│   │   ├── services/         # SuggestionEngine, RuleEvaluator
│   │   └── repositories/     # AlarmConfigRepository
│   └── data/
│       └── local/            # SQLite 数据访问
├── tests/
│   ├── unit/                 # 单元测试
│   └── integration/          # 集成测试
└── docs/
    └── design/               # 设计文档
```

### 关键组件

| 组件名 | 类型 | 职责 | 所在模块 |
|--------|------|------|---------|
| AlarmLimitSuggestViewModel | ViewModel | 暴露建议列表、用户操作接口 | GUI |
| SuggestionEngine | Service | 聚合多源数据，生成排序后的建议列表 | Core |
| RuleEvaluator | Service | 执行临床规则（如：HR > 120 且 SpO2 < 95%） | Core |
| PatientContextModel | Model | 封装患者当前状态（年龄、诊断、用药） | Core |
| AlarmConfigRepository | Repository | 报警配置持久化与缓存 | Data |

---

## 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 推理引擎位置 | 本地嵌入式（非云端） | 医疗设备离线可用，数据不出设备 |
| 规则表达方式 | 声明式 JSON 规则 + 脚本钩子 | 便于临床专家调整，无需重新编译 |
| UI 展示形式 | 非模态悬浮建议卡片 | 不中断医护工作流，随时可忽略 |
| 学习机制 | 设备级本地学习（不跨患者） | 符合医疗隐私法规，避免数据泄露 |

---

## 外部依赖与约束

- **约束1**: 必须通过 IEC 60601-1-8 报警系统安全标准审查
- **约束2**: 所有建议必须有可追溯的规则来源（不可黑盒）
- **约束3**: 建议生成延迟 < 500ms（不影响实时监护）

---

## 设计演进记录

| 日期 | 变更内容 | 影响范围 |
|------|---------|---------|
| 2026-05-07 | 初始化项目设计文档 | 全部模块 |
