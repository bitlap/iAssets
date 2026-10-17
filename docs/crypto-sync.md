# 数字币只读同步（1.6.0）

## 数据与界面

底部导航为股票、数字币、资产。数字币有独立总资产卡片及总览、现货/币种余额、合约仓位三个标签。资产页顶部总资产及资产占比分布加入数字币估值。两页共用 `CryptoStore`，切换显示币种后按既有法币汇率换算。

数字币只读，不提供修改余额、持仓、下单、转账、提现或录入成本。无需同步历史成交，不计算现货成本收益。合约使用交易所返回的未实现盈亏，价格为标记价格。数量使用 Decimal，数据解析与序列化使用字符串以保留精度；币本位仓位保留“张”单位，不冒充标的币数量。

除顶部资产汇总卡片沿用紧凑金额格式外，数字币明细使用 Decimal 固定显示 8 位小数，超出部分截断，不四舍五入或缩写；法币估值按当前汇率进行 Decimal 换算。缺失的参考价格和估值显示“未估值”，不显示为零。

数字币顶部总资产卡片固定按合约、现货、带单三列显示分类金额，带单不重复计入合约或现货；卡片不显示更新时间；最近更新时间放在页面标题下，沿用股票页面的日期时间格式。连接后只展示自定义账户名称与资产明细，不再显示范围和注意事项；添加时仍完整提示这些信息及刷新方式。

数字币页移除重复的“添加交易所”按钮，使用底部加号添加账户。

## 添加连接

当前仅支持币安，填写账户用途、名称和凭证；币安带单再选择现货或合约类型。跟单账户测试会提示暂不支持，不能添加。用户阅读范围与注意事项，所有账户（含带单）优先使用只读 API。含交易权限时提示资产损失风险，查询测试成功后仍可添加；提现、转账权限仍需关闭。无法自动核验权限的 API 不能添加。测试查询真实私有账户、检查 API 权限及所需持仓接口，而非仅 ping 公共服务器。失败不能添加；更改字段会使测试失效，测试凭证最多有效 5 分钟。按交易所、地区和账户 UID 去重，避免不同 Key 重复计入同一账户。

使用固定 HTTPS 域名和 GET 白名单调用方式，不提供用户自定义服务器地址，不跟随携带凭证的重定向。错误仅暴露数值错误码/HTTP 状态，不输出原始响应、签名 URL、Secret 或 Passphrase。用户如需更换凭证，可移除连接后重新测试添加。

法币换算沿用 `ExchangeRateService`（open.er-api.com）；币种兑美元估值使用行情参考数据，当前实现另有 Coinbase 公开报价查询。这两个来源用途不同，添加页不再将法币汇率描述为来自 Coinbase。

## 权益汇总

- Binance：现货数量含 free + locked；现货估值与 U 本位、币本位合约钱包权益分别计入。合约带单单独添加项目专用 API，只计 totalMarginBalance，不再累加 totalUnrealizedProfit；展示 totalWalletBalance 与 totalUnrealizedProfit。
- USDT、USDC 等通过公开美元参考行情估值，不硬编码为 1 USD。公开价格获取失败时标记未估值。
- 缺失报价的币种不计入已估值金额；账户读取失败或首次同步未完成时显示对应状态，不在总资产卡片增加“估值不完整”提示行。顶部总额在账户未同步、读取失败或估值不完整时显示“未估值”；分类金额仅在对应数据可估值时显示，已同步确认的零余额显示 0，未添加对应类型账户的分类也显示 0。

## 交易所及带单/跟单支持边界

| 交易所 | 当前读取范围 | 带单 / 跟单 |
|---|---|---|
| Binance 国际站 | Spot、USDⓈ-M、COIN-M | 现货带单使用项目专用 API 查询 Spot 币种余额及行情估值；合约带单使用项目专用 API 查询 FAPI v2 钱包余额、总权益、未实现盈亏及仓位。两类单独添加，不查询另一类账户；跟单组合暂未找到公开只读资产接口，不能添加 |

资金账户、理财、杠杆借贷、其他子账户未作为本版通用范围。实际权限/IP/账户未开通错误不视作空仓；建议所有账户使用只读 API，交易权限作为风险提示，不因交易权限拒绝添加。没有真实 API 凭证时，只能完成模拟接口和应用层验证，需在发布前用实际只读账户对账。

