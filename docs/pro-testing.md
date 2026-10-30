# Pro 内购测试

## 自动化范围

| 层级 | 文件 | 重点场景 |
| --- | --- | --- |
| Flutter 权益与配额 | `test/services/pro_service_test.dart` | 免费上限、永久权益、验证失败、到期锁定、导入导出拦截 |
| Flutter 购买流程 | `test/services/pro_purchase_test.dart` | 月/年/买断商品、重复点击、取消、待批准、异常重试、恢复失败、续订、精确到期、交易更新并发、当地价格及配置校验 |
| 购买页交互 | `test/pro_purchase_page_test.dart` | 默认年付、选择月付/买断后实际商品 ID、商品缺失与身份未验证时禁用付款、订阅转买断确认与取消 |
| 界面与功能限制 | `test/pro_page_test.dart`、`test/pro_limits_widget_test.dart`、`test/crypto/` | 三语言深浅主题、受限入口、免费状态不查询交易所、同步过程中失去权益 |
| iOS 原生判定 | `ios/RunnerTests/RunnerTests.swift` | 老用户严格分界、生产/沙盒与 Bundle ID、商品 ID/类型匹配、撤销/升级、订阅与宽限期截止时间、永久权益优先级 |

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
  -only-testing:RunnerTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

将模拟器名称替换为本机列表中的可用设备。CI 的 `iOS Pro Entitlement Tests` 作业会选择可用 iPhone 模拟器，执行原生测试并保存 `.xcresult`。

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
