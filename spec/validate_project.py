# -*- coding: utf-8 -*-
"""工程级校验：YAML 结构、资源路径、plist/JSON 合法性、Swift 括号配平、target 源码隔离。"""
import json
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = []

try:
    import yaml
except ImportError:
    print("需要 pyyaml：pip install pyyaml")
    sys.exit(2)

spec = yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))
targets = spec.get("targets", {})

# 1. 路径存在性
declared = []
for name, cfg in targets.items():
    for entry in cfg.get("sources", []):
        path = entry if isinstance(entry, str) else entry.get("path")
        declared.append((name, path))
        if not (ROOT / path).exists():
            errors.append(f"{name}: 源码路径不存在 {path}")
    info = cfg.get("info")
    if info:
        declared.append((name, info["path"]))
    ent = cfg.get("entitlements")
    if ent:
        declared.append((name, ent["path"]))

print(f"targets: {', '.join(targets)}")
print(f"源码路径条目: {len(declared)}")

# 2. target 之间的源码隔离
def swift_files(rel):
    p = ROOT / rel
    return {str(f.relative_to(ROOT)) for f in p.rglob("*.swift")} if p.exists() else set()

app_files = swift_files("Sources") | swift_files("Shared")
widget_files = swift_files("Targets/Widgets") | swift_files("Shared/Activity")
watch_files = swift_files("Targets/Watch") | swift_files("Shared/Watch")

overlap = (app_files & widget_files) - {f for f in app_files if f.startswith("Shared")}
if overlap:
    errors.append(f"App 与 Widget 共享了不该共享的文件: {overlap}")

for f in widget_files:
    src = (ROOT / f).read_text(encoding="utf-8")
    if "import SwiftData" in src or "Theme." in src:
        errors.append(f"Widget target 不应对主 App 的持久化/主题产生依赖: {f}")

for f in watch_files:
    src = (ROOT / f).read_text(encoding="utf-8")
    if "import ActivityKit" in src:
        errors.append(f"Watch target 不能引入 ActivityKit: {f}")

# 3. plist / xcprivacy 合法性
for f in ROOT.rglob("*"):
    if f.suffix in {".plist", ".xcprivacy"} and f.is_file():
        try:
            with f.open("rb") as fh:
                plistlib.load(fh)
        except Exception as exc:
            errors.append(f"plist 解析失败 {f.relative_to(ROOT)}: {exc}")

# 4. JSON 合法性
for f in ROOT.rglob("*.json"):
    try:
        json.loads(f.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        errors.append(f"JSON 解析失败 {f.relative_to(ROOT)}: {exc}")

# 5. Swift 括号配平
swift_count = 0
for f in ROOT.rglob("*.swift"):
    swift_count += 1
    s = f.read_text(encoding="utf-8")
    for a, b, label in [("{", "}", "花括号"), ("(", ")", "圆括号")]:
        if s.count(a) != s.count(b):
            errors.append(f"{f.relative_to(ROOT)}: {label}不配平 {s.count(a)}/{s.count(b)}")

print(f"Swift 文件: {swift_count}")

# 6. 关键 Info 配置
# 主 target 现在用显式 Info.plist（targets.TrainLedger.info.properties），
# 只有资源目录名还留在构建设置里。
app_settings = targets["TrainLedger"]["settings"]["base"]
if "ASSETCATALOG_COMPILER_APPICON_NAME" not in app_settings:
    errors.append("App 缺少构建设置: ASSETCATALOG_COMPILER_APPICON_NAME")

app_info = targets["TrainLedger"].get("info", {})
info_props = app_info.get("properties", {})
for key in ["NSSupportsLiveActivities",
            "NSHealthShareUsageDescription",
            "NSHealthUpdateUsageDescription",
            "UILaunchScreen",
            "CFBundleShortVersionString",
            "CFBundleVersion"]:
    if key not in info_props:
        errors.append(f"App Info.plist 缺少键: {key}")

if "GENERATE_INFOPLIST_FILE" in app_settings:
    errors.append("不要再开 GENERATE_INFOPLIST_FILE（与显式 Info.plist 冲突）")

if not (ROOT / "Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").exists():
    errors.append("缺少 1024 图标文件")

if errors:
    print("\n发现问题:")
    for e in errors:
        print(" -", e)
    sys.exit(1)
print("\n工程校验通过")
