# iOS 资产组件

桌面支持小号、中号、大号；锁屏支持行内和矩形。组件显示资产页同口径的总资产与分类金额、上次数据更新时间，点击进入资产页。App 在前台完成刷新或资产编辑后写入快照并请求 WidgetKit 刷新；组件本身不联网。超过 30 分钟未更新时显示“已过期”，实际刷新时机仍由 iOS 决定。

组件只读取 App Group `group.org.bitlap.assets` 中的 `widget-snapshot-v1.json`。文件仅包含格式化后的总资产、股票、数字币、其他资产、币种、语言、更新时间及状态；不包含账户、持仓明细或交易所密钥。开启隐藏金额或生物识别锁时，App 会原子替换快照并删除四个金额字段。用户关闭隐私设置后，App 会重新生成快照。

发布前须在 [Apple Developer 的 Identifiers](https://developer.apple.com/account/resources/identifiers/list) 注册 App Group `group.org.bitlap.assets`，并将其关联到 `org.bitlap.assets` 和 `org.bitlap.assets.AssetsWidget` 两个 App ID，然后重新生成包含 App Groups 权限的签名配置文件。详见 [Apple 的 App Groups 配置说明](https://developer.apple.com/documentation/xcode/configuring-app-groups)。
