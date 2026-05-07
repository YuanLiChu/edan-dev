---
paths:
  - "**/*.java"
---
# Java 编码风格（强制性约束）

## 格式化

- [必须]  用 4 空格缩进
- [必须]  每行最多 120 字符
- [必须]  每个文件一个公共顶级类型
- [必须]  用 Checkstyle 或 SpotBugs

## 不可变性

- [必须]  值类型用 `record`（Java 16+）
- [必须]  默认字段 `final`
- [必须]  用不可变集合（`List.of()`、`Set.of()`）
- [必须]  返回防御性副本：`List.copyOf()`
- [禁止] 公共字段

## 命名约定

遵循官方约定：
- [必须]  类和接口：`PascalCase`
- [必须]  方法和变量：`camelCase`
- [必须]  常量：`SCREAMING_SNAKE_CASE`
- [必须]  包名：全小写

## Optional 使用

- [必须]  查找方法返回 `Optional<T>`
- [必须]  用 `map()`、`flatMap()`、`orElseThrow()`
- [禁止]  `Optional` 用作字段类型或方法参数
- [禁止] 无 `isPresent()` 时调用 `get()`

## 空安全

- [必须]  用 `Optional<T>` 处理可空值
- [禁止] 返回 `null`（用 `Optional`）
- [禁止] 传递 `null` 参数

## 现代 Java 特性

- [必须]  记录（`record`）用于 DTO（Java 16+）
- [必须]  密封类（`sealed`）用于封闭类型（Java 17+）
- [必须]  instanceof 模式匹配（Java 16+）
- [必须]  Switch 表达式（Java 14+）

## 错误处理

- [必须]  用自定义异常类型
- [必须]  异常消息清晰描述错误
- [禁止] 捕获通用异常（`Exception`）
- [禁止] 空 `catch` 块

## 禁止行为

- [禁止]  使用原始类型（`List` 而非 `List<String>`）
- [禁止]  公共字段
- [禁止]  字段注入