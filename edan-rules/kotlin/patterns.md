---
paths:
  - "**/*.kt"
  - "**/*.kts"
---
# Kotlin 设计模式（强制性约束）

## 架构模式

| 模式 | 强制场景 | 说明 |
|------|---------|------|
| **MVVM** | Android/KMP UI 层 | ViewModel + StateFlow |
| **Clean Architecture** | 复杂业务逻辑 | UseCase + Repository |
| **Repository Pattern** | 数据层 | Repository 模式 |
| **UseCase Pattern** | 业务逻辑层 | 复杂业务逻辑用 UseCase |

## Dependency Injection

| 项目类型 | 强制框架 | 说明 |
|---------|---------|------|
| **KMP 多平台** | Koin | 必须用 Koin |
| **Android 专用** | Hilt | 必须用 Hilt |

**禁止**：
- [禁止]  手动创建对象
- [禁止]  Service Locator 模式

## ViewModel Requirements

- [必须]  单一状态对象：`StateFlow<ScreenState>`
- [必须]  事件处理：`sealed interface ScreenEvent`
- [必须]  单向数据流：State → UI → Event → ViewModel → State

**禁止**：
- [禁止]  多个 LiveData/StateFlow（分散状态）
- [禁止]  ViewModel 直接操作 View

## Repository Requirements

- [必须]  返回类型：`suspend` 函数返回 `Result<T>`
- [必须]  响应式流：用 `Flow` 观察数据变化
- [必须]  数据源协调：本地 + 远程

**禁止**：
- [禁止]  返回可空类型（`User?`）
- [禁止]  Repository 包含业务逻辑

## Coroutine Scope

| 场景 | 强制作用域 | 说明 |
|------|-----------|------|
| **ViewModel** | `viewModelScope` | 自动清理 |
| **子任务** | `coroutineScope` | 结构化并发 |
| **独立任务** | `supervisorScope` | 独立失败处理 |

**禁止**：
- [禁止]  使用 `GlobalScope`
- [禁止]  捕获 `CancellationException`