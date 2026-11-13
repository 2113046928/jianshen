# -*- coding: utf-8 -*-
"""没有编译器时的兜底：检查每个 Swift 文件是否 import 了它用到的框架。"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

RULES = [
    (r"ObservableObject|@Published|@StateObject|@ObservedObject", {"Combine", "SwiftUI"}, "Combine"),
    (r"@Model|@Query|@Relationship|ModelContext|FetchDescriptor", {"SwiftData"}, "SwiftData"),
    (r"\bColor\(", {"SwiftUI"}, "SwiftUI"),
    (r"some View|:\s*View\b", {"SwiftUI"}, "SwiftUI"),
    (r"\bHK\w+", {"HealthKit"}, "HealthKit"),
    (r"Activity<|ActivityContent|ActivityAttributes", {"ActivityKit"}, "ActivityKit"),
    (r"WCSession", {"WatchConnectivity"}, "WatchConnectivity"),
    (r"WidgetBundle|WidgetConfiguration|ActivityConfiguration|DynamicIsland", {"WidgetKit"}, "WidgetKit"),
    (r"\bStoreKit\b|Product\.products|Transaction\.", {"StoreKit"}, "StoreKit"),
    (r"UTType|fileImporter", {"UniformTypeIdentifiers"}, "UniformTypeIdentifiers"),
    (r"PhotosPicker", {"PhotosUI"}, "PhotosUI"),
    (r"VNDetect|VNImageRequestHandler|VNHumanBodyPoseObservation", {"Vision"}, "Vision"),
    (r"AVURLAsset|AVAssetImageGenerator", {"AVFoundation"}, "AVFoundation"),
]


def main() -> int:
    problems = []
    files = sorted(ROOT.rglob("*.swift"))
    for f in files:
        source = f.read_text(encoding="utf-8")
        imports = set(re.findall(r"^import\s+(\w+)", source, re.M))
        for pattern, needed, label in RULES:
            if re.search(pattern, source) and not (imports & needed):
                problems.append(f"{f.relative_to(ROOT)}: 需要 {label}")

    print(f"检查文件数: {len(files)}")
    for p in problems:
        print(" -", p)
    if problems:
        return 1
    print("import 检查通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
