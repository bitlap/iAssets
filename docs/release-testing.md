# 发布测试索引

配合 [发布前检查清单](../RELEASE_CHECKLIST.md) 使用。表中列出检查场景和现有测试入口，不代表这些场景已经全部覆盖或通过。

## 如何使用

1. 从本次变更列出受影响的功能，逐项填写发布记录中的测试结果；共享计算、存储、主题和本地化变更须覆盖所有调用方。
2. 每项功能检查正常、边界和失败路径。修复缺陷时补充能复现问题的回归测试，避免只测试实现细节。
3. 记录具体用例、设备/系统/语言、提交、结果及证据；区分自动化、模拟平台、真机和线上验证。
4. 首次安装与旧版升级、空数据与历史数据、断网与恢复、前后台切换及权限拒绝均须按影响范围覆盖。
5. 内测待验证项列入 What to Test；正式发布前完成关键真机、升级、隐私和购买链路验证，不以单元测试替代。

## 功能与测试入口

以下代码路径相对于仓库根目录。

| 功能 | 检查场景 | 测试入口示例 |
| --- | --- | --- |
| 股票搜索与行情 | 各市场搜索、报价币种/单位、延迟/缺失、数据源隔离、失败重试 | `test/global_stock_widgets_test.dart`、`test/services/global_stock_search_test.dart`、`test/services/lse_currency_quote_test.dart`、`test/services/quote_source_isolation_test.dart` |
| 交易与收益 | 买卖、部分卖出、平仓、费用、股息税率、历史记录和收益曲线 | `test/utils/stock_calculator_test.dart`、`test/services/stock_data_manager_test.dart`、`test/stock_close_widget_test.dart`、`test/profit_chart_test.dart` |
| 资产分类与记录 | 内置/地区/自定义分类、增删改、排序、移动和金额汇总 | `test/asset_categories_test.dart`、`test/asset_category_sheet_test.dart`、`test/utils/asset_calculator_test.dart`、`test/utils/asset_reorder_test.dart`、`test/asset_reorder_widget_test.dart`、`test/asset_move_test.dart`（同模板拖动/修改分类、选择取消、iPad 列表宽度、样式切换、错误提示与空菜单） |
| 定期自动转存 | 默认关闭与序列化、到期/闰月、跨多期补算、并发读取幂等、金额溢出/保存失败恢复、删除失败后重试、开关持久化、33 语言窄屏/大字体布局、到期日期标记 | `test/time_deposit_auto_renew_test.dart`；另做真机跨日、重启、iCloud 多设备和银行金额核对 |
| 定期本息转存 | 33 语言预填、实际银行金额/新利率、到期限制、取消、免费超额记录更新、保存失败重试、单笔落盘与金额汇总 | `test/time_deposit_rollover_test.dart`；另做真机到期转存验收 |
| 数字币 | 普通/带单账户、只读权限、现货/合约、估值不完整、断网和缓存保留 | `test/crypto/exchange_client_test.dart`、`test/crypto/crypto_store_test.dart`、`test/crypto/crypto_widgets_test.dart` |
| 汇率与数字输入 | 币种换算、旧单位兼容、本地小数/数字、非法输入和回填后保存 | `test/utils/currency_profit_test.dart`、`test/native_currency_widgets_test.dart`、`test/localized_number_input_test.dart`、`test/localized_financial_forms_test.dart` |
| 存储、同步与备份 | 旧数据读取、往返序列化、导入导出、冲突、损坏备份、恢复失败 | `test/services/serde_test.dart`、`test/services/backup_service_test.dart`；另做 iCloud 多设备实测 |
| Pro 与购买 | 免费额度、老用户、订阅/买断、取消/待批准、恢复、到期/退款、跨设备 | `test/services/pro_service_test.dart`、`test/services/pro_purchase_test.dart`、`test/pro_limits_widget_test.dart`、`ios/RunnerTests/`；另做 StoreKit/沙盒及生产凭据验证 |
| 隐私与应用锁 | 隐藏金额、Face ID/Touch ID、后台预览、共享快照脱敏和恢复 | `test/privacy_widget_test.dart`、`test/widget_snapshot_service_test.dart`、`ios/RunnerTests/RunnerTests.swift`；另做真机验证 |
| 桌面与锁屏组件 | 四种尺寸、语言、日期/金额、空数据、过期/不完整、隐藏金额、点击跳转 | `test/widget_snapshot_service_test.dart`、`scripts/test_native_l10n.py`；另做 WidgetKit 实测 |
| 多语言与旧记录 | 全量键/参数、语言切换、系统语言、金融术语和旧记录标题 | `test/l10n_catalog_test.dart`、`test/l10n_locale_test.dart`、`test/trade_action_localization_test.dart` |
| 布局与交互 | iPhone 窄屏、iPad 横竖屏/分屏、键盘、深浅主题、长文案和 RTL | `test/bottom_sheet_layout_test.dart`、`test/settings_l10n_layout_test.dart`、`test/asset_card_layout_test.dart`；另做设备实测 |
| 设置与外部入口 | 设置持久化、主题/排序、反馈、GitHub 链接和帮助内容 | `test/services/settings_service_test.dart`、`test/services/settings_locale_test.dart`、`test/help_dialog_style_test.dart`；另做链接和操作实测 |

## 设备与语言矩阵

| 维度 | 覆盖要求 |
| --- | --- |
| 设备 | iPhone 窄屏、iPad 横竖屏与分屏；覆盖最低支持 iOS 和当前目标系统。 |
| 布局 | 深浅主题、键盘弹出、大字体、VoiceOver、长文案；弹窗打开后旋转和调整窗口。 |
| 语言 | 以 `lib/l10n/l10n.dart` 为准逐语言检查 App、原生资源、changelog 及平台文案；记录平台语言映射、缺失翻译及回退，并验证手动/系统语言、重启持久化、繁简中文、葡萄牙语地区、RTL。 |
| 数字 | 本地数字、小数分隔符、金额回填/保存、费用/税率、币种单位、非法值及有歧义的分组粘贴。 |
| 组件 | 小号/中号桌面、行内/矩形锁屏；空数据、过期、不完整、隐藏金额、语言切换和点击跳转。 |
| 真实链路 | TestFlight 安装、iCloud 多设备、行情/交易所只读连接、StoreKit 沙盒及生产老用户凭据分别记录。 |

修改功能或测试文件后同步维护此索引。详细行为见 [组件](widgets.md)、[数字币同步](crypto-sync.md)、[资产分类](asset-categories.md)、[Pro](pro.md) 和 [购买测试](pro-testing.md)。
