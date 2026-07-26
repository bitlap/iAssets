# 资产管理（iAssets）

<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" height="128" alt="iAssets Logo">
</p>

一款使用 Flutter 开发的个人资产管理 iOS APP，采用 Material 3 暗色主题，支持多币种换算、iCloud 同步、后台收益快照等能力。

已在 [App Store](https://apps.apple.com/cn/app/iassets/id6790114856) 上线。无内购无广告，使用公开 API，不保证严格实时。

## 页面与模块

### 首页（股票管理）

**顶部概况卡**
- 展示总资产、持仓市值、总成本、总盈亏、已实现盈亏、税后总股息
- 点击货币标签切换多币种展示（CNY / USD / HKD 等），汇率实时换算
- 展开后可查看今日盈亏迷你曲线（红涨绿跌，虚线零轴），点击区域展开全尺寸收益曲线
- **右上角**：股息全局概览按钮（`Icons.payments_outlined`）和设置按钮

**持仓列表**
- 每行展示 Logo、公司名/代码、市值、持仓数量、盈亏金额与百分比
- 点击展开详情：总成本、均价、最高/最低买入价、买入/卖出次数
- 持仓卡片支持加仓、减仓、平仓、派息、删除操作

**搜索与建仓**
- 支持美股、港股、A 股按代码或名称搜索
- 市场筛选（全部/美股/港股/A 股）
- 添加时自动创建首笔买入记录，自动带入默认手续费

**收益曲线**
- 标题行始终可见，下方固定展示今日盈亏迷你曲线
- 点击展开全尺寸曲线，支持今天/7天/30天/180天/360天粒度切换
- 前台 60 秒定时刷新、切后台和后台任务均记录收益快照，历史最多保留一年

**排序与刷新**
- 列表头支持按盈亏、持仓市值、代码排序
- 每 60 秒自动刷新行情，下拉可手动刷新，表头显示最近更新时间

### 全局股息概览

从首页右上角股息按钮进入，查看所有股票的派息汇总：
- 按市场筛选（全部/美股/港股/A 股）
- 展示总派息金额、税前/税后对比
- 每条记录包含：派息日期、每股金额、持仓股数、税率、税后总额
- 左滑可删除，删除后自动重算资产数据

### 资产管理

- **总览卡片**：总资产、股票市值、总成本、总盈亏、税后总股息、持仓比例
- **多类型管理**：现金、活期存款、定期存款、理财/基金、公积金
- **分组折叠**：资产按分类分组，每个分类可独立折叠/展开，状态持久化
- **拖拽排序**：分类标题和同分类内资产均可拖拽调整顺序；跨分类拖拽拦截提示
- **定期存款**：按本金、年利率、期限自动计算总值
- **理财/基金**：按持有份额和单位净值计算当前价值

### 设置

- **本地货币**：CNY / CNH / USD / HKD / EUR / JPY / GBP / AUD / CAD / CHF / KRW / SGD 切换
- **iCloud 同步**：自动同步设置、股票、记录、资产和收益快照
- **排序偏好**：默认排序字段、排序方向
- **平仓保留**：平仓后是否在列表中保留该股票
- **默认手续费**：按比例或固定金额配置，建仓/加减仓时自动填入
- **计算公式**：各指标（总资产、总成本、盈亏等）计算方式说明
- **意见反馈、开源软件说明、版本信息**

### 记录管理

每只股票的「操作」和「派息」记录通过底部弹窗管理（从持仓卡片点击进入）。

**操作记录**
- 显示每笔操作：描述、股数、单价 × 股数、总金额、更新时间
- 支持编辑（修改价格和股数）和左滑删除
- 修改后自动重算持仓数据

**派息记录**
- 显示每笔派息：派息代码、总金额、计算公式、派息日期、更新时间
- 支持编辑（修改日期、每股金额、股数、税率）和左滑删除
- 修改后自动重算资产数据

## 技术栈

| 类别   | 技术                                    |
|------|---------------------------------------|
| 框架   | Flutter 3.44.4（CI） / Dart SDK ^3.12.2 |
| UI   | Material 3 暗色主题                      |
| 设计系统 | 统一 AppColors / TextStyles 常量体系       |
| 本地化  | flutter_localizations、intl            |
| 网络   | http                                  |
| 本地存储 | 文件系统（JSON）                            |
| 路径访问 | path_provider                         |
| 云同步  | iCloud（CloudKit / CloudDocuments）     |
| 后台任务 | workmanager                           |
| 版本信息 | package_info_plus                     |
| 系统调用 | url_launcher                          |
| 数据源  | 东方财富搜索、腾讯行情、东方财富行情补充、ExchangeRate-API |

## 快速开始

```bash
# 克隆
git clone https://github.com/bitlap/assets
cd assets

# 依赖环境
# - Flutter 3.44.4 stable
# - Xcode / CocoaPods
# - iOS 14.0+

# 配置 Apple Developer Team ID（用于真机调试和签名）
cp ios/Config.example.xcconfig ios/Config.xcconfig
# 编辑 ios/Config.xcconfig，填入你的 DEVELOPMENT_TEAM
#
# 如果你需要使用自己的签名 / 包名 / iCloud 配置，还要同步修改：
# - Bundle Identifier（当前默认 org.bitlap.assets）
# - iCloud Container / kvstore 标识（当前默认 iCloud.org.bitlap.assets）

# 安装依赖
flutter pub get

# 运行（iOS 模拟器）
open -a Simulator
flutter run

# 真机调试 / 签名检查
open ios/Runner.xcworkspace
flutter devices            # 查看设备 ID
flutter run -d <device_id>

# 代码分析
flutter analyze

# 单元测试
flutter test

# 格式化
dart format .
```

## 贡献

欢迎提交 Issue 和 Pull Request。

### 开发准则

- 保持 `flutter analyze --fatal-infos` 无错误
- 提交前运行 `dart format .`
- 新增 UI 优先使用 `AppColors` 和 `TextStyles` 常量，避免硬编码颜色和样式
- PR 标题用中文简述改动，描述中英文均可

### PR 流程

1. Fork 并创建特性分支
2. 确保 `flutter analyze` 通过
3. 提交 PR，描述改了什么和为什么
4. 维护者 review 后合并

## 配置

| 配置项       | 值                                               | 说明                         |
|-----------|-------------------------------------------------|----------------------------|
| 行情刷新间隔    | 60 秒                                            | 前台定时刷新行情                   |
| 首次刷新延迟    | 3 秒                                             | 启动后延迟刷新，避免冷启动阻塞            |
| 行情缓存      | 15 分钟                                           | 股票行情缓存有效期                  |
| 搜索缓存      | 5 分钟                                            | 搜索结果缓存有效期                  |
| 汇率缓存      | 24 小时                                           | 汇率缓存有效期                    |
| 搜索防抖      | 1000 ms                                         | 输入停止后延迟搜索                  |
| API 熔断    | 连续 3 次失败，冷却 5 分钟                                | 搜索、行情、汇率请求共用保护策略           |
| HTTP 超时   | 15 秒                                            | 单次请求超时上限                   |
| 后台快照间隔    | 10 分钟                                           | WorkManager 定时记录收益快照       |
| 支持币种      | CNY、CNH、USD、HKD、EUR、JPY、GBP、AUD、CAD、CHF、KRW、SGD | 当前代码实际支持                   |
| 数据源       | 东方财富搜索、腾讯行情、东方财富行情补充、ExchangeRate-API           | 当前代码实际使用                   |
| iOS 最低版本  | 14.0                                            | 当前 Xcode 工程配置              |
| Bundle ID | `org.bitlap.assets`                             | 当前工程默认值，克隆后可按需修改           |
| Team ID   | `ios/Config.xcconfig`                           | 通过 `DEVELOPMENT_TEAM` 配置签名 |
| iCloud 容器 | `iCloud.org.bitlap.assets`                      | 若修改包名需同步调整                 |
| 后台任务标识    | `profit-snapshot`                               | 已注册到 iOS BGTaskScheduler   |
