#!/bin/bash
# ════════════════════════════════════════════════════════════════════
# LianYu (恋语) — Android 签名密钥库生成脚本
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
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYSTORE_PATH="${PROJECT_DIR}/release.keystore"

# ── 默认证书信息（可被环境变量覆盖）──
KEY_ALIAS="${LIANYU_KEY_ALIAS:-lianyu}"
CERT_CN="${LIANYU_CERT_CN:-LianYu}"
CERT_OU="${LIANYU_CERT_OU:-LianYu Team}"
CERT_O="${LIANYU_CERT_O:-LianYu}"
CERT_L="${LIANYU_CERT_L:-Beijing}"
CERT_ST="${LIANYU_CERT_ST:-Beijing}"
CERT_C="${LIANYU_CERT_C:-CN}"
VALIDITY_DAYS="${LIANYU_KEY_VALIDITY:-10000}"
KEY_SIZE="${LIANYU_KEY_SIZE:-2048}"

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  LianYu 签名密钥库生成工具${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

# ── 检查 keytool 是否可用 ──
if ! command -v keytool &> /dev/null; then
    echo -e "${RED}❌ 错误：未找到 keytool 工具${NC}"
    echo -e "  请确保 JDK 已安装并添加到 PATH 环境变量"
    echo -e "  项目使用的 JDK 路径：D:\\and studio\\jbr"
    exit 1
fi

# ── 检查是否已存在 keystore ──
if [ -f "$KEYSTORE_PATH" ]; then
    echo -e "${YELLOW}⚠️  警告：密钥库文件已存在：${KEYSTORE_PATH}${NC}"
    read -p "是否覆盖？这将丢失旧密钥！(yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}已取消${NC}"
        exit 0
    fi
    rm -f "$KEYSTORE_PATH"
    echo -e "${GREEN}✓ 已删除旧密钥库${NC}"
fi

# ── 获取密码（优先使用环境变量，否则交互式输入）──
if [ -n "${LIANYU_STORE_PASSWORD:-}" ]; then
    STORE_PASS="$LIANYU_STORE_PASSWORD"
    echo -e "${GREEN}✓ 使用环境变量 LIANYU_STORE_PASSWORD${NC}"
else
    echo -e "${YELLOW}请设置密钥库密码（keystore password）：${NC}"
    read -s STORE_PASS
    if [ -z "$STORE_PASS" ]; then
        echo -e "${RED}❌ 错误：密码不能为空${NC}"
        exit 1
    fi
    # 确认密码
    echo -e "${YELLOW}请再次输入密码以确认：${NC}"
    read -s STORE_PASS_CONFIRM
    if [ "$STORE_PASS" != "$STORE_PASS_CONFIRM" ]; then
        echo -e "${RED}❌ 错误：两次输入的密码不一致${NC}"
        exit 1
    fi
fi

if [ -n "${LIANYU_KEY_PASSWORD:-}" ]; then
    KEY_PASS="$LIANYU_KEY_PASSWORD"
    echo -e "${GREEN}✓ 使用环境变量 LIANYU_KEY_PASSWORD${NC}"
else
    echo ""
    echo -e "${YELLOW}请设置密钥密码（key password）：${NC}"
    read -s KEY_PASS
    if [ -z "$KEY_PASS" ]; then
        echo -e "${RED}❌ 错误：密码不能为空${NC}"
        exit 1
    fi
fi

# ── 构造证书 DN（Distinguished Name）──
DN="CN=${CERT_CN}, OU=${CERT_OU}, O=${CERT_O}, L=${CERT_L}, ST=${CERT_ST}, C=${CERT_C}"

echo ""
echo -e "${CYAN}── 生成参数 ──${NC}"
echo -e "  密钥库路径   : ${KEYSTORE_PATH}"
echo -e "  密钥别名     : ${KEY_ALIAS}"
echo -e "  算法         : RSA"
echo -e "  密钥长度     : ${KEY_SIZE} 位"
echo -e "  签名算法     : SHA256withRSA"
echo -e "  有效期       : ${VALIDITY_DAYS} 天"
echo -e "  证书 DN      : ${DN}"
echo ""

# ── 执行 keytool 生成密钥库 ──
echo -e "${YELLOW}正在生成密钥库...${NC}"
keytool -genkeypair \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize "$KEY_SIZE" \
    -sigalg SHA256withRSA \
    -validity "$VALIDITY_DAYS" \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "$DN"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 密钥库生成失败${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ 密钥库生成成功！${NC}"
echo ""

# ── 验证生成的密钥库 ──
echo -e "${CYAN}── 密钥库信息 ──${NC}"
keytool -list -v \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$STORE_PASS" \
    -alias "$KEY_ALIAS" 2>&1 | head -30

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ 密钥库生成完成${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  重要安全提示：${NC}"
echo -e "  1. 密钥库文件 ${KEYSTORE_PATH} 已在 .gitignore 中排除"
echo -e "     绝对不要提交到版本库或分享给他人"
echo -e "  2. 请将密钥库备份到安全的离线位置（如加密 USB）"
echo -e "  3. CI/CD 环境请通过 GitHub Secrets 注入："
echo -e "     - SIGNING_KEYSTORE_BASE64 : base64 编码的 keystore 文件"
echo -e "     - LIANYU_STORE_PASSWORD   : 密钥库密码"
echo -e "     - LIANYU_KEY_ALIAS        : 密钥别名 (${KEY_ALIAS})"
echo -e "     - LIANYU_KEY_PASSWORD     : 密钥密码"
echo ""
echo -e "${CYAN}  base64 编码命令（用于配置 GitHub Secret）：${NC}"
echo -e "  base64 -w 0 ${KEYSTORE_PATH}"
echo ""
