#!/usr/bin/env python3
"""Verify LianYu APK hardening invariants before release.

Checks:
  - APK exists and is a zip
  - classes*.dex do not contain high-value prompt/debug strings
  - classes*.dex do not leak high-signal business/security class names (release only)
  - APK does not contain Compose PreviewActivity
  - release APK is not debuggable by manifest string heuristics

Usage:
  python3 tools/verify_release_apk.py app/build/outputs/apk/debug/app-debug.apk
  python3 tools/verify_release_apk.py app/build/outputs/apk/release/app-release.apk --release
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

SENSITIVE_PATTERNS = [
    "主动消息铁律",
    "主动消息类型参考",
    "字数15-40",
    ">>> SG:",
    "SecurityGuard CRASH",
]

# 高价值业务/安全符号：发布版 DEX 中不应以类名形式残留。
# R8/ProGuard 应将这些类进一步混淆，若在 release DEX 中发现原名，说明混淆配置缺失或被绕过。
BLACKBOX_DEX_PATTERNS = [
    "ChatMessageCrypto",          # 聊天消息加密入口（密钥派生/解密占位）
    "ApiConfigSecretCodec",       # API 配置项的加解密封装
    "RequestSecurityInterceptor", # 请求安全拦截器（签名/防重放）
    "M0",                         # 微信消息模型（短名混淆 stub）
    "A0",                         # 微信账号/令牌模型（短名混淆 stub）
]

FORBIDDEN_COMPONENTS = [
    "androidx.compose.ui.tooling.PreviewActivity",
]


def printable_strings(data: bytes, min_len: int = 4) -> list[str]:
    out: list[str] = []
    current = bytearray()
    for byte in data:
        if 32 <= byte <= 126:
            current.append(byte)
        else:
            if len(current) >= min_len:
                out.append(current.decode("latin1", errors="ignore"))
            current.clear()
    if len(current) >= min_len:
        out.append(current.decode("latin1", errors="ignore"))
    return out


def read_entries(apk: zipfile.ZipFile, pattern: re.Pattern[str]) -> bytes:
    chunks: list[bytes] = []
    for name in sorted(apk.namelist()):
        if pattern.fullmatch(name):
            chunks.append(apk.read(name))
    return b"".join(chunks)


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def check_blackbox_patterns(dex_text: str) -> None:
    """扫描 release DEX 中是否残留高价值业务/安全类名。

    使用前后非单词字符边界匹配，避免短名（M0/A0）误报为随机子串。
    """
    for symbol in BLACKBOX_DEX_PATTERNS:
        pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(symbol)}(?![A-Za-z0-9_])")
        if pattern.search(dex_text):
            fail(f"blackbox-sensitive symbol found in release DEX: {symbol}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    if not args.apk.exists():
        fail(f"APK not found: {args.apk}")

    with zipfile.ZipFile(args.apk, "r") as apk:
        names = set(apk.namelist())
        dex_names = [name for name in names if re.fullmatch(r"classes\d*\.dex", name)]
        if not dex_names:
            fail("no classes*.dex found")

        dex_bytes = read_entries(apk, re.compile(r"classes\d*\.dex"))
        dex_text = "\n".join(printable_strings(dex_bytes))
        for pattern in SENSITIVE_PATTERNS:
            if pattern in dex_text:
                fail(f"sensitive string found in DEX: {pattern}")

        all_text = dex_text
        if "AndroidManifest.xml" in names:
            all_text += "\n" + "\n".join(printable_strings(apk.read("AndroidManifest.xml")))
        if args.release:
            # 发布版额外检查：DEX 中不得残留高价值业务/安全类名
            check_blackbox_patterns(dex_text)

            for component in FORBIDDEN_COMPONENTS:
                if component in all_text:
                    fail(f"forbidden debug component found: {component}")

            if "android:debuggable" in all_text:
                fail("release manifest appears to contain android:debuggable")

    print(f"OK: {args.apk}")
    print("OK: no sensitive prompt/debug strings in DEX")
    if args.release:
        print("OK: no blackbox-sensitive symbols in release DEX")
        print("OK: no forbidden debug components found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
