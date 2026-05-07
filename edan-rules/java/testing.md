---
paths:
  - "**/*.java"
---
# Java 测试（强制性约束）

## 测试框架

- [必须]  用 JUnit 5 作主测试框架
- [必须]  用 Mockito 进行 Mock
- [必须]  用 AssertJ 进行断言
- [必须]  用 Testcontainers 进行集成测试

## 覆盖率要求

| 类型 | 最低覆盖率 | 目标覆盖率 |
|------|-----------|-----------|
| **整体项目** | ≥80% | 85% |
| **核心业务逻辑** | 100% | 100% |
| **工具类** | ≥70% | 85% |

## 测试命名

用描述性命名：
- [必须]  方法名：`methodName_scenario_expectedBehavior()`
- [必须]  用 `@DisplayName` 注解提供可读描述

## 测试组织

```
src/test/java/com/example/app/
  service/           # 服务层单元测试
  controller/        # Web 层 / API 测试
  repository/        # 数据访问测试
  integration/       # 跨层集成测试
```

- [必须]  测试文件与源文件同目录结构
- [必须]  测试类命名：`<ClassName>Test`

## 禁止行为

- [禁止]  跳过测试（不使用 `@Disabled`）
- [禁止]  测试私有方法
- [禁止]  测试中包含复杂逻辑