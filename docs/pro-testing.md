# Pro 内购测试

## 自动化范围

| 层级 | 文件 | 重点场景 |
| --- | --- | --- |
| Flutter 权益与配额 | `test/services/pro_service_test.dart` | 免费上限、永久权益、验证失败、到期锁定、导入导出拦截 |
| Flutter 购买流程 | `test/services/pro_purchase_test.dart` | 月/年/买断商品、重复点击、取消、待批准、异常重试、恢复失败、续订、精确到期、交易更新并发、当地价格及配置校验 |
| 购买页交互 | `test/pro_purchase_page_test.dart` | 默认年付、选择月付/买断后实际商品 ID、商品缺失与身份未验证时禁用付款、订阅转买断确认与取消 |
| 界面与功能限制 | `test/pro_page_test.dart`、`test/pro_limits_widget_test.dart`、`test/crypto/` | 三语言深浅主题、受限入口、免费状态不查询交易所、同步过程中失去权益 |
| iOS 原生判定 | `ios/RunnerTests/RunnerTests.swift` | 老用户严格分界、生产/沙盒与 Bundle ID、商品 ID/类型匹配、撤销/升级、订阅与宽限期截止时间、永久权益优先级 |
| Xcode 本地 StoreKit | `ios/RunnerTests/ProStoreKitTests.swift`、`ios/RunnerTests/Pro.storekit` | 通过原生 `ProStore` 加载真实 StoreKit 测试商品，验证购买、恢复、重复购买、退款、续订、到期与 Ask to Buy |

StoreKit 适配器先检查 `VerificationResult.verified`，再将事实交给 `ProEntitlementPolicy`。原生测试直接覆盖生产代码使用的判定规则，不构造或伪造 Apple 签名交易。Flutter 测试模拟平台通道，验证购买结果字符串本身不能解锁权益，必须在后续权益快照中确认。

## 本地运行

```bash
flutter pub get
flutter test --no-pub --concurrency=1
dart analyze lib/services/pro_service.dart lib/widgets/pro/pro_page.dart \
  test/services/pro_purchase_test.dart test/pro_purchase_page_test.dart
```

原生测试需要 macOS、完整 Xcode、CocoaPods 和已安装的 iOS 模拟器运行时。未准备本机配置时先复制 `ios/Config.example.xcconfig` 为 `ios/Config.xcconfig`，已有配置无需覆盖。

```bash
flutter build ios --simulator --debug --config-only --no-codesign
xcrun simctl list devices available
xcodebuild test \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:RunnerTests/RunnerTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

将模拟器名称替换为本机列表中的可用设备。CI 的 `iOS Pro Entitlement Tests` 作业会选择可用 iPhone 模拟器，执行不依赖商店服务的原生权益规则测试并保存 `.xcresult`。

运行 `xcodebuild` 前需要执行上面的 `flutter build ... --config-only`。仅执行 `flutter pub get` 和 `pod install` 不足以同步生成的 Swift Package 最低系统版本；开启 Swift Package Manager 的干净构建可能因此仍声明 iOS 13，与插件要求冲突。

## Xcode 本地 StoreKit 与 Apple 沙盒

`Pro.storekit` 仅加入测试 Target 的资源，不打包到正式 App。测试通过 `SKTestSession` 使用本地商品与模拟交易，无需登录 Apple 账户、不连接 App Store 交易服务器，也不产生真实扣款。配置中的美元价格只用于模拟器测试，不设置或同步 App Store Connect 的价格。

本地交易测试使用独立的 `ProStoreKit` scheme 与测试计划。可以在 Xcode 选择该 scheme 执行 Test，或运行：

```bash
xcodebuild test \
  -workspace ios/Runner.xcworkspace \
  -scheme ProStoreKit \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' \
  -only-testing:RunnerTests/ProStoreKitTests \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 60 \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

以上使用模拟器临时签名，不需要分发证书。设备名称和系统版本需替换为本机已安装的运行时。部分 iOS 26.5 运行时存在命令行无法加载 StoreKit 配置的已知问题，表现为 `SKInternalErrorDomain Code=3`；请选用兼容运行时或已修复该问题的 Xcode/运行时组合，参见 [Apple 开发者论坛](https://developer.apple.com/forums/thread/826971)。测试商品加载失败会直接报告失败，不能把它当作交易用例通过。

这层测试使用生产原生适配器与 StoreKit 的本地交易环境，比 Flutter 平台通道模拟更接近实际运行，但仍不能验证商店商品是否可售、真实 Apple 账户恢复或生产老用户凭据。Apple 真实沙盒需要先在 App Store Connect 创建商品和沙盒测试账户，再按下节验收。

## App Store 沙盒验收

自动化覆盖的是代码规则与交互，不代表真实 App Store 购买已经通过。发布前必须使用实际商品及沙盒账户完成以下检查，并记录设备系统、构建号、商品 ID、预期与实际权益：

1. 三种商品均能加载当地价格；购买页周期、付款说明、恢复购买、隐私政策和 EULA 可用。
2. 月付、年付及买断成功后立即解锁；取消和待批准期间不解锁。待批准在应用外完成后能收到更新。
3. 连续点击只发起一次付款；恢复过程中不能再次付款。网络失败后可重试，不重复收费。
4. 同一 Apple 账户重装、换机后恢复正确权益；生产环境旧账户在固定分界时间之前获得 App 时授予永久 Pro，不显示再次购买入口。
5. 沙盒模拟首次获取日期不能触发老用户赠送；首次获取验证失败时禁止购买。
6. 验证订阅续订、取消续订但尚未到期、到期、退款撤销、账单重试和宽限期。取消续订不应立即失去已付期间权益；到期或撤销后恢复免费限制。
7. 订阅用户切换买断前显示原订阅不会自动取消的提示，取消确认不付款；完成买断后永久解锁，并能管理原订阅。
8. 免费上限和 Pro 功能在应用重启、恢复前台及交易更新后保持一致；失去权益不删除现有资产，也不继续读取交易所账户。

不能用沙盒的模拟首次获取时间替代生产老用户资格验证，也不能用本地备份解锁权益。发行地区和隐私政策发布状态按 [发布指南](../scripts/README.md#pro-发布配置) 单独确认。
