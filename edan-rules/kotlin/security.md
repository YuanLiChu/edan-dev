---
paths:
  - "**/*.kt"
  - "**/*.kts"
---
# Kotlin 安全

> 扩展 [common/security.md](../common/security.md)

## 机密管理

- [禁止] 源代码中硬编码 API 密钥、令牌或凭据
- [必须]  用 `local.properties`（git 忽略）存储本地开发机密
- [必须]  用从 CI 机密生成的 `BuildConfig` 字段用于发布构建
- [必须]  用 `EncryptedSharedPreferences`（Android）或 Keychain（iOS）存储运行时机密

```kotlin
// 错误：
val apiKey = "sk-abc123..."

// 正确： — 来自 BuildConfig（构建时生成）
val apiKey = BuildConfig.API_KEY

// 正确： — 来自运行时安全存储
val token = secureStorage.get("auth_token")
```

## 网络安全

- [必须]  只用 HTTPS — 配置 `network_security_config.xml` 阻止明文流量
- [必须]  用 OkHttp `CertificatePinner` 或 Ktor 等效方法对敏感端点进行证书固定
- [必须]  为所有 HTTP 客户端设置超时 — 保留默认值（可能是无限的）
- [必须]  用前验证和净化所有服务器响应

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

## 输入验证

- [必须]  处理或发送到 API 前验证所有用户输入
- [必须]  对 Room/SQLDelight 用参数化查询 — 不将用户输入连接到 SQL
- [必须]  净化来自用户输入的文件路径以防止路径遍历

```kotlin
// 错误： — SQL 注入
@Query("SELECT * FROM items WHERE name = '$input'")

// 正确： — 参数化
@Query("SELECT * FROM items WHERE name = :input")
fun findByName(input: String): List<ItemEntity>
```

## 数据保护

- [必须]  在 Android 上用 `EncryptedSharedPreferences` 存储敏感键值数据
- [必须]  用带有显式字段名的 `@Serializable` — 不泄露内部属性名
- [必须]  不再需要时从内存清除敏感数据
- [必须]  对序列化类用 `@Keep` 或 ProGuard 规则以防止名称混淆

## 认证

- [必须]  将令牌存储在安全存储中，而非普通 SharedPreferences
- [必须]  实现具有适当 401/403 处理的令牌刷新
- [必须]  注销时清除所有认证状态（令牌、缓存的用户数据、cookie）
- [必须]  对敏感操作用生物识别认证（`BiometricPrompt`）

## ProGuard / R8

- [必须]  为所有序列化模型保留规则（`@Serializable`、Gson、Moshi）
- [必须]  为基于反射的库保留规则（Koin、Retrofit）
- [必须]  测试发布构建 — 混淆可能静默破坏序列化

## WebView 安全

- [必须]  除非明确需要，否则禁用 JavaScript：`settings.javaScriptEnabled = false`
- [必须]  在 WebView 中加载前验证 URL
- [禁止] 暴露访问敏感数据的 `@JavascriptInterface` 方法
- [必须]  用 `WebViewClient.shouldOverrideUrlLoading()` 控制导航