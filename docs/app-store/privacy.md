# App Privacy 问卷对照

App Store Connect 的隐私问卷必须和代码行为一致。练账的结论是：**不收集任何数据**。

## 1. 跟踪（Tracking）

| 问题 | 答案 |
| --- | --- |
| 是否使用数据追踪用户？ | 否 |
| 是否包含追踪域名？ | 否 |

依据：没有任何广告 SDK、没有 IDFA、没有跨 App 归因。

## 2. 数据收集

| 分类 | 是否收集 | 说明 |
| --- | --- | --- |
| 联系信息 | 否 | 无账号、无手机号、无邮箱 |
| 健康与健身 | **否**（仅设备本地） | 训练记录存在 SwiftData；HealthKit 只读，不写回、不上传 |
| 财务信息 | 否 | 支付由 App Store 处理，App 不接触 |
| 位置 | 否 | 不申请定位权限 |
| 敏感信息 | 否 | — |
| 联系人 | 否 | — |
| 用户内容 | 否 | 无 UGC、无上传 |
| 浏览历史 | 否 | — |
| 标识符 | 否 | 不使用 IDFA、IDFV |
| 使用数据 | 否 | 无埋点 SDK |
| 诊断 | 否 | 未接入第三方崩溃 SDK；如后续接入 MetricKit 上报，需改为「诊断数据 · 不关联身份」 |
| 其他 | 否 | — |

> 关键判断：数据「只在设备上处理、不离开设备」时，不算收集。备份文件由用户自己通过系统分享导出，App 不代为上传。

## 3. 权限与用途文案

| 权限 | 用途文案 | 位置 |
| --- | --- | --- |
| HealthKit 读取 | 读取体重与活动能量，用于计算减脂期的力量保持率与容量趋势；数据只保存在本机。 | `project.yml` → `INFOPLIST_KEY_NSHealthShareUsageDescription` |
| HealthKit 写入 | 在获得授权后把训练记录写入「健康」，方便在系统里统一查看。 | `INFOPLIST_KEY_NSHealthUpdateUsageDescription` |
| 通知 | 当前版本未申请；如后续加组间休息本地通知，需补 `NSUserNotificationUsageDescription` 说明 | 待办 |

## 4. 隐私清单（PrivacyInfo.xcprivacy）

| 项目 | 值 |
| --- | --- |
| NSPrivacyTracking | false |
| NSPrivacyCollectedDataTypes | 空数组 |
| NSPrivacyAccessedAPITypes | UserDefaults · CA92.1（仅访问 App 自身偏好设置） |

如果后续引入：文件时间戳（C617.1）、磁盘空间（E174.1）、活跃键盘（C617.1）等，需要同步更新清单。

## 5. 需要一并更新的文档

- `docs/app-store/listing.md` 里的隐私政策 URL
- App 内「我的 → 隐私说明」页面（`PrivacyView`）
- 如果新增任何联网行为（例如崩溃上报、远程配置），必须先改本文件再改代码
