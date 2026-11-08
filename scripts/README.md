# iOS Release 编译与上传

每次发布前先执行 [发布前检查清单](../RELEASE_CHECKLIST.md)，记录检查证据、问题和修复结果；上传、送审和正式发布分别核验。

使用 App Store Connect **团队 API Key**，从 App Store Connect 获取 Key ID、Issuer ID 和 `.p8` 私钥；账号/API Key 需要具有该 App 的上传权限。私钥保存在仓库外，本机需安装 Flutter、完整 Xcode、CocoaPods，并准备签名证书或启用 Xcode 自动签名。

以下命令均在项目根目录执行。

```bash
cp scripts/release_ios.env.example scripts/release_ios.env
# 编辑 scripts/release_ios.env，填写密钥、老用户分界时间和隐私政策 URL

# 检查配置、查看命令，不编译或上传
./scripts/release_ios.sh --dry-run

# 一键编译、签名、导出 IPA 并上传 App Store Connect
./scripts/release_ios.sh

# 仅上传 TestFlight 内部测试构建，不能用于外部测试或 App Store 正式发布
./scripts/release_ios.sh --internal-testflight
```

脚本自动读取同目录的 `release_ios.env`，无需手动 `source`。外部环境变量优先于文件配置，例如：

```bash
BUILD_NUMBER=2 ./scripts/release_ios.sh
```

版本默认读取 `pubspec.yaml`，构建号读取 `+` 后缀（缺省为 `1`），可通过 `BUILD_NAME`、`BUILD_NUMBER` 覆盖。团队默认读取 `ios/Config.xcconfig`，也可指定 `APPLE_TEAM_ID`。Xcode 在上传时管理构建号以避免重复，因此上传后的构建号可能与本地导出的 IPA 不同。

归档、IPA、导出配置及各阶段日志保存在 `build/ios/releases/` 的独立目录；可用 `RELEASE_OUTPUT_DIR` 指定一个尚不存在的目录。任何阶段失败立即停止，上传成功后仍需等待 Apple 处理，不会自动提交审核或发布。

`--internal-testflight` 使用 Xcode 的内部测试专用标记。此类构建不能转为外部测试或正式上架；正式版必须以最终固定的 `PRO_LEGACY_CUTOFF` 重新构建并上传。内测时可通过环境变量临时覆盖该值，不要把测试分界时间写入正式发布配置。

包含桌面和锁屏组件的版本需要主 App 与 Widget 扩展分别使用含 App Groups 权限的 App Store 描述文件。在 `release_ios.env` 中配置 `IOS_APP_PROFILE_NAME` 和 `IOS_WIDGET_PROFILE_NAME` 两个名称；脚本在导出和上传时会显式选用它们。
TestFlight 使用 Apple 沙盒：可以测试订阅、买断及其恢复，但沙盒中的 App 首次获取日期不能证明旧版付费下载，旧用户永久 Pro 必须在正式版通过生产环境 AppTransaction 验证。

## GitHub Release 草稿

`master` 更新后，Release Drafter 工作流按 `pubspec.yaml` 的版本创建或更新草稿，再用 `scripts/github_release_notes.py` 从 `changelog/<版本>.md` 提取简体中文、繁体中文和英文作为正文，包含直接提交的改动。本地 changelog 及 App Store 产品描述仍覆盖全部项目语言。运行 `python3 scripts/check_release_notes.py` 核对语言、条目数量及产品描述文件；缺少任一语言内容或草稿版本不匹配时工作流失败，不将空说明视为成功。语言与平台文案映射见 [多语言维护说明](../docs/localization.md)。

该流程只维护草稿，不自动发布、创建正式 tag 或改变 Latest。已公开的同版本会在草稿动作前跳过；仅清理旧工作流遗留、正文完全一致且无附件的同版本机器人重复草稿。正式发布前仍需按检查清单核对正文、源码版本及实际 App Store/TestFlight 状态。

## App Store 与 TestFlight 文案

App Store 产品描述和 TestFlight Beta 产品描述使用 `changelog/app_store/<App 语言代码>.txt`。App Store 更新说明取 `changelog/<版本>.md` 的对应语言段，仍覆盖平台支持的全部语言；GitHub 的中英文显示规则不适用于商店或 TestFlight。

TestFlight 的 What to Test 在对应语言更新说明后追加测试重点与已知限制。源文件位于 `changelog/testflight/<版本>/<App 语言代码>.txt`，按实际构建号生成，例如：

```bash
python3 scripts/testflight_release_notes.py --version 2.2.0 --build 26 --language en
python3 scripts/test_testflight_release_notes.py
```

