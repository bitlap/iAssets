# iOS 资产组件

桌面支持小号、中号；锁屏支持行内和矩形。组件显示 App 最近一次在前台整理的总资产、分类金额和更新时间，点击进入资产页。App 前台刷新、资产编辑或隐私设置变更后会写入共享快照并请求组件重载。组件不单独定时联网，也不通过后台任务查询数字币或生成快照。超过 30 分钟未更新时显示“已过期”。更新时间居中显示，支持与 App 相同的 33 种语言，并使用对应语言的日期和数字格式；原有中英文日期格式保留。

在 App 中切换语言后，会重新生成共享快照并请求组件刷新；阿拉伯语、波斯语和希伯来语使用从右向左布局。组件预览不显示实际资产金额，但会从已有快照读取所选语言，组件选择页说明也沿用该语言；没有可用快照时跟随系统，不支持的语言回退英文。刷新由 WidgetKit 调度，语言变更可能需要等待系统更新。

数字币账户请求失败，或原本可估值的币种、钱包缺少报价时，组件保留该账户上次可用的金额和对应时间，避免把缺失估值误写为 0。首次同步、重启后尚无账户结果或权益验证未完成时，继续使用已有共享快照。明确查询到零余额或移除连接后，才将对应金额更新为 0。持续缺价的其他币种不会阻止已估值金额正常更新，相关快照仍标记为不完整。

组件只读取 App Group `group.org.bitlap.assets` 中的 `widget-snapshot-v1.json`。文件仅包含格式化后的总资产、股票、数字币、其他资产、币种、语言、更新时间及状态；不包含账户、持仓明细或交易所密钥。交易所凭据仍只在本机 Keychain 中，新保存的凭据采用设备解锁时可读取、不可迁移到其他设备的保护级别。开启隐藏金额或生物识别锁时，App 会原子替换快照并删除四个金额字段，同时将隐私状态写入 App Group；组件渲染时也会检查该状态。WidgetKit 可能短暂保留旧画面，App 会请求系统立即重载，组件的下一次时间线读取也会再次检查。用户关闭隐私设置后，App 会重新生成快照。

发布前须在 [Apple Developer 的 Identifiers](https://developer.apple.com/account/resources/identifiers/list) 注册 App Group `group.org.bitlap.assets`，并将其关联到 `org.bitlap.assets` 和 `org.bitlap.assets.AssetsWidget` 两个 App ID，然后重新生成包含 App Groups 权限的签名配置文件。发行脚本的 `IOS_APP_PROFILE_NAME`、`IOS_WIDGET_PROFILE_NAME` 应分别指向两份 App Store 描述文件，确保导出时不会选到旧配置。详见 [Apple 的 App Groups 配置说明](https://developer.apple.com/documentation/xcode/configuring-app-groups)。
