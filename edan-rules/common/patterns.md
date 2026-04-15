---
paths:
  - "**/*"
---
# 通用设计模式（强制性约束）

## 架构模式

| 模式 | 强制场景 | 说明 |
|------|---------|------|
| **Repository Pattern** | 数据层 | 隔离数据访问 |
| **UseCase Pattern** | 复杂业务逻辑 | 封装业务逻辑 |
| **Dependency Injection** | 全项目 | 用 DI 框架，禁止手动创建对象 |

## 数据访问

**Repository 必须遵循**：
- [必须]  返回类型：`suspend` 函数返回 `Result<T>` 或自定义错误类型
- [必须]  响应式流：使用 `Flow` 观察数据变化
- [禁止] 返回可空类型（`User?`）
- [禁止]  Repository 包含业务逻辑

## API 响应格式

所有 API 响应必须包含：
- [必须]  成功/状态指示器
- [必须]  数据载体（错误时可空）
- [必须]  错误消息字段（成功时可空）
- [必须]  分页元数据（total、page、limit）

## 禁止行为

- [禁止]  Service Locator 模式
- [禁止]  ViewModel 直接操作 View
- [禁止]  多个 LiveData/StateFlow（分散状态）
- [禁止]  手动创建对象