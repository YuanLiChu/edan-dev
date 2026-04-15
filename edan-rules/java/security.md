---
paths:
  - "**/*.java"
---
# Java 安全（强制性检查）

> 扩展 [common/security.md](../common/security.md)

## 输入验证

- [必须]  用 Bean Validation（`@Valid`、`@NotNull`、`@NotBlank`）
- [必须]  验证所有 HTTP 请求参数
- [禁止] 信任用户输入

## SQL 注入防护

- [必须]  用 PreparedStatement 或 JPA 参数化查询
- [必须]  用 `jdbcTemplate.query()` 参数化
- [禁止] 字符串拼接 SQL

## 加密算法

- [必须]  用 SHA-256 或更强算法
- [必须]  用 bcrypt 或 Argon2 存储密码
- [必须]  用 AES-256 加密敏感数据
- [禁止] 用 MD5、SHA1

## 机密管理

- [必须]  用环境变量：`System.getenv("API_KEY")`
- [必须]  启动时验证机密存在：`Objects.requireNonNull()`
- [禁止] 硬编码敏感信息

## 错误消息

- [必须]  记录详细错误在服务器端
- [必须]  返回通用错误消息给客户端
- [禁止] 暴露堆栈跟踪、内部路径、SQL 错误

## 禁止行为

- [禁止]  硬编码敏感信息
- [禁止]  明文存储密码
- [禁止]  日志记录敏感信息