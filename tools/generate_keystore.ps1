# ════════════════════════════════════════════════════════════════════
# LianYu (恋语) — Android 签名密钥库生成脚本 (PowerShell 版本)
# ════════════════════════════════════════════════════════════════════
# 功能：使用 keytool 生成符合安全标准的 RSA 密钥库
#
# 安全标准：
#   - 算法：RSA
#   - 密钥长度：2048 位（满足 NIST SP 800-131A 推荐）
#   - 签名算法：SHA256withRSA（避免 SHA1）
#   - 有效期：10000 天（约 27 年）
#   - 密码通过环境变量或交互式输入，绝不硬编码
#
# ⚠️  安全警告：
#   生成的 release.keystore 是应用签名的根密钥，一旦泄露：
#     1. 攻击者可以伪造相同签名的恶意应用
#     2. 无法在不更换签名（导致用户需卸载重装）的情况下撤销
#   因此该文件已在 .gitignore 中排除，永远不要提交到版本库！
#   CI 环境请通过 GitHub Secrets 注入（见 .github/workflows/android-build.yml）
# ════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$KeyStorePath = Join-Path $ProjectDir "release.keystore"

# ── 默认证书信息（可被环境变量覆盖）──
$KeyAlias = if ($env:LIANYU_KEY_ALIAS) { $env:LIANYU_KEY_ALIAS } else { "lianyu" }
$CertCN = if ($env:LIANYU_CERT_CN) { $env:LIANYU_CERT_CN } else { "LianYu" }
$CertOU = if ($env:LIANYU_CERT_OU) { $env:LIANYU_CERT_OU } else { "LianYu Team" }
$CertO = if ($env:LIANYU_CERT_O) { $env:LIANYU_CERT_O } else { "LianYu" }
$CertL = if ($env:LIANYU_CERT_L) { $env:LIANYU_CERT_L } else { "Beijing" }
$CertST = if ($env:LIANYU_CERT_ST) { $env:LIANYU_CERT_ST } else { "Beijing" }
$CertC = if ($env:LIANYU_CERT_C) { $env:LIANYU_CERT_C } else { "CN" }
$ValidityDays = if ($env:LIANYU_KEY_VALIDITY) { [int]$env:LIANYU_KEY_VALIDITY } else { 10000 }
$KeySize = if ($env:LIANYU_KEY_SIZE) { [int]$env:LIANYU_KEY_SIZE } else { 2048 }

function Write-ColorHost($Message, $Color = "White") {
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorHost "════════════════════════════════════════════════════" "Cyan"
Write-ColorHost "  LianYu 签名密钥库生成工具 (PowerShell)" "Cyan"
Write-ColorHost "════════════════════════════════════════════════════" "Cyan"
Write-Host ""

# ── 检查 keytool 是否可用 ──
$KeyTool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $KeyTool) {
    # 尝试项目自带的 JBR
    $JbrKeytool = "D:\and studio\jbr\bin\keytool.exe"
    if (Test-Path $JbrKeytool) {
        $KeyToolExe = $JbrKeytool
        Write-ColorHost "✓ 使用项目 JDK 的 keytool: $KeyToolExe" "Green"
    } else {
        Write-ColorHost "❌ 错误：未找到 keytool 工具" "Red"
        Write-ColorHost "  请确保 JDK 已安装并添加到 PATH 环境变量" "Yellow"
        Write-ColorHost "  项目使用的 JDK 路径：D:\and studio\jbr" "Yellow"
        exit 1
    }
} else {
    $KeyToolExe = $KeyTool.Source
    Write-ColorHost "✓ 找到 keytool: $KeyToolExe" "Green"
}

# ── 检查是否已存在 keystore ──
if (Test-Path $KeyStorePath) {
    Write-ColorHost "⚠️  警告：密钥库文件已存在：$KeyStorePath" "Yellow"
    $Confirm = Read-Host "是否覆盖？这将丢失旧密钥！(yes/no)"
    if ($Confirm -ne "yes") {
        Write-ColorHost "已取消" "Red"
        exit 0
    }
    Remove-Item $KeyStorePath -Force
    Write-ColorHost "✓ 已删除旧密钥库" "Green"
}

