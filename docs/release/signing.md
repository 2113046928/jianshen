# 签名与打包

仓库里的 `Sign IPA` workflow 会做：装证书 → 装描述文件 → `xcodebuild archive` → `exportArchive` → 产出 `.ipa`。

它需要 **5 个仓库 Secrets**。缺任何一个，第一步就会报「缺少签名密钥」并列出缺哪几个，不会跑到一半才失败。

## 需要的 Secrets

| 名称 | 内容 | 从哪来 |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | 导出为 .p12 的签名证书，转 base64 | 钥匙串访问（Mac） |
| `P12_PASSWORD` | 导出 .p12 时设的密码 | 你自己设 |
| `PROVISIONING_PROFILE_BASE64` | .mobileprovision 文件转 base64 | developer.apple.com |
| `PROFILE_SPECIFIER` | 描述文件的 **Name**（不是文件名），如 `TrainLedger Development` | 同上 |
| `TEAM_ID` | 10 位团队 ID，如 `A1B2C3D4E5` | 同上 |

## 一、拿 Team ID

1. 打开 https://developer.apple.com/account
2. 左侧 **Membership details**
3. 复制 **Team ID**（10 位字母数字）

## 二、建 App ID（第一次做需要）

1. **Certificates, Identifiers & Profiles → Identifiers → +**
2. 选 **App IDs → App**
3. Bundle ID 填 **`com.trainledger.app`**（必须完全一致）
4. 如果要保留 HealthKit / App Group（workflow 里勾 `keep_entitlements`），在这里勾上：
   - **HealthKit**
   - **App Groups** → 创建并使用 `group.com.trainledger.shared`
5. 保存

## 三、导出证书（.p12）

在 **Mac** 上：

1. 打开 Xcode → Settings → Accounts，登录你的 Apple ID
2. 选中团队 → **Manage Certificates…** → 左下 **+**
   - 打 App Store 包选 **Apple Distribution**
   - 装到自己设备调试选 **Apple Development**
3. 打开 **钥匙串访问**，左侧「我的证书」，找到刚生成的证书
4. 右键 → **导出…** → 格式选 **个人信息交换 (.p12)** → 设一个密码（就是 `P12_PASSWORD`）
5. 转成 base64（终端）：

```bash
base64 -i Certificates.p12 -o cert.txt
```

`cert.txt` 的全部内容就是 `BUILD_CERTIFICATE_BASE64`。

> Windows 上没法导出 .p12，这一步必须用 Mac。

## 四、生成描述文件（.mobileprovision）

1. **Profiles → +**
2. 选类型：
   - 装到自己/测试设备：**iOS App Development**
   - 发给测试人员（不经过 App Store）：**Ad Hoc**
   - 上架 / TestFlight：**App Store**
3. 选 App ID `com.trainledger.app`
4. 选刚才那张证书
5. Development / Ad Hoc 需要勾选设备（先把设备 UDID 加进 Devices）
6. 生成后 **Download**，文件名类似 `TrainLedger_Dev.mobileprovision`
7. 转 base64：

```bash
base64 -i TrainLedger_Dev.mobileprovision -o profile.txt
```

`profile.txt` 的内容是 `PROVISIONING_PROFILE_BASE64`。

**`PROFILE_SPECIFIER` 填的是描述文件在列表里显示的 Name**（比如 `TrainLedger Development`），不是文件名。

## 五、写进仓库

1. 打开 `https://github.com/2113046928/jianshen/settings/secrets/actions`
2. **New repository secret**，逐个添加 5 个
3. 粘贴 base64 时注意不要带换行以外多余空格

## 六、跑

Actions → 左侧 **Sign IPA** → **Run workflow**：

| 输入 | 说明 |
|---|---|
| `export_method` | `development`（装登记设备）/ `ad-hoc`（分发测试）/ `app-store-connect`（上架） |
| `keep_entitlements` | 只有描述文件已开通 HealthKit 与 App Group 时才勾 |

跑完在 Artifacts 里下载 `TrainLedger-signed-ipa`。

## 关于 watch / widget

签名 job 目前**只打主 App**（生成工程时裁掉 watch 与 widget），因为一个描述文件只能覆盖一个 bundle id。

要一起打包，需要再准备：

- `com.trainledger.app.widgets` 的描述文件
- `com.trainledger.app.watchkitapp` 的描述文件

并在 workflow 的 `provisioningProfiles` 里补上这两项。校验通过前不建议开——多一个 profile 就多一个失败点。

## 常见失败

| 报错 | 原因 |
|---|---|
| `No profiles for 'com.trainledger.app' were found` | `PROFILE_SPECIFIER` 写成了文件名，或描述文件没装进 runner |
| `Provisioning profile doesn't include the HealthKit entitlement` | 勾了 `keep_entitlements` 但 App ID / profile 没开 HealthKit |
| `does not include signing certificate` | 证书和描述文件里的证书不是同一张（重新生成 profile 时选错） |
| `No signing certificate "iOS Distribution" found` | 导出的 .p12 里没有私钥（导出时选了「证书」而不是「我的证书」条目） |
| `The device is not registered`（development） | 设备 UDID 没加进 Devices，需要重新生成 profile |

## 没有付费开发者账号

免费 Apple ID 也能签，但只有 **7 天有效期**、不能上架、不能 Ad Hoc 分发，且描述文件最多 3 个 App。这种情况下建议先用 `development` 方式在本人设备上跑通。
