# iAssets 发布前检查清单

每次上传 TestFlight、提交 App Store 审核或发布 GitHub Release 时执行。按发布阶段检查，逐项留下证据；本清单本身不代表检查已通过，也不会自动发布。

## 执行与问题处理

- [ ] 先阅读本清单和 [iOS 发布指南](scripts/README.md)，确认此次发布范围。
- [ ] 为本次发布新建一份检查记录，使用本文末尾的模板；不要沿用上次已勾选的结果。
- [ ] 每项记录“通过 / 失败 / 未验证 / 不适用”、证据和检查时间。不适用须说明原因；无法访问后台或没有真机时标记未验证。
- [ ] 发现问题，先向用户说明现象、影响、证据及修复方案，再在已授权范围内修复并复查；记录修复提交和复查结果。
- [ ] 修复后重跑受影响的检查。提交、代码、依赖、配置或文案改变后，重新检查对应阶段，不能沿用失效的结果。
- [ ] 影响金额、数据完整性、隐私、购买权益、启动、构建或发布内容真实性的问题未解决时，停止上传、送审或发布。
- [ ] 没有执行的测试、尚未处理完成的构建、未核验的线上状态不能写成通过；构建成功、测试通过、上传成功、可测试、审核通过、正式可下载分别记录。
- [ ] 最后向用户报告完成项、发现及修复的问题、仍未验证的项目、版本/构建号/提交和发布链接。

## 1. 发布范围、版本与源码

- [ ] 记录目标：内部测试 / 外部测试 / 正式版 / 仅补历史 GitHub Release，明确是否包括提交、推送、上传、送审和正式发布。
- [ ] 检查 `git status --short`、提交差异和远端分支；确认所有拟发布修改均已纳入指定提交，没有遗漏的本地修复或无关文件。
- [ ] 核对 `pubspec.yaml`、构建时的 `BUILD_NAME` / `BUILD_NUMBER`、主 App、Widget 扩展及 App Store Connect 的实际版本与构建号。
- [ ] 确保上传构建号可用；Xcode 可能调整上传构建号，以 App Store Connect 实际结果为准。
- [ ] 记录构建使用的完整 Git SHA、Flutter/Xcode 版本、非敏感配置、归档和日志位置。发布构建来自可追溯的提交。
- [ ] 核对本版相对上一个正式版本的全部变更，包含直接提交、合并 PR 和修复；不能仅依赖自动生成的 Release 草稿。
- [ ] 检查依赖和锁文件变更、插件兼容性、最低 iOS 版本及 App/扩展部署目标；不为发布临时执行无关依赖升级。

## 2. 代码、注释与隐私

- [ ] 检查空值、异常、重复操作、异步竞态、取消、销毁和前后台切换，保证失败提示明确且能够重试。
- [ ] 核对股票、股息、手续费、汇率、资产和数字币估值；检查零值、负值、大金额、部分卖出、币种及单位转换，防止格式化改变实际金额。
- [ ] 数据读取失败、行情缺失和权益未验证时，不得以零值覆盖已有数据或缓存估值。
- [ ] 核对本地持久化、旧版数据兼容、导入导出、备份回滚、iCloud 合并及换机恢复；异常不能破坏已有数据。
- [ ] 注释准确描述当前行为、边界和原因；删除失效说明、临时调试代码及无效开关，审查 TODO/FIXME 是否影响本次发布。
- [ ] 日志、异常提示、测试夹具、提交与构建产物中不含 API 私钥、交易所凭据、真实账户或资产信息。
- [ ] 核对权限说明、隐私政策与实际采集/同步行为；主 App 与 Widget 的 App Groups、隐藏金额和生物识别锁保持一致。
- [ ] 核对开源许可证、依赖许可和 GitHub 反馈链接；敏感本机配置仍被 Git 忽略。

## 3. 格式化、静态检查与构建