OKX、Bybit 适配代码暂保留供后续开发，产品入口和同步服务均只开放币安。已有非币安配置不会被自动删除，也不会继续同步或计入估值。

## 刷新与凭证

- 凭证及连接配置：`Security.framework` Keychain，`WhenUnlockedThisDeviceOnly`，禁止同步与跨设备恢复。
- 余额、权益与仓位只保留在当前会话的内存中，不读写资产快照文件，不保存历史流水，不进入 iCloud 或导出备份。启动时清理旧版本的 `Library/Caches/exchange-snapshot-v1.json`。
- App 在前台时每 5 分钟自动查询；启动、恢复前台及进入数字币/资产页面时查询，下拉立即查询。后台不执行定时查询；重叠请求合并为正在进行的同一次同步。
- 查询失败保留当前会话上次成功结果并提示错误，成功时间不更新。重启后只恢复连接配置，资产金额须重新从交易所获取；不再使用 24 小时缓存规则。
- 标题下使用股票页面相同的“最近更新：年月日 时分秒”格式。多个账户采用最早的成功同步时间，避免将部分成功显示成全部已更新；尚无成功结果时显示“-”。
- 移除连接删除 Keychain 中对应项与会话数据。进行中的同步不能恢复已移除连接。

## 共用界面组件

股票、资产、数字币顶部共用 `SummaryCardFrame` 与 `CurrencySelectorButton`，货币浮层继续使用 `CurrencySelector`。股票自定义表单与数字币添加表单共用 `AppFormSheet` 和圆角输入框样式；数字币测试/添加使用现有 `cancelButton` / `confirmButton`（支持禁用状态），移除连接复用 `ConfirmDeleteDialog`，空状态复用 `EmptyStateWidget`。颜色均使用 `AppColors` 语义颜色，支持深色、浅色及主题切换。

## 验证

`flutter test test/crypto` 覆盖账户权益去重、带单/跟单汇总、权限拒绝、API 签名请求、分页及双向持仓、无快照持久化、实时刷新、并发合并、失败保留、账户身份变化、重复账户、移除清理、十进制精度和添加表单测试失效。

iOS 原生存储需要真机/模拟器运行，Dart 测试使用内存存储，不会访问真实 Keychain 或真实交易所账户。

## 官方接口资料

- [Binance 账户](https://developers.binance.com/en/docs/catalog/core-trading-spot-trading/api/rest-api/account)
- [Binance API 权限](https://developers.binance.com/en/docs/catalog/core-trading-wallet/api/rest-api/account)
- [Binance U 本位账户](https://developers.binance.com/en/docs/catalog/core-trading-derivatives-trading-usd-s-m-futures/api/rest-api/account)
- [Binance Copy Trading](https://developers.binance.com/en/docs/catalog/advanced-trading-copy-trading/api/rest-api/future-copy-trading)
- [Coinbase 公开汇率](https://docs.cdp.coinbase.com/coinbase-business/track-apis/exchange-rates)

### 带单专用 API 权限与账户身份

所有账户均通过 SAPI 权限接口检查权限。具备读取权限且提现、转账权限关闭时，可以接入；若含交易权限，则在添加页显示醒目的风险提示，不直接阻止添加。带单专用 Key 无法通过权限接口核验时仍拒绝接入。不把账户 canTrade 当作 API Key 权限。App 始终仅发送查询请求。

带单账户使用签名余额接口返回的 accountAlias 识别项目，普通账户也保存对应合约钱包引用，防止同一钱包以不同用途或不同 Key 重复计入。

[币安带单专用 API 创建说明](https://www.binance.com/en-IN/support/faq/detail/2bec848b904b422197ce121d0925f20b)。

### 现货带单

`CryptoLeadMarket.spot` 通过 `/api/v3/account` 读取所有非零币种 free + locked，并通过公开现货报价计算估值；不会调用 FAPI/DAPI，也不录入成本或计算现货未实现盈亏。余额接口返回的 UID 用于账户识别，与普通现货账户引用去重；若交易所不返回 UID，验证失败，不以 API Key 哈希冒充账户身份。不能区分项目的身份信息会保守阻止重复添加。

现货、合约带单连接分别刷新，均按 `lead` 分类加入数字币及资产页总额。连接配置持久化带单类型；旧配置缺省为此前的合约带单，保持兼容。

[币安现货带单专用 API 创建说明](https://www.binance.com/zh-CN/support/faq/detail/ceb4e539b034462c9c81fa0ada65e6eb)。
