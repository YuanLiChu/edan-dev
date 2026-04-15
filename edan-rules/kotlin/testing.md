---
paths:
  - "**/*.kt"
  - "**/*.kts"
---
# Kotlin 测试（强制性约束）

## 测试框架

| 项目类型 | 强制框架 | 说明 |
|---------|---------|------|
| **KMP 多平台** | kotlin.test | 必须用 kotlin.test |
| **Android 专用** | JUnit 4/5 | 必须用 JUnit |
| **Flow 测试** | Turbine | StateFlow 测试必须用 |
| **协程测试** | kotlinx-coroutines-test | 挂起函数测试必须用 |

## 覆盖率要求

| 类型 | 最低覆盖率 | 目标覆盖率 |
|------|-----------|-----------|
| **整体项目** | ≥80% | 85% |
| **核心业务逻辑** | 100% | 100% |

**核心业务逻辑**：ViewModel、Repository、UseCase

## 测试命名

用反引号命名：
- [必须]  `` `should xxx when yyy` ``
- [必须]  格式：`should_<预期结果>_when_<触发条件>`

```kotlin
@Test
fun `should return user when id exists`() = runTest { }
```

## 测试组织

```
src/
├── commonTest/kotlin/          # KMP 共享测试
├── androidUnitTest/kotlin/     # Android 单元测试
├── androidInstrumentedTest/    # Android 插桩测试
└── iosTest/kotlin/             # iOS 特定测试
```

- [必须]  测试文件与源文件同目录结构
- [必须]  测试类命名：`<ClassName>Test`

## 禁止行为

- [禁止]  跳过测试（不使用 `@Disabled`、`@Ignore`）
- [禁止]  降低覆盖率标准
- [禁止]  测试私有方法
- [禁止]  测试中包含复杂逻辑