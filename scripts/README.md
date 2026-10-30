# iOS Release 编译与上传

使用 App Store Connect **团队 API Key**，从 App Store Connect 获取 Key ID、Issuer ID 和 `.p8` 私钥；账号/API Key 需要具有该 App 的上传权限。私钥保存在仓库外，本机需安装 Flutter、完整 Xcode、CocoaPods，并准备签名证书或启用 Xcode 自动签名。

以下命令均在项目根目录执行。

```bash
cp scripts/release_ios.env.example scripts/release_ios.env
# 编辑 scripts/release_ios.env，填写密钥、老用户分界时间和隐私政策 URL

# 检查配置、查看命令，不编译或上传
./scripts/release_ios.sh --dry-run

# 一键编译、签名、导出 IPA 并上传 App Store Connect
./scripts/release_ios.sh
```

脚本自动读取同目录的 `release_ios.env`，无需手动 `source`。外部环境变量优先于文件配置，例如：

```bash
BUILD_NUMBER=2 ./scripts/release_ios.sh
```

版本默认读取 `pubspec.yaml`，构建号读取 `+` 后缀（缺省为 `1`），可通过 `BUILD_NAME`、`BUILD_NUMBER` 覆盖。团队默认读取 `ios/Config.xcconfig`，也可指定 `APPLE_TEAM_ID`。Xcode 在上传时管理构建号以避免重复，因此上传后的构建号可能与本地导出的 IPA 不同。

归档、IPA、导出配置及各阶段日志保存在 `build/ios/releases/` 的独立目录；可用 `RELEASE_OUTPUT_DIR` 指定一个尚不存在的目录。任何阶段失败立即停止，上传成功后仍需等待 Apple 处理，不会自动提交审核或发布。

## Pro 发布配置

免费版最多 3 只股票、3 种资产类型，每种类型最多 3 条记录；数字币、导入导出（含备份回滚）和自定义股票需要 Pro。Pro 订阅到期不会删除或截断已有数据，超额记录仍可查看、编辑和删除；已有自定义股票保留展示，相关操作需要恢复 Pro。

在 App Store Connect 为现有 App 创建以下商品，首次内购与新版本一起提交审核。代码只读取 Apple 返回的当地价格，不会创建商品或设置商店价格：

| Product ID | 类型 | 人民币参考定价 |
| --- | --- | --- |
| `org.bitlap.assets.pro.monthly` | 自动续期，一个月 | ¥10 |
| `org.bitlap.assets.pro.yearly` | 自动续期，一年 | ¥99 |
| `org.bitlap.assets.pro.lifetime` | 非消耗型，一次性买断 | ¥299 |

月付和年付放在同一个订阅组、同一等级，权益相同。商品类型、订阅周期、可选价格点和发行地区需在商店中确认。上表为定价意向，各地区实际价格以 App Store Connect 可选价格点及 Apple 返回的本地价格为准。App 只在中国大陆以外的地区上架；加入内购不会解除中国区的法律下架限制，也不能假定中国区老用户可以更新或购买。

2.0.0 的权益规则、实现入口与验证清单见 [Pro 使用与开发说明](../docs/pro.md)，对外更新说明见 [2.0.0 更新日志](../changelog/2.0.0.md)。

`PRO_LEGACY_CUTOFF` 必须是首次收费版本实际发布的 UTC 时间（以 `Z` 结尾），发布后永久固定。Apple 验证通过的 AppTransaction 中，生产环境 `originalPurchaseDate` 早于该时间的账户自动获得永久 Pro，无需购买；换机或重装后使用同一个 Apple 账户恢复验证。沙盒获取日期是模拟数据，不用于赠送老用户权益。不要用本地资产文件、设置或导入备份判断老用户身份。

`PRO_PRIVACY_URL` 默认使用现有的 `https://bitlap.org/iAssets-privacy/`，可覆盖为其他已发布的 HTTPS 隐私政策，购买页同时提供 Apple 标准 EULA、恢复购买与管理订阅。分界时间缺失或隐私政策链接无效时购买按钮不可用，发布脚本会停止。

本机调试可通过 `flutter run --dart-define=PRO_LEGACY_CUTOFF=<UTC时间> --dart-define=PRO_PRIVACY_URL=<HTTPS地址>` 传入同样配置。请勿把示例时间当成正式分界时间。

StoreKit 2 交易在设备端验证，应用启动、回到前台、收到交易更新及订阅到期时刷新权益；账单宽限期按 StoreKit 返回的状态和截止时间处理。买断不会自动取消已存在的订阅，购买前和购买后均提示用户管理原订阅。权益不写入用户可导入的备份，也不使用本地布尔值永久解锁。

最低支持 iOS 16，AppTransaction 用于验证老用户身份。首次获取信息暂时无法验证时保留已有数据并禁用购买，提示联网恢复验证，避免误向老用户收费。

发布前需真机/沙盒验证：首次购买、取消、待批准购买、恢复、跨设备恢复、订阅到期、续订、退款撤销、宽限期、订阅转买断，以及网络断开/恢复；生产环境老用户凭据需单独核验。Flutter 单元测试中的模拟权益不代表真实付款链路已验证。