# ── 获取密码（优先使用环境变量，否则交互式输入）──
if ($env:LIANYU_STORE_PASSWORD) {
    $StorePass = $env:LIANYU_STORE_PASSWORD
    Write-ColorHost "✓ 使用环境变量 LIANYU_STORE_PASSWORD" "Green"
} else {
    $StorePass = Read-Host "请设置密钥库密码（keystore password）" -AsSecureString
    $StorePass = [System.Net.NetworkCredential]::new("", $StorePass).Password
    if (-not $StorePass) {
        Write-ColorHost "❌ 错误：密码不能为空" "Red"
        exit 1
    }
    $StorePassConfirm = Read-Host "请再次输入密码以确认" -AsSecureString
    $StorePassConfirm = [System.Net.NetworkCredential]::new("", $StorePassConfirm).Password
    if ($StorePass -ne $StorePassConfirm) {
        Write-ColorHost "❌ 错误：两次输入的密码不一致" "Red"
        exit 1
    }
}

if ($env:LIANYU_KEY_PASSWORD) {
    $KeyPass = $env:LIANYU_KEY_PASSWORD
    Write-ColorHost "✓ 使用环境变量 LIANYU_KEY_PASSWORD" "Green"
} else {
    Write-Host ""
    $KeyPass = Read-Host "请设置密钥密码（key password）" -AsSecureString
    $KeyPass = [System.Net.NetworkCredential]::new("", $KeyPass).Password
    if (-not $KeyPass) {
        Write-ColorHost "❌ 错误：密码不能为空" "Red"
        exit 1
    }
}

# ── 构造证书 DN（Distinguished Name）──
$DN = "CN=$CertCN, OU=$CertOU, O=$CertO, L=$CertL, ST=$CertST, C=$CertC"

Write-Host ""
Write-ColorHost "── 生成参数 ──" "Cyan"
Write-Host "  密钥库路径   : $KeyStorePath"
Write-Host "  密钥别名     : $KeyAlias"
Write-Host "  算法         : RSA"
Write-Host "  密钥长度     : $KeySize 位"
Write-Host "  签名算法     : SHA256withRSA"
Write-Host "  有效期       : $ValidityDays 天"
Write-Host "  证书 DN      : $DN"
Write-Host ""

# ── 执行 keytool 生成密钥库 ──
Write-ColorHost "正在生成密钥库..." "Yellow"
& $KeyToolExe -genkeypair `
    -alias $KeyAlias `
    -keyalg RSA `
    -keysize $KeySize `
    -sigalg SHA256withRSA `
    -validity $ValidityDays `
    -keystore $KeyStorePath `
    -storepass $StorePass `
    -keypass $KeyPass `
    -dname $DN

if ($LASTEXITCODE -ne 0) {
    Write-ColorHost "❌ 密钥库生成失败" "Red"
    exit 1
}

Write-Host ""
Write-ColorHost "✓ 密钥库生成成功！" "Green"
Write-Host ""

# ── 验证生成的密钥库 ──
Write-ColorHost "── 密钥库信息 ──" "Cyan"
& $KeyToolExe -list -v `
    -keystore $KeyStorePath `
    -storepass $StorePass `
    -alias $KeyAlias 2>&1 | Select-Object -First 30

Write-Host ""
Write-ColorHost "════════════════════════════════════════════════════" "Cyan"
Write-ColorHost "  ✓ 密钥库生成完成" "Green"
Write-ColorHost "════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-ColorHost "⚠️  重要安全提示：" "Yellow"
Write-Host "  1. 密钥库文件 $KeyStorePath 已在 .gitignore 中排除"
Write-Host "     绝对不要提交到版本库或分享给他人"
Write-Host "  2. 请将密钥库备份到安全的离线位置（如加密 USB）"
Write-Host "  3. CI/CD 环境请通过 GitHub Secrets 注入："
Write-Host "     - SIGNING_KEYSTORE_BASE64 : base64 编码的 keystore 文件"
Write-Host "     - LIANYU_STORE_PASSWORD   : 密钥库密码"
Write-Host "     - LIANYU_KEY_ALIAS        : 密钥别名 ($KeyAlias)"
Write-Host "     - LIANYU_KEY_PASSWORD     : 密钥密码"
Write-Host ""
Write-ColorHost "  base64 编码命令（用于配置 GitHub Secret）：" "Cyan"
Write-Host "  [Convert]::ToBase64String([IO.File]::ReadAllBytes('$KeyStorePath'))"
Write-Host ""
