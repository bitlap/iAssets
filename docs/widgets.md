# iOS 资产组件

桌面支持小号、中号；锁屏支持行内和矩形。组件显示资产页同口径的总资产与分类金额、上次数据更新时间，点击进入资产页。App 在前台完成刷新或资产编辑后写入快照并请求 WidgetKit 刷新。现有股票收益后台任务运行时也会同步数字币并更新组件快照；数字币只在已验证 Pro 权益后读取只读 API，若后台同步失败或读不到交易所连接则保留上一份组件快照，避免把暂时无法获取的资产显示为零。组件本身不联网。组件也会请求约 5 分钟后重新读取快照；超过 30 分钟未更新时显示“已过期”。后台任务和组件的实际刷新时机均由 iOS 决定，不保证固定间隔。

组件只读取 App Group `group.org.bitlap.assets` 中的 `widget-snapshot-v1.json`。文件仅包含格式化后的总资产、股票、数字币、其他资产、币种、语言、更新时间及状态；不包含账户、持仓明细或交易所密钥。交易所凭据仍只在本机 Keychain 中，采用首次解锁后可供后台读取、不可迁移到其他设备的保护级别。旧版凭据会在用户升级后首次解锁并打开 App 时迁移。开启隐藏金额或生物识别锁时，App 会原子替换快照并删除四个金额字段。用户关闭隐私设置后，App 会重新生成快照。

发布前须在 [Apple Developer 的 Identifiers](https://developer.apple.com/account/resources/identifiers/list) 注册 App Group `group.org.bitlap.assets`，并将其关联到 `org.bitlap.assets` 和 `org.bitlap.assets.AssetsWidget` 两个 App ID，然后重新生成包含 App Groups 权限的签名配置文件。发行脚本的 `IOS_APP_PROFILE_NAME`、`IOS_WIDGET_PROFILE_NAME` 应分别指向两份 App Store 描述文件，确保导出时不会选到旧配置。详见 [Apple 的 App Groups 配置说明](https://developer.apple.com/documentation/xcode/configuring-app-groups)。
