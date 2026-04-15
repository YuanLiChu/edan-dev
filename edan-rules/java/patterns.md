---
paths:
  - "**/*.java"
---
# Java 设计模式（强制性约束）

## 架构模式

| 模式 | 强制场景 | 说明 |
|------|---------|------|
| **Repository Pattern** | 数据层 | 隔离数据访问 |
| **Service Pattern** | 业务逻辑层 | 封装业务逻辑 |
| **Dependency Injection** | 全项目 | 用 DI 框架 |

## Dependency Injection

- [必须]  用构造函数注入
- [必须]  用 Spring IoC 或 Guice
- [禁止] 手动创建对象
- [禁止] 字段注入
- [禁止]  Service Locator 模式

## Repository Requirements

- [必须]  返回类型：用 `Optional<T>` 处理可空结果
- [必须]  数据访问抽象：用接口定义操作
- [禁止]  Repository 包含业务逻辑

## DTO 映射

- [必须]  DTO 用 `record`（Java 16+）
- [必须]  在服务/控制器边界映射
- [禁止] 直接暴露实体类

## 禁止行为

- [禁止]  Service Locator 模式
- [禁止]  字段注入
- [禁止]  Repository 包含业务逻辑