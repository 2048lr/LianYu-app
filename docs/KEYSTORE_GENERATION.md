# LianYu 签名密钥库生成指南

本文档详细介绍如何使用 `keytool` 工具为 LianYu (恋语) Android 应用生成符合安全标准的签名密钥库。

## 目录

- [1. 概述](#1-概述)
- [2. 前置条件](#2-前置条件)
- [3. 快速开始](#3-快速开始)
- [4. keytool 命令参数详解](#4-keytool-命令参数详解)
- [5. 安全注意事项](#5-安全注意事项)
- [6. 配置 GitHub Secrets](#6-配置-github-secrets)
- [7. 本地构建配置](#7-本地构建配置)
- [8. 验证密钥库](#8-验证密钥库)
- [9. 常见问题](#9-常见问题)

---

## 1. 概述

Android 应用必须使用密钥库（keystore）中的私钥进行签名，才能在设备上安装或发布到应用商店。LianYu 项目使用自定义签名机制，所有敏感信息通过环境变量或 GitHub Secrets 注入，**绝不硬编码到代码或脚本中**。

### 安全标准

| 项目 | 标准 | 说明 |
|------|------|------|
| 密钥算法 | RSA | 广泛使用的非对称加密算法 |
| 密钥长度 | 2048 位 | 满足 NIST SP 800-131A 推荐（2030 年后可用）|
| 签名算法 | SHA256withRSA | 避免使用已不安全的 SHA1 |
| 有效期 | 10000 天（约 27 年）| 长有效期避免频繁更换签名 |
| 密钥库类型 | JKS | Java KeyStore，keytool 默认格式 |

---

## 2. 前置条件

### 2.1 安装 JDK

需要 JDK 8 或更高版本（项目使用 JDK 17）。`keytool` 随 JDK 一起安装。

**检查 keytool 是否可用：**

```bash
# Linux / macOS
keytool -help

# Windows (PowerShell)
Get-Command keytool
```

如果 keytool 不在 PATH 中，可以使用项目自带的 JBR：
- Windows: `D:\and studio\jbr\bin\keytool.exe`
- macOS/Linux: `/path/to/android-studio/jbr/bin/keytool`

### 2.2 项目环境

- LianYu 项目已克隆到本地
- 位于项目根目录执行脚本
- `release.keystore` 文件已在 `.gitignore` 中排除（第 24 行）

---

## 3. 快速开始

### 方式一：使用生成脚本（推荐）

项目提供了两个一键生成脚本，密码通过环境变量或交互式输入：

**Linux / macOS：**
```bash
# 交互式输入密码
./tools/generate_keystore.sh

# 或通过环境变量（适合 CI）
LIANYU_STORE_PASSWORD="你的密码" \
LIANYU_KEY_PASSWORD="你的密码" \
LIANYU_KEY_ALIAS="lianyu" \
./tools/generate_keystore.sh
```

**Windows (PowerShell)：**
```powershell
# 交互式输入密码
.\tools\generate_keystore.ps1

# 或通过环境变量（适合 CI）
$env:LIANYU_STORE_PASSWORD = "你的密码"
$env:LIANYU_KEY_PASSWORD = "你的密码"
$env:LIANYU_KEY_ALIAS = "lianyu"
.\tools\generate_keystore.ps1
```

### 方式二：手动执行 keytool

如果需要完全自定义，可手动执行 keytool 命令：

```bash
keytool -genkeypair \
    -alias lianyu \
    -keyalg RSA \
    -keysize 2048 \
    -sigalg SHA256withRSA \
    -validity 10000 \
    -keystore release.keystore \
    -storepass "你的keystore密码" \
    -keypass "你的密钥密码" \
    -dname "CN=LianYu, OU=LianYu Team, O=LianYu, L=Beijing, ST=Beijing, C=CN"
```

---

## 4. keytool 命令参数详解

以脚本中的核心命令为例：

```bash
keytool -genkeypair \
    -alias lianyu \
    -keyalg RSA \
    -keysize 2048 \
    -sigalg SHA256withRSA \
    -validity 10000 \
    -keystore release.keystore \
    -storepass **** \
    -keypass **** \
    -dname "CN=LianYu, OU=LianYu Team, O=LianYu, L=Beijing, ST=Beijing, C=CN"
```

### 参数说明

| 参数 | 值 | 说明 |
|------|------|------|
| `-genkeypair` | — | 生成密钥对（公钥 + 私钥）和自签名证书 |
| `-alias` | `lianyu` | 密钥条目的别名，用于在 keystore 中唯一标识该密钥。一个 keystore 可包含多个别名 |
| `-keyalg` | `RSA` | 密钥算法。RSA 是 Android 应用签名的标准选择 |
| `-keysize` | `2048` | 密钥长度（位）。2048 是当前安全基线，4096 更安全但签名更慢 |
| `-sigalg` | `SHA256withRSA` | 证书签名算法。使用 SHA-256 哈希 + RSA 签名，避免 SHA1 的安全弱点 |
| `-validity` | `10000` | 证书有效期（天），约 27 年。Google Play 要求至少到 2033 年 |
| `-keystore` | `release.keystore` | 输出的 keystore 文件路径 |
| `-storepass` | `****` | keystore 文件的访问密码。保护整个 keystore 文件 |
| `-keypass` | `****` | 私钥的访问密码。保护单个密钥条目，可与 storepass 不同 |
| `-dname` | `CN=...` | 证书的 X.500 Distinguished Name（标识信息） |

### Distinguished Name (DN) 字段说明

DN 是证书中的身份标识信息：

| 字段 | 含义 | 示例值 | 可选 |
|------|------|--------|------|
| `CN` | Common Name（通用名称）| `LianYu` | 必填 |
| `OU` | Organizational Unit（组织单位）| `LianYu Team` | 可选 |
| `O` | Organization（组织）| `LianYu` | 可选 |
| `L` | Locality（城市）| `Beijing` | 可选 |
| `ST` | State/Province（省/州）| `Beijing` | 可选 |
| `C` | Country（国家代码，2 字母）| `CN` | 可选 |

**通过环境变量自定义 DN：**
```bash
LIANYU_CERT_CN="MyName" \
LIANYU_CERT_OU="MyOrg" \
LIANYU_CERT_C="US" \
./tools/generate_keystore.sh
```

---

## 5. 安全注意事项

### 5.1 密钥库文件安全

> ⚠️ **关键警告**：`release.keystore` 是应用签名的根密钥。一旦泄露：
> 1. 攻击者可以伪造相同签名的恶意应用，冒充你的应用身份
> 2. 用户设备上的应用更新机制可能被利用
> 3. 更换签名会导致用户必须卸载旧版本才能安装新版本
> 4. Google Play 上的应用签名密钥无法撤销（只能通过 Google Play App Signing 重新注册）

**安全措施：**
- ✅ `release.keystore` 已在 `.gitignore` 中排除（第 24 行）
- ✅ 脚本中不硬编码任何密码
- ✅ 密码通过环境变量或交互式输入
- ✅ CI 环境通过 GitHub Secrets 注入

### 5.2 密码安全要求

**强密码建议：**
- 长度至少 16 个字符
- 包含大小写字母、数字、特殊符号
- 不使用字典单词或个人信息
- keystore 密码和密钥密码建议不同

**密码存储方式：**

| 方式 | 安全性 | 适用场景 |
|------|--------|---------|
| 交互式输入 | ⭐⭐⭐⭐⭐ | 本地开发 |
| 环境变量 | ⭐⭐⭐⭐ | CI/CD（GitHub Actions）|
| GitHub Secrets | ⭐⭐⭐⭐⭐ | CI/CD（加密存储）|
| `~/.gradle/gradle.properties` | ⭐⭐⭐ | 本地开发（不提交到 repo）|
| 硬编码到脚本 | ❌ 禁止 | 任何情况 |

### 5.3 备份策略

**强烈建议：**
1. 将 `release.keystore` 备份到**至少两个**不同的离线介质（如加密 USB、离线硬盘）
2. 记录密码到安全的密码管理器（如 KeePass、1Password）
3. 不要将 keystore 和密码存储在同一位置
4. 团队协作时，keystore 应由受信任的发布管理员保管

### 5.4 密钥轮换

如果密钥泄露或怀疑泄露：
1. **立即**生成新密钥库
2. 更新所有 GitHub Secrets
3. 通知用户下一次更新需要卸载重装
4. 如使用 Google Play App Signing，可通过控制台申请密钥升级

---

## 6. 配置 GitHub Secrets

生成 keystore 后，需要在 GitHub 仓库中配置以下 Secrets，以便 CI 自动签名：

### 6.1 获取 keystore 的 base64 编码

**Linux / macOS：**
```bash
base64 -w 0 release.keystore
```

**Windows (PowerShell)：**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore"))
```

### 6.2 在 GitHub 仓库添加 Secrets

1. 进入 GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions**
2. 点击 **New repository secret**
3. 添加以下 4 个 Secrets：

| Secret 名称 | 值 | 说明 |
|-------------|------|------|
| `SIGNING_KEYSTORE_BASE64` | base64 编码字符串 | keystore 文件内容（上一步获取）|
| `LIANYU_STORE_PASSWORD` | keystore 密码 | 你设置的 storepass |
| `LIANYU_KEY_ALIAS` | `lianyu` | 密钥别名（默认 lianyu）|
| `LIANYU_KEY_PASSWORD` | 密钥密码 | 你设置的 keypass |

### 6.3 验证 Secrets 配置

配置完成后，推送代码到 `main` 分支，GitHub Actions 会自动：
1. 从 `SIGNING_KEYSTORE_BASE64` 解码 keystore 文件
2. 通过环境变量注入密码
3. 构建 Release APK 并使用自定义签名
4. 使用 `apksigner verify` 验证签名
5. 构建完成后删除 runner 上的 keystore 文件

查看工作流文件：[.github/workflows/android-build.yml](../.github/workflows/android-build.yml)

---

## 7. 本地构建配置

### 7.1 使用环境变量

```bash
# Linux / macOS
export LIANYU_STORE_PASSWORD="你的密码"
export LIANYU_KEY_ALIAS="lianyu"
export LIANYU_KEY_PASSWORD="你的密码"
./gradlew assembleRelease

# Windows (PowerShell)
$env:LIANYU_STORE_PASSWORD = "你的密码"
$env:LIANYU_KEY_ALIAS = "lianyu"
$env:LIANYU_KEY_PASSWORD = "你的密码"
.\gradlew assembleRelease
```

### 7.2 使用 ~/.gradle/gradle.properties

在用户主目录的 `~/.gradle/gradle.properties`（不是项目内的）中添加：

```properties
LIANYU_STORE_PASSWORD=你的密码
LIANYU_KEY_ALIAS=lianyu
LIANYU_KEY_PASSWORD=你的密码
```

项目内的 [gradle.properties](../gradle.properties) 已移除所有硬编码密码，仅保留说明注释。`app/build.gradle.kts` 会依次从环境变量和 gradle properties 中读取。

---

## 8. 验证密钥库

### 8.1 查看密钥库内容

```bash
keytool -list -v \
    -keystore release.keystore \
    -storepass "你的密码" \
    -alias lianyu
```

### 8.2 验证 APK 签名

构建完成后，使用 apksigner 验证：

```bash
# 查找 apksigner（在 Android SDK build-tools 中）
APKSIGNER=$(find $ANDROID_HOME -name apksigner -type f | head -1)

# 验证签名
$APKSIGNER verify --verbose app/build/outputs/apk/release/app-release.apk
```

预期输出包含：
```
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

### 8.3 提取证书指纹

```bash
keytool -list -v \
    -keystore release.keystore \
    -storepass "你的密码" \
    -alias lianyu | grep -A1 "SHA1\|SHA256"
```

---

## 9. 常见问题

### Q1: keytool 命令找不到

**解决方案：**
- 确认 JDK 已安装
- Windows: 使用项目 JBR 路径 `D:\and studio\jbr\bin\keytool.exe`
- macOS/Linux: 检查 `JAVA_HOME/bin` 是否在 PATH 中

### Q2: 密码忘记了怎么办

**无法找回。** keytool 不提供密码恢复功能。需要：
1. 生成新的 keystore
2. 更新所有 GitHub Secrets
3. 通知用户需要卸载重装（签名变更）

### Q3: 能否复用同一 keystore 签名多个应用

**技术上可以但不推荐。** 最佳实践是每个应用使用独立的 keystore，避免单点泄露影响多个应用。

### Q4: 密钥库应该提交到 Git 吗

**绝对不要。** `release.keystore` 已在 `.gitignore` 中排除。提交到版本库会导致：
1. 任何能访问仓库的人都可以伪造你的应用签名
2. 即使仓库是私有的，也可能在未来变为公开
3. Git 历史无法真正删除（即使 force push）

### Q5: 如何更换签名密钥

1. 运行 `./tools/generate_keystore.sh` 生成新 keystore
2. 更新 GitHub Secrets 中的 4 个值
3. 推送代码触发 CI 重建
4. **注意**：已安装旧版本的用户需要卸载后才能安装新签名版本

### Q6: 为什么脚本中不使用 4096 位密钥

4096 位 RSA 密钥更安全，但：
- 签名速度慢 4-6 倍
- APK 体积增加约 1-2KB（可忽略）
- 2048 位在可预见的未来仍然是安全的
- 如需更高安全性，可通过环境变量 `LIANYU_KEY_SIZE=4096` 指定

---

## 相关文件

- 生成脚本（Bash）: [tools/generate_keystore.sh](../tools/generate_keystore.sh)
- 生成脚本（PowerShell）: [tools/generate_keystore.ps1](../tools/generate_keystore.ps1)
- GitHub Actions 工作流: [.github/workflows/android-build.yml](../.github/workflows/android-build.yml)
- 签名配置（Gradle）: [app/build.gradle.kts](../app/build.gradle.kts)
- Git 忽略规则: [.gitignore](../.gitignore)（第 24 行 `release.keystore`）

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-07-06 | 初始版本，RSA 2048 + SHA256withRSA，10000 天有效期 |
