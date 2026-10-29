#!/usr/bin/env python3
"""omp-models 生成器：读取 agenix 解密的 key 文件，替换模板占位符，写出实际 models.yml。

用法: omp-sync.py <keys_file> <template> <output>
key 文件格式: 每行 `provider: sk-xxx`（provider 名连字符转下划线映射到占位符）。
"""
import socket
import sys

# Magpie 网关地址按本机角色选择：网关所在的 Athena 用回环（Magpie 只对回环免 key，
# 因此 auth: none 合法，也不会被 magpie sync 改回无 key 的 LAN 地址），
# 其他客户端（Apollo、Artemis）用 Athena 的局域网地址并携带 @MAGPIE_KEY@。
MAGPIE_LOOPBACK_URL = "http://127.0.0.1:3425/v1"
MAGPIE_LAN_URL = "http://192.168.100.11:3425/v1"

REQUIRED_PLACEHOLDERS = (
    "@SCI_OPENAI_KEY@",
    "@ANTHROPIC_KEY@",
    "@SCI_PLUS_KEY@",
    "@SCI_PRO_SPECIAL_KEY@",
    "@GEMINI_KEY@",
    "@GLM_KEY@",
    "@DEEPSEEK_KEY@",
    "@NEWAPI_KEY@",
    "@MAGPIE_KEY@",
    "@MAGPIE_BASE_URL@",
)


def magpie_base_url(hostname):
    """网关地址：hostname 为 athena（忽略域名后缀与大小写）时用回环，否则用局域网地址。"""
    return MAGPIE_LOOPBACK_URL if hostname.split(".")[0].lower() == "athena" else MAGPIE_LAN_URL


def read_keys(keys_file):
    keys = {}
    for line in open(keys_file, encoding="utf-8"):
        line = line.strip()
        if not line or ":" not in line:
            continue
        k, _, v = line.partition(":")
        keys[k.strip().upper().replace("-", "_") + "_KEY"] = v.strip()
    return keys


def render(template, keys, hostname):
    content = template.replace("@MAGPIE_BASE_URL@", magpie_base_url(hostname))
    for ph, val in keys.items():
        p = "@" + ph + "@"
        if p in content:
            content = content.replace(p, val)
    return content


def main(argv):
    keys_file, tmpl, out = argv[1], argv[2], argv[3]
    content = render(open(tmpl, encoding="utf-8").read(), read_keys(keys_file), socket.gethostname())
    missing = [chunk for chunk in REQUIRED_PLACEHOLDERS if chunk in content]
    if missing:
        print("omp-sync-models: 模板未替换占位符: %s" % missing, file=sys.stderr)
        return 1
    open(out, "w", encoding="utf-8").write(content)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
