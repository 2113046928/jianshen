# 练账 TrainLedger

一个**纯本地、不联网也能用**的 iOS 力量训练记录与决策 App。记录免费，收钱的是「算得清」那部分：下一次该练多重、肌群容量够不够、减脂掉的是脂肪还是肌肉。

> 产品判断见 `../健身App产品分析_全景版.md`。

## 功能现状

**上手**
- 首次建档 5 问（目标 / 每周次数 / 器械 / 经验 / 体重），直接给出阶段、训练模板与每周目标
- 器械选「家里有哑铃」会自动切到居家模板，不会给你排杠铃动作

**记录与决策**
- 46 个动作的内置动作库（中文别名、器械、主动肌/协同肌、最小递增、次数区间）
- 4 套模板：推拉腿 / 上下肢 / 全身 / 居家哑铃，按已完成训练次数自动轮转
- 逐组记重量/次数/RPE，组间休息计时，复合动作自动生成热身组
- 配重引擎：双进阶（次数到上限才加重、连续两次失手才减重、RPE 过低跳级、热身不参与判断）
- **换动作**：器械被占或做不了时，按「动作模式 + 器械 + 主动肌」打分给替代，选中后重算目标次数与建议重量
- **容量自适应**：近 7 天某肌群差 2 组以上，下周相关动作自动 +1 组；超上限 3 组以上自动 −1 组（每次最多 ±1，避免来回抖）
- 容量分析、周报、Epley 1RM 与力量等级

**饮食（每日推荐）**
- Mifflin-St Jeor 算基础代谢，乘日常活动系数得到维持热量
- 按阶段给目标：增肌 +10%、减脂 −18%（缺口不超过 20% 且绝不低于 BMR）、维持不变
- 三大营养素按体重分配：蛋白 1.8（增肌）/ 2.2（减脂）g/kg，脂肪 0.9 g/kg，其余给碳水
- 分四餐并给每餐热量与蛋白目标；内置 18 条常见食物的分量参照（不是食物数据库）
- 每周按体重趋势给调整建议：不动就减 150 千卡，掉太快就加 150

**周期化**
- 4 周渐进 + 1 周减载，按已完成训练次数自动判断
- 组数波峰 3 → 3 → 4（峰值）→ 3 → 2（减载），由 `Periodization.sets(forBlockWeek:)` 决定
- 减载周组数降到 2 组、不加重，今日页显示「减载周」标记

**iOS 差异化**
- **Live Activity / 灵动岛**：锁屏看当前动作、第几组、重量次数与休息倒计时
- **桌面小组件**：小号/中号显示「今天练什么」与本周完成进度，点开直达训练
- **HealthKit（只读）**：从「健康」同步体重到阶段仪表盘
- **Apple Watch**：手表上看当前动作并可「完成本组」

**减脂期**
- 力量保持率：阶段内最佳 1RM ÷ 阶段前最佳 1RM，分卧推/深蹲/硬拉/推举，配合体重判断掉的是脂肪还是肌肉

**数据安全**
- 完整 JSON 备份（导出 / 导入 / 全量恢复，版本号 + ISO8601 日期）
- 每次训练结束自动备份，保留最近 3 份
- CSV 导出、清空记录、隐私说明

**商业**
- 买断 Pro（StoreKit 2 本地验签）
- 3 个计划包（5×5 力量入门 / 4 周减脂保肌 / 居家 20 分钟），非消耗型商品，解锁即设为当前计划

**动作评估**
- 选一段侧向深蹲视频，端上抽帧跑 Vision 人体关键点，给出次数、最低膝角、节奏与两条改进建议
- 视频不保存、不上传；只评估深度/前倾/节奏三件事，不做动作对错判定

**外观与无障碍**
- 浅色/深色双配色，颜色全部是动态色（`UIColor` dynamic provider），没有硬编码白底黑字
- 字号走语义样式，跟随 Dynamic Type 缩放
- 关键控件有 VoiceOver 标签：组完成按钮、容量条、设置入口

**工程**
- 4 个 target（App / Live Activity 扩展 / watchOS / 测试）
- 隐私清单、1024 图标、归档脚本、GitHub Actions
- 资产与工程校验脚本（见下）

## 运行

需要 macOS + Xcode 15 以上（SwiftData 要求 iOS 17）。

```bash
brew install xcodegen
cd TrainLedger
xcodegen generate
open TrainLedger.xcodeproj
```

