#!/usr/bin/env python3
"""检查所有语言文件的 key 是否一致"""
import json, sys, pathlib

locales_dir = pathlib.Path(__file__).parent.parent / "locales"
files = sorted(locales_dir.glob("*.json"))

if not files:
    print("❌ 未找到任何语言文件")
    sys.exit(1)

all_keys = {}
for f in files:
    all_keys[f.stem] = set(json.loads(f.read_text()).keys())

reference = all_keys.get("en", set())
ok = True
for lang, keys in all_keys.items():
    missing = reference - keys
    extra = keys - reference
    if missing:
        print(f"❌ {lang}.json 缺少: {sorted(missing)}")
        ok = False
    if extra:
        print(f"⚠️  {lang}.json 多余: {sorted(extra)}")

if ok:
    print(f"✅ 所有语言文件 key 一致（{len(reference)} 个 key，{len(files)} 种语言）")
sys.exit(0 if ok else 1)