在项目根目录执行，保留完整日志和退出状态。不能用过滤错误、`|| true` 或仅查看 CI 绿灯代替检查。

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
python3 scripts/test_native_l10n.py
bash -n scripts/release_ios.sh
git diff --check
flutter build ios --simulator --debug --no-codesign --no-pub
```

- [ ] 格式化检查通过。需要修改时执行 `dart format .`，审查差异后重新检查。
- [ ] 静态分析结果逐项处理；既有告警也必须记录，不能默认为通过。
- [ ] Flutter 完整测试通过；失败不能通过删测试、放宽断言或跳过用例掩盖。
- [ ] 原生小组件多语言检查通过，且原生 XCTest 通过；执行方式见 [Flutter CI](.github/workflows/flutter-ci.yml) 的 `ios-pro-tests` 作业。
- [ ] iOS 模拟器编译通过；使用发布配置完成真机 Release 归档，检查 App 和 Widget 的签名、权限及版本。
- [ ] 执行 `./scripts/release_ios.sh --dry-run` 核对配置。该命令不能代替真实归档，也不代表已上传。
- [ ] 查看完整构建日志，判断警告是否影响功能、签名、平台兼容性或后续发布。

## 4. 每项功能的测试覆盖

每个本次新增、修改或受共享逻辑影响的功能都要记录测试入口、场景和结果；没有覆盖的功能要明确补测。自动化测试证明业务逻辑与回归行为，真机和后台验证证明平台链路，两者分别记录。

下表是测试入口索引，不代表这些场景已经全部覆盖。测试文件随功能演进同步更新。

| 功能 | 检查场景 | 测试入口示例 |
| --- | --- | --- |
| 股票搜索与行情 | 各市场搜索、报价币种/单位、延迟/缺失、数据源隔离、失败重试 | `test/global_stock_widgets_test.dart`、`test/services/global_stock_search_test.dart`、`test/services/lse_currency_quote_test.dart`、`test/services/quote_source_isolation_test.dart` |
| 交易与收益 | 买卖、部分卖出、平仓、费用、股息税率、历史记录和收益曲线 | `test/utils/stock_calculator_test.dart`、`test/services/stock_data_manager_test.dart`、`test/stock_close_widget_test.dart`、`test/profit_chart_test.dart` |
| 资产分类与记录 | 内置/地区/自定义分类、增删改、排序、移动和金额汇总 | `test/asset_categories_test.dart`、`test/asset_category_sheet_test.dart`、`test/utils/asset_calculator_test.dart`、`test/utils/asset_reorder_test.dart` |
| 数字币 | 普通/带单账户、只读权限、现货/合约、估值不完整、断网和缓存保留 | `test/crypto/exchange_client_test.dart`、`test/crypto/crypto_store_test.dart`、`test/crypto/crypto_widgets_test.dart` |
| 汇率与数字输入 | 币种换算、旧单位兼容、本地小数/数字、非法输入和回填后保存 | `test/utils/currency_profit_test.dart`、`test/native_currency_widgets_test.dart`、`test/localized_number_input_test.dart`、`test/localized_financial_forms_test.dart` |
| 存储、同步与备份 | 旧数据读取、往返序列化、导入导出、冲突、损坏备份、恢复失败 | `test/services/serde_test.dart`、`test/services/backup_service_test.dart`；另做 iCloud 多设备实测 |
| Pro 与购买 | 免费额度、老用户、订阅/买断、取消/待批准、恢复、到期/退款、跨设备 | `test/services/pro_service_test.dart`、`test/services/pro_purchase_test.dart`、`test/pro_limits_widget_test.dart`、`ios/RunnerTests/`；另做 StoreKit/沙盒及生产凭据验证 |
| 隐私与应用锁 | 隐藏金额、Face ID/Touch ID、后台预览、共享快照脱敏和恢复 | `test/privacy_widget_test.dart`、`test/widget_snapshot_service_test.dart`、`ios/RunnerTests/RunnerTests.swift`；另做真机验证 |
| 桌面与锁屏组件 | 四种尺寸、语言、日期/金额、空数据、过期/不完整、隐藏金额、点击跳转 | `test/widget_snapshot_service_test.dart`、`scripts/test_native_l10n.py`；另做 WidgetKit 实测 |
| 多语言与旧记录 | 全量键/参数、语言切换、系统语言、金融术语和旧记录标题 | `test/l10n_catalog_test.dart`、`test/l10n_locale_test.dart`、`test/trade_action_localization_test.dart` |
| 布局与交互 | iPhone 窄屏、iPad 横竖屏/分屏、键盘、深浅主题、长文案和 RTL | `test/bottom_sheet_layout_test.dart`、`test/settings_l10n_layout_test.dart`、`test/asset_card_layout_test.dart`；另做设备实测 |
| 设置与外部入口 | 设置持久化、主题/排序、反馈、GitHub 链接和帮助内容 | `test/services/settings_service_test.dart`、`test/services/settings_locale_test.dart`、`test/help_dialog_style_test.dart`；另做链接和操作实测 |

- [ ] 为本次每个功能变更补齐正常、边界和失败路径；修复问题时增加能复现问题的有效回归测试。
- [ ] 共享计算、存储、主题或本地化改变时，检查所有调用方，不能只验证新页面。
- [ ] 覆盖首次安装、旧版升级、有历史数据和空数据；真机验证冷启动、前后台切换、断网/恢复及系统权限拒绝。
- [ ] 检查性能、刷新频率、重复请求和耗电；组件继续遵守 [组件数据更新约定](docs/widgets.md)。
- [ ] 检查大字体、VoiceOver、按钮可点击区域及颜色辨识；覆盖 iPad 弹窗打开后的旋转和分屏调整。

## 5. 多语言专项

- [ ] 以 `lib/l10n/l10n.dart` 为语言注册表，核对所有语言的键、动态参数、非空文案及回退策略；当前共 33 种语言，新增时同步调整检查脚本。
- [ ] 检查新增/修改文案和金融术语，不残留意外中文、英文占位、机器翻译标记或错误产品名；未完成人工语言校对的部分明确记录。
- [ ] 验证手动选择、跟随系统、重启后持久化，以及繁简中文、葡萄牙语地区和历史语言别名。
- [ ] 验证日期、数字、小数逗号、本地数字、金额编辑回填和保存，保证显示格式不改变底层值。
- [ ] 验证阿拉伯语、波斯语、希伯来语 RTL，及德语等长文案；检查窄屏、弹窗、表单、设置和记录标题。
- [ ] 修改语言表后执行 `python3 scripts/sync_native_l10n.py`，审查生成差异并再次运行原生语言检查。
- [ ] 核对 iOS 权限说明、Widget 语言声明、组件正文/预览/选择页说明、日期金额及隐私状态；在 App 切换语言后观察系统刷新结果。
- [ ] App 界面语言与商店元数据语言分别检查；已维护的每种 TestFlight/App Store 文案均须更新，不能把“支持 33 种界面语言”写成“已有 33 种商店文案”。

## 6. 文档与对外文案

- [ ] 更新 `changelog/<版本>.md` 的简体中文、繁体中文、英文；说明用户能感知的变化、修复及必要限制。
- [ ] 更新 README、截图和涉及的功能文档，确保免费/Pro、支持市场、语言、同步、组件行为与实现一致。
- [ ] 检查 [组件](docs/widgets.md)、[数字币同步](docs/crypto-sync.md)、[资产分类](docs/asset-categories.md)、[Pro](docs/pro.md) 及 [购买测试](docs/pro-testing.md) 中受影响的说明。
- [ ] 核对 `changelog/app_store.txt`、`app_store_hant.txt`、`app_store_en.txt` 的产品描述、功能、语言数及订阅说明；保留所需的使用条款链接。
- [ ] 核对 GitHub 仓库、问题反馈、隐私政策、支持页面及 Apple 标准 EULA 链接可访问且指向正确内容。
- [ ] TestFlight 测试说明针对具体构建；产品描述介绍实际功能；App Store 更新说明和 GitHub Release 与各自版本对应。
- [ ] 不把仅在本地、尚未纳入对应二进制的修复写成已发布；不把测试版功能提前写入旧正式版描述。

## 7. TestFlight

- [ ] 上传前确认目标提交、版本、构建号、配置及测试分组，记录内部专用或可用于外部测试/正式发布的构建类型。
- [ ] 等待 Apple 处理完成，确认实际构建号、处理结果、合规状态及测试人员可安装；上传成功不等于已经可测试。
- [ ] 为该构建填写“测试内容 / What to Test”，覆盖新增内容、测试重点、已知限制和反馈方法，核对所有已维护语言。
- [ ] 更新 Beta 产品描述、反馈邮箱、营销/隐私链接；回读后台确认内容已保存，没有沿用旧版本或空白说明。
- [ ] 若发布外部测试，确认构建可外测、Beta 审核与分组状态，不将内部可测状态等同于外部可测。
- [ ] 从 TestFlight 安装核对实际版本，执行核心流程、小组件、购买沙盒、iPad 及旧数据升级测试，记录反馈并闭环。
- [ ] 保存构建 ID、测试范围、验证结果和已知问题；Beta 描述是共享元数据，修改后检查是否影响仍在测试的旧构建。

## 8. App Store 正式发布

- [ ] 按最终代码和正式配置归档；内部 TestFlight 专用构建不能直接转为正式版，重新构建后重新验证。
- [ ] 老用户 Pro 分界时间固定为 `2026-11-09T16:00:00Z`；检查主 App/扩展签名、App Groups、隐私 URL 和 Release 配置，无测试配置混入。
- [ ] 核对产品描述、更新说明、宣传文本、截图、支持/隐私/条款链接及已维护的全部商店语言；内容与待审版本一致。
- [ ] 核对版本关联的实际构建、内购商品、审核说明、所需测试方式、隐私申报、分级、发行地区、价格及发布方式。
- [ ] StoreKit 沙盒不能证明生产环境老用户身份；按 [Pro 发布配置](scripts/README.md#pro-发布配置) 单独记录生产凭据验证。
- [ ] 送审和正式发布分别核验状态；只有达到本次授权的发布范围才执行对应操作，不因清单存在而自动送审或上架。
- [ ] 上线后检查 App Store 版本、下载/更新、线上产品描述、内购恢复和关键流程；如有异常，停止后续推广/发布并处理。

## 9. GitHub tag 与 Release

- [ ] 拉取并核对远端 tag 和已发布 Release，检查本版和历史版本是否缺失、重复或误标。
- [ ] 沿用 `v<版本>` 命名；tag 指向该版本的正确提交。补历史 tag 时核对历史源码版本，不能直接指向当前 HEAD。
- [ ] 已发布 tag 不擅自移动、覆盖或删除；发现对应错误先报告，再明确处理方式。
- [ ] tag 与 Release 分别核验：推送 tag 不代表已发布 Release，Release Drafter 草稿也不代表正式发布。
- [ ] Release 标题、版本、三语说明、比较链接及源码引用正确；发布后打开页面核对 tag 对应 SHA 和可见状态。
- [ ] 测试版使用明确的预发布版本标识并标为 Pre-release；正式版才按实际情况标为 Latest，避免让测试版替代最新正式版。
- [ ] 上传二进制附件时，确认来自对应提交、版本和签名配置，提供校验值；源码 Release 没有二进制时不暗示提供了安装包。
- [ ] GitHub 发布内容与 App Store/TestFlight 的实际发布状态一致，不宣称尚未上架的版本已正式可用。

## 10. 收尾与回退准备

- [ ] 保存归档、符号文件、构建/上传日志、检查记录和上一正式版本信息，不包含密钥和用户数据。
- [ ] 对可能改变持久化数据的更新准备备份、兼容和恢复方案，并验证恢复路径。
- [ ] 区分暂停分阶段发布、修正元数据与发布修复版本；已安装 App 无法靠移动 Git tag 或删除 Release 回退。
- [ ] 汇总尚未验证的设备/语言/购买路径及已知问题，安排具体后续验证；不能用“以后再测”将未验证项勾选通过。
- [ ] 发布完成后回读 TestFlight/App Store 和 GitHub，记录实际状态、链接及时间，向用户报告。

## 每次发布的检查记录模板

复制到新的发布记录，例如 `docs/release-checks/<版本>-<构建>-<阶段>.md`。共享记录前移除私钥路径、凭据、真实账户和资产数据。

```markdown
# 发布检查：<版本>（<实际构建号>）— <阶段>

- 检查时间：
- 发布范围：
- Git 分支与完整 SHA：
- Flutter / Xcode 版本：
- 归档及完整日志位置（不含敏感信息）：
- TestFlight 构建 ID / App Store 版本：
- GitHub tag / Release 链接：

| 检查项 | 状态（通过/失败/未验证/不适用） | 证据、原因及检查时间 |
| --- | --- | --- |
| 源码与版本 | | |
| 代码、注释与隐私 | | |
| 格式化、静态分析、自动化测试及构建 | | |
| 每项变更的测试覆盖（逐功能补行） | | |
| 多语言、iPhone / iPad / Widget | | |
| 文档与各语言对外文案 | | |
| TestFlight | | |
| App Store 正式发布 | | |
| GitHub tag / Release | | |
| 收尾与回退准备 | | |

| 问题 | 影响与证据 | 已向用户提示 | 修复提交/处理 | 复查结果与时间 |
| --- | --- | --- | --- | --- |
| | | | | |

- 本次结论（可以进入哪个阶段 / 被哪些问题阻塞）：
- 尚未验证及已知问题：
- 实际完成的外部操作与状态：
- 后续事项：
```