### 签名与商品配置

- `project.yml` 里 `PRODUCT_BUNDLE_IDENTIFIER` 默认 `com.trainledger.*`，改成你自己的前缀。
- 归档前 `export TEAM_ID=你的TeamID`。
- HealthKit 需在开发者后台为 App ID 打开 capability。
- App Group `group.com.trainledger.shared`：App 与小组件共享「今天练什么」快照，需在两个 App ID 上都勾选。
- App Store Connect 需要建 4 个商品：
  - `com.trainledger.app.pro.lifetime`（非消耗型，买断）
  - `com.trainledger.pack.strength5x5` / `com.trainledger.pack.cutkeep` / `com.trainledger.pack.home20`（非消耗型，计划包）
  没配置也能跑，界面会显示「商品尚未配置」；DEBUG 构建里有「本地解锁」按钮，方便内测。

### 命令

```bash
python3 scripts/gen_project.py            # 生成工程（默认含 Watch）
WITH_WATCH=0 python3 scripts/gen_project.py  # 剔除 Watch target（构建兜底）
./scripts/test.sh                         # 模拟器跑单元测试
./scripts/archive.sh                      # 归档并导出 App Store 包（需 TEAM_ID）
./scripts/screenshots.sh                  # 用演示数据拍 App Store 原始截图
python scripts/make_store_frames.py       # 合成带标题的成品图
python scripts/make_icon.py               # 重新生成 1024 图标
python3 scripts/extract_strings.py        # 抽取文案生成中文骨架
python3 scripts/extract_strings.py --check # 检查中英 key 是否对齐
```

## 目录结构

```
Sources/
  App/          入口、Tab 容器、预览用内存库、entitlements
  Models/       SwiftData 模型、枚举、模板、计划包、建档规则、内置数据导入
  Core/         纯逻辑：配重、容量、1RM、周报、保持率、备份、CSV、内购、健康、手表、实时活动
  Design/       主题色与基础组件
  Features/     引导、今天、训练中、记录、周报、阶段、计划包、我的、买断
  Resources/    Exercises.json、ProgramPacks.json、Assets、PrivacyInfo
Shared/
  Activity/     Live Activity 属性（App + 小组件）
  Watch/        手表同步状态（App + 手表）
Targets/
  Widgets/      Live Activity / 灵动岛
  Watch/        watchOS App
Tests/          配重、容量、周报、保持率、建档、备份
```

## 校验（没有编译器时也能跑）

```bash
./scripts/verify.sh               # 一键跑完下面四项 + 中英文案对齐
python3 spec/test_engine.py        # 配重规则 10 个边界用例（与 Swift 共用期望值）
python3 spec/validate_assets.py    # 动作库、模板、计划包的引用完整性
python3 spec/validate_project.py   # 工程结构、target 隔离、plist/JSON、括号配平
python spec/check_imports.py      # 逐文件检查框架 import
```

`spec/engine.py` 是规则说明书也是可运行代码；`fixtures.json` 由它生成，Swift 的 `LoadPrescriptionTests` 用的是同一批数字。**改规则必须两边一起改，否则测试会挂——这是故意的。**

## 多语言

- 简体中文为开发语言，英文在 `Sources/Resources/en.lproj/Localizable.strings`
- 文案用中文原文作 key；需要拼数字的句子统一走 `L10n` 的 `String(format:)`，避免 SwiftUI 隐式生成的 `%lld` key 不可控
- 新增文案后跑 `python3 scripts/extract_strings.py` 生成中文骨架，再跑 `--check` 检查中英 key 是否对齐
- 覆盖 123 条文案，中英完全对齐；原先 27 条插值句已改成 `L10n` 里的显式格式串（`Shared/L10n/L10n.swift`）
- 如果 `xcodegen` 没把 `*.lproj` 识别成本地化变体组，在 Xcode 里选中 `Localizable.strings`，右侧 File Inspector 勾上 English 即可

## 设计稿

`docs/design/preview-v3.html` 是当前设计（v3：深色数据卡 + 一周柱条），`preview-v2.html` / `preview.html` 是历史版本。两者都用 HTML/CSS 1:1 复刻 SwiftUI 的布局与配色（同一套 token、间距、字号），并用 Chrome 无头模式渲染成 393×852@3x 的图（`docs/design/*.png`）。

