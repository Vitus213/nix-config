#!/usr/bin/env python3
"""omp-models 生成器：读取 agenix 解密的 key 文件，替换模板占位符，写出实际 models.yml。

用法: omp-sync.py <keys_file> <template> <output>
key 文件格式: 每行 `provider: sk-xxx`（provider 名连字符转下划线映射到占位符）。
"""
import sys

keys_file, tmpl, out = sys.argv[1], sys.argv[2], sys.argv[3]
keys = {}
for line in open(keys_file, encoding="utf-8"):
    line = line.strip()
    if not line or ":" not in line:
        continue
    k, _, v = line.partition(":")
    keys[k.strip().upper().replace("-", "_") + "_KEY"] = v.strip()
content = open(tmpl, encoding="utf-8").read()
for ph, val in keys.items():
    p = "@" + ph + "@"
    if p in content:
        content = content.replace(p, val)
missing = [
    chunk
    for chunk in (
        "@OPENAI_KEY@",
        "@ANTHROPIC_KEY@",
        "@SCI_PLUS_KEY@",
        "@SCI_PRO_SPECIAL_KEY@",
        "@BAILIAN_KEY@",
        "@GEMINI_KEY@",
    )
    if chunk in content
]
if missing:
    print("omp-sync-models: 模板未替换占位符: %s" % missing, file=sys.stderr)
    sys.exit(1)
open(out, "w", encoding="utf-8").write(content)