按后台实际可用的 locale 保存并回读每个字段，不能用本地翻译代表线上成功。Beta 产品描述是 App 级共享字段；测试说明绑定构建，更新旧构建前先核对其实际源码，不能把后续修复写成旧构建已有功能。2.2.0（10）、（22）、（23）及（24）的历史说明按各自源码保留；当前构建（26）同步自动转存、开关配色和卡片详情顺序的测试重点，待审商店文案单独核验。重新生成旧构建说明时必须使用其对应提交的源文件；不能使用包含后续功能的当前文案。构建 9 保留原测试说明。平台未接受的语言需记录实际错误与回退，不伪造语言支持。

## Pro 发布配置

免费版最多 3 只股票、3 种资产类型，每种类型最多 3 条记录；数字币、导入导出（含备份回滚）和自定义股票需要 Pro。Pro 订阅到期不会删除或截断已有数据，超额记录仍可查看、编辑和删除；已有自定义股票保留展示，相关操作需要恢复 Pro。

在 App Store Connect 为现有 App 创建以下商品，首次内购与新版本一起提交审核。代码只读取 Apple 返回的当地价格，不会创建商品或设置商店价格：

| Product ID | 类型 | 美国区参考价格（USD） |
| --- | --- | --- |
| `org.bitlap.assets.pro.subscription.monthly` | 自动续期，一个月 | $1.99 |
| `org.bitlap.assets.pro.subscription.yearly` | 自动续期，一年 | $19.99 |
| `org.bitlap.assets.pro.lifetime` | 非消耗型，一次性买断 | $39.99 |

月付和年付放在同一个订阅组、同一等级，权益相同。商品类型、订阅周期、可选价格点和发行地区需在商店中确认。上表为定价意向，各地区实际价格以 App Store Connect 可选价格点及 Apple 返回的本地价格为准。App 只在中国大陆以外的地区上架；加入内购不会解除中国区的法律下架限制，也不能假定中国区老用户可以更新或购买。

2.0.0 的权益规则、实现入口与验证清单见 [Pro 使用与开发说明](../docs/pro.md)，对外更新说明见 [2.0.0 更新日志](../changelog/2.0.0.md)。

2.0.0 正式版于北京时间 2026 年 11 月 5 日提前发布，App 同时改为免费。老用户永久 Pro 的固定分界时间仍为北京时间 11 月 10 日 00:00，正式构建使用 `PRO_LEGACY_CUTOFF="2026-11-09T16:00:00Z"`，以后版本不得调整。Apple 验证通过的 AppTransaction 中，生产环境 `originalPurchaseDate` 早于该时间的账户自动获得永久 Pro，无需购买；换机或重装后使用同一个 Apple 账户恢复验证。沙盒获取日期是模拟数据，不用于赠送老用户权益。不要用本地资产文件、设置或导入备份判断老用户身份。由于提前发布，分界前免费获取 App 的用户也获得永久 Pro；App Store 改价展示尚未同步时按旧价购买的用户同样获得永久 Pro。

`PRO_PRIVACY_URL` 默认使用现有的 `https://bitlap.org/iAssets-privacy/`，可覆盖为其他已发布的 HTTPS 隐私政策，购买页同时提供 Apple 标准 EULA、恢复购买与管理订阅。分界时间缺失或隐私政策链接无效时购买按钮不可用，发布脚本会停止。

自动续期订阅的 App Store 产品页也必须显示使用条款链接。提交审核前，核对 `changelog/app_store/<App 语言代码>.txt` 中对应平台支持语言的每份产品描述均包含 Apple 标准 EULA 链接：`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`。应用内购买页的链接不能替代商店描述中的链接。

本机调试可通过 `flutter run --dart-define=PRO_LEGACY_CUTOFF=<UTC时间> --dart-define=PRO_PRIVACY_URL=<HTTPS地址>` 传入同样配置。请勿把示例时间当成正式分界时间。

StoreKit 2 交易在设备端验证，应用启动、回到前台、收到交易更新及订阅到期时刷新权益；账单宽限期按 StoreKit 返回的状态和截止时间处理。买断不会自动取消已存在的订阅，购买前和购买后均提示用户管理原订阅。权益不写入用户可导入的备份，也不使用本地布尔值永久解锁。

最低支持 iOS 16，AppTransaction 用于验证老用户身份。首次获取信息暂时无法验证时保留已有数据并禁用购买，提示联网恢复验证，避免误向老用户收费。

发布前需真机/沙盒验证：首次购买、取消、待批准购买、恢复、跨设备恢复、订阅到期、续订、退款撤销、宽限期、订阅转买断，以及网络断开/恢复；生产环境老用户凭据需单独核验。Flutter 单元测试中的模拟权益不代表真实付款链路已验证。