用途是**在没有 Mac 的情况下评审界面**，不是运行中的应用；真实渲染以 SwiftUI 为准。改了 Theme 或布局后，重跑：

```bash
chrome --headless=new --force-device-scale-factor=3 --window-size=393,852 \
  --screenshot=docs/design/today.png "file://<path>/preview.html#today"
```

## 上架材料

- `docs/app-store/listing.md`：名称、副标题、关键词、描述、促销文本、审核备注、提审检查清单
- `docs/app-store/privacy.md`：App Privacy 问卷对照（结论：不收集数据）、权限文案、隐私清单项
- `docs/qa/device-checklist.md`：真机走查清单（深色模式逐屏、Dynamic Type、Live Activity 生命周期、Watch 断连、备份恢复、内购沙盒、升级迁移）
- `docs/app-store/final/`：5 张 6.7" 截图模板（当前是**排版占位图**，需在 Mac 上跑 `screenshots.sh` 换成真实截图）

截图流水线：`screenshots.sh` 用 `-demoData` 写入 4 周演示数据、`-screen` 指定界面并自动截图，再交给 `make_store_frames.py` 排版。

## 为什么不做食物数据库

市面上的饮食 App 动辄十万条食物数据，维护成本高、包体大，而且要联网更新。练账走的是另一条路：**给目标和结构，不给条目**——每天多少千卡、多少蛋白、怎么分到四餐、44g 蛋白相当于多少鸡胸肉。

这和训练侧是同一套哲学：**算得清比记得全重要**。真正让人失败的不是「不知道米饭多少千卡」，而是「不知道今天该吃多少」。

## 发布与 CI

### 没有 Mac 时拿到 ipa

推送到 GitHub 后，`.github/workflows/build-ipa.yml` 会在 macOS runner 上归档并打一个**未签名 ipa**，在 Actions 的 Artifacts 里下载。

未签名包不能直接装到真机，它的用途是：验证工程能完整编译归档、给测试同学做冒烟检查前的结构核对、以及作为后续签名流程的输入。

```bash
# 本地推送（需要 gh 已登录 / GITHUB_TOKEN / SSH key 三选一）
./scripts/push_github.sh <你的GitHub用户名> trainledger
```

### 打成能装真机的包

需要 macOS + Apple 开发者账号：

1. `xcodegen generate` 生成工程
2. Xcode 里给主 target 选好 Team，打开 HealthKit 与 App Group 能力
3. `export TEAM_ID=你的TeamID && ./scripts/archive.sh`
4. 产物在 `build/export/TrainLedger.ipa`

TestFlight 上传前确认：4 个内购商品已建、隐私政策 URL 可访问、App Privacy 问卷按 `docs/app-store/privacy.md` 填。

## 数据与隐私

- 不设账号，数据只在本机 SwiftData 数据库，不上传。
- HealthKit 只读体重/体脂，不写回；未授权不影响记录。
- 备份文件由用户自己保管（Files / 微信 / 网盘），App 不做任何同步。
- 隐私清单声明：不追踪、不收集数据、仅使用 UserDefaults（CA92.1）。

## 已知限制

- **Watch target 最可能需要现场调整**：`WKCompanionAppBundleIdentifier`、Embed Watch Content 与签名团队要和账号对齐；卡住构建就先注释 `project.yml` 里的 `TrainLedgerWatch` 依赖，App 与 Live Activity 不受影响。
- Live Activity 需要 iOS 16.1+，`NSSupportsLiveActivities` 已配置。
- 桌面小组件依赖 App Group；没配好时小组件会显示「打开 App 开始训练」的兜底态。
- 深色模式是代码内动态色，未做逐屏对比度实测；上线前建议在真机两种外观下各走一遍。
- 计划包商品未配置时只能通过 DEBUG 按钮解锁，正式版需要 ASC 商品审核通过。
- 动作评估依赖视频质量与侧面角度，正面或遮挡会识别失败；不做医疗或康复判断。
- 备份恢复是「全量覆盖」：会先删掉现有训练与体重记录，恢复前请先导出当前数据。
- 训练与营养建议都不构成医疗或康复建议；有代谢疾病、孕期或进食障碍史请遵医嘱。
- 本地化仍有缺口：枚举标题（性别/活动量/餐次等）和少数数字拼接句仍是中文，需要在 `Enums.swift` 里改成 `String(localized:)` 才能翻译。
