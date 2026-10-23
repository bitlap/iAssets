<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="96" height="96" alt="iAssets 图标">
</p>

<h1 align="center">iAssets</h1>

<p align="center">
  看清资产，轻松记录<br>
  在一个 App 中查看股票、数字币、存款与理财。
</p>

<p align="center">
  <a href="https://github.com/bitlap/iAssets/releases/latest"><img src="https://img.shields.io/github/v/release/bitlap/iAssets" alt="最新 Release"></a>
  <a href="https://github.com/bitlap/iAssets/actions/workflows/flutter-ci.yml"><img src="https://github.com/bitlap/iAssets/actions/workflows/flutter-ci.yml/badge.svg" alt="Flutter CI"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Built with Flutter"></a>
  <img src="https://img.shields.io/badge/Platform-iOS-000000?logo=apple&logoColor=white" alt="Platform: iOS">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-BSD--3--Clause-blue.svg" alt="License: BSD 3-Clause"></a>
</p>

<p align="center">
  <a href="https://apps.apple.com/cn/app/iassets/id6790114856"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/zh-cn?size=250x83" height="40" alt="在 App Store 下载"></a>
</p>

<p align="center">
  <a href="changelog/1.6.0.md">更新日志</a> ·
  <a href="https://github.com/bitlap/iAssets/issues">反馈问题</a>
</p>

## 简介

iAssets 是一款使用 Flutter 构建的开源 iOS 个人资产管理应用。记录投资、追踪收益、查看资产分布，帮助你了解自己的财务状况。

无广告、无社区、无内购。支持简体中文、繁體中文和 English，以及浅色、深色和跟随系统主题。

## 界面预览

以下截图在 iPhone 17 Pro 和 iPad Air 13 英寸（M4）模拟器中重新生成，使用 iOS 系统字体和演示数据。点击图片可查看原图。

### iPhone 17 Pro

<details open>
<summary>简体中文 · 浅色</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-light-stocks.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 股票持仓">](docs/images/iphone-17-pro/zh-light-stocks.png) | [<img src="docs/images/iphone-17-pro/zh-light-search.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 股票搜索">](docs/images/iphone-17-pro/zh-light-search.png) | [<img src="docs/images/iphone-17-pro/zh-light-dividends.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 股息概览">](docs/images/iphone-17-pro/zh-light-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-light-crypto.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 数字币总览">](docs/images/iphone-17-pro/zh-light-crypto.png) | [<img src="docs/images/iphone-17-pro/zh-light-crypto-spot.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 现货余额">](docs/images/iphone-17-pro/zh-light-crypto-spot.png) | [<img src="docs/images/iphone-17-pro/zh-light-crypto-futures.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 合约持仓">](docs/images/iphone-17-pro/zh-light-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-light-assets.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 资产总览">](docs/images/iphone-17-pro/zh-light-assets.png) | [<img src="docs/images/iphone-17-pro/zh-light-settings.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 设置">](docs/images/iphone-17-pro/zh-light-settings.png) | [<img src="docs/images/iphone-17-pro/zh-light-custom-stock.png" width="220" alt="iPhone 17 Pro · 简体中文 · 浅色 · 自定义股票">](docs/images/iphone-17-pro/zh-light-custom-stock.png) |

</details>

<details>
<summary>简体中文 · 深色</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-dark-stocks.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 股票持仓">](docs/images/iphone-17-pro/zh-dark-stocks.png) | [<img src="docs/images/iphone-17-pro/zh-dark-search.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 股票搜索">](docs/images/iphone-17-pro/zh-dark-search.png) | [<img src="docs/images/iphone-17-pro/zh-dark-dividends.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 股息概览">](docs/images/iphone-17-pro/zh-dark-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-dark-crypto.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 数字币总览">](docs/images/iphone-17-pro/zh-dark-crypto.png) | [<img src="docs/images/iphone-17-pro/zh-dark-crypto-spot.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 现货余额">](docs/images/iphone-17-pro/zh-dark-crypto-spot.png) | [<img src="docs/images/iphone-17-pro/zh-dark-crypto-futures.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 合约持仓">](docs/images/iphone-17-pro/zh-dark-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/zh-dark-assets.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 资产总览">](docs/images/iphone-17-pro/zh-dark-assets.png) | [<img src="docs/images/iphone-17-pro/zh-dark-settings.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 设置">](docs/images/iphone-17-pro/zh-dark-settings.png) | [<img src="docs/images/iphone-17-pro/zh-dark-custom-stock.png" width="220" alt="iPhone 17 Pro · 简体中文 · 深色 · 自定义股票">](docs/images/iphone-17-pro/zh-dark-custom-stock.png) |

</details>

<details>
<summary>English · Light</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-light-stocks.png" width="220" alt="iPhone 17 Pro · English · Light · 股票持仓">](docs/images/iphone-17-pro/en-light-stocks.png) | [<img src="docs/images/iphone-17-pro/en-light-search.png" width="220" alt="iPhone 17 Pro · English · Light · 股票搜索">](docs/images/iphone-17-pro/en-light-search.png) | [<img src="docs/images/iphone-17-pro/en-light-dividends.png" width="220" alt="iPhone 17 Pro · English · Light · 股息概览">](docs/images/iphone-17-pro/en-light-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-light-crypto.png" width="220" alt="iPhone 17 Pro · English · Light · 数字币总览">](docs/images/iphone-17-pro/en-light-crypto.png) | [<img src="docs/images/iphone-17-pro/en-light-crypto-spot.png" width="220" alt="iPhone 17 Pro · English · Light · 现货余额">](docs/images/iphone-17-pro/en-light-crypto-spot.png) | [<img src="docs/images/iphone-17-pro/en-light-crypto-futures.png" width="220" alt="iPhone 17 Pro · English · Light · 合约持仓">](docs/images/iphone-17-pro/en-light-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-light-assets.png" width="220" alt="iPhone 17 Pro · English · Light · 资产总览">](docs/images/iphone-17-pro/en-light-assets.png) | [<img src="docs/images/iphone-17-pro/en-light-settings.png" width="220" alt="iPhone 17 Pro · English · Light · 设置">](docs/images/iphone-17-pro/en-light-settings.png) | [<img src="docs/images/iphone-17-pro/en-light-custom-stock.png" width="220" alt="iPhone 17 Pro · English · Light · 自定义股票">](docs/images/iphone-17-pro/en-light-custom-stock.png) |

</details>

<details>
<summary>English · Dark</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-dark-stocks.png" width="220" alt="iPhone 17 Pro · English · Dark · 股票持仓">](docs/images/iphone-17-pro/en-dark-stocks.png) | [<img src="docs/images/iphone-17-pro/en-dark-search.png" width="220" alt="iPhone 17 Pro · English · Dark · 股票搜索">](docs/images/iphone-17-pro/en-dark-search.png) | [<img src="docs/images/iphone-17-pro/en-dark-dividends.png" width="220" alt="iPhone 17 Pro · English · Dark · 股息概览">](docs/images/iphone-17-pro/en-dark-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-dark-crypto.png" width="220" alt="iPhone 17 Pro · English · Dark · 数字币总览">](docs/images/iphone-17-pro/en-dark-crypto.png) | [<img src="docs/images/iphone-17-pro/en-dark-crypto-spot.png" width="220" alt="iPhone 17 Pro · English · Dark · 现货余额">](docs/images/iphone-17-pro/en-dark-crypto-spot.png) | [<img src="docs/images/iphone-17-pro/en-dark-crypto-futures.png" width="220" alt="iPhone 17 Pro · English · Dark · 合约持仓">](docs/images/iphone-17-pro/en-dark-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/iphone-17-pro/en-dark-assets.png" width="220" alt="iPhone 17 Pro · English · Dark · 资产总览">](docs/images/iphone-17-pro/en-dark-assets.png) | [<img src="docs/images/iphone-17-pro/en-dark-settings.png" width="220" alt="iPhone 17 Pro · English · Dark · 设置">](docs/images/iphone-17-pro/en-dark-settings.png) | [<img src="docs/images/iphone-17-pro/en-dark-custom-stock.png" width="220" alt="iPhone 17 Pro · English · Dark · 自定义股票">](docs/images/iphone-17-pro/en-dark-custom-stock.png) |

</details>

### iPad Air 13 英寸

<details>
<summary>简体中文 · 浅色</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-light-stocks.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 股票持仓">](docs/images/ipad-air-13/zh-light-stocks.png) | [<img src="docs/images/ipad-air-13/zh-light-search.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 股票搜索">](docs/images/ipad-air-13/zh-light-search.png) | [<img src="docs/images/ipad-air-13/zh-light-dividends.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 股息概览">](docs/images/ipad-air-13/zh-light-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-light-crypto.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 数字币总览">](docs/images/ipad-air-13/zh-light-crypto.png) | [<img src="docs/images/ipad-air-13/zh-light-crypto-spot.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 现货余额">](docs/images/ipad-air-13/zh-light-crypto-spot.png) | [<img src="docs/images/ipad-air-13/zh-light-crypto-futures.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 合约持仓">](docs/images/ipad-air-13/zh-light-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-light-assets.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 资产总览">](docs/images/ipad-air-13/zh-light-assets.png) | [<img src="docs/images/ipad-air-13/zh-light-settings.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 设置">](docs/images/ipad-air-13/zh-light-settings.png) | [<img src="docs/images/ipad-air-13/zh-light-custom-stock.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 浅色 · 自定义股票">](docs/images/ipad-air-13/zh-light-custom-stock.png) |

</details>

<details>
<summary>简体中文 · 深色</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-dark-stocks.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 股票持仓">](docs/images/ipad-air-13/zh-dark-stocks.png) | [<img src="docs/images/ipad-air-13/zh-dark-search.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 股票搜索">](docs/images/ipad-air-13/zh-dark-search.png) | [<img src="docs/images/ipad-air-13/zh-dark-dividends.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 股息概览">](docs/images/ipad-air-13/zh-dark-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-dark-crypto.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 数字币总览">](docs/images/ipad-air-13/zh-dark-crypto.png) | [<img src="docs/images/ipad-air-13/zh-dark-crypto-spot.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 现货余额">](docs/images/ipad-air-13/zh-dark-crypto-spot.png) | [<img src="docs/images/ipad-air-13/zh-dark-crypto-futures.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 合约持仓">](docs/images/ipad-air-13/zh-dark-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/zh-dark-assets.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 资产总览">](docs/images/ipad-air-13/zh-dark-assets.png) | [<img src="docs/images/ipad-air-13/zh-dark-settings.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 设置">](docs/images/ipad-air-13/zh-dark-settings.png) | [<img src="docs/images/ipad-air-13/zh-dark-custom-stock.png" width="220" alt="iPad Air 13 英寸 · 简体中文 · 深色 · 自定义股票">](docs/images/ipad-air-13/zh-dark-custom-stock.png) |

</details>

<details>
<summary>English · Light</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-light-stocks.png" width="220" alt="iPad Air 13 英寸 · English · Light · 股票持仓">](docs/images/ipad-air-13/en-light-stocks.png) | [<img src="docs/images/ipad-air-13/en-light-search.png" width="220" alt="iPad Air 13 英寸 · English · Light · 股票搜索">](docs/images/ipad-air-13/en-light-search.png) | [<img src="docs/images/ipad-air-13/en-light-dividends.png" width="220" alt="iPad Air 13 英寸 · English · Light · 股息概览">](docs/images/ipad-air-13/en-light-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-light-crypto.png" width="220" alt="iPad Air 13 英寸 · English · Light · 数字币总览">](docs/images/ipad-air-13/en-light-crypto.png) | [<img src="docs/images/ipad-air-13/en-light-crypto-spot.png" width="220" alt="iPad Air 13 英寸 · English · Light · 现货余额">](docs/images/ipad-air-13/en-light-crypto-spot.png) | [<img src="docs/images/ipad-air-13/en-light-crypto-futures.png" width="220" alt="iPad Air 13 英寸 · English · Light · 合约持仓">](docs/images/ipad-air-13/en-light-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-light-assets.png" width="220" alt="iPad Air 13 英寸 · English · Light · 资产总览">](docs/images/ipad-air-13/en-light-assets.png) | [<img src="docs/images/ipad-air-13/en-light-settings.png" width="220" alt="iPad Air 13 英寸 · English · Light · 设置">](docs/images/ipad-air-13/en-light-settings.png) | [<img src="docs/images/ipad-air-13/en-light-custom-stock.png" width="220" alt="iPad Air 13 英寸 · English · Light · 自定义股票">](docs/images/ipad-air-13/en-light-custom-stock.png) |

</details>

<details>
<summary>English · Dark</summary>

| 股票持仓 | 股票搜索 | 股息概览 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-dark-stocks.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 股票持仓">](docs/images/ipad-air-13/en-dark-stocks.png) | [<img src="docs/images/ipad-air-13/en-dark-search.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 股票搜索">](docs/images/ipad-air-13/en-dark-search.png) | [<img src="docs/images/ipad-air-13/en-dark-dividends.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 股息概览">](docs/images/ipad-air-13/en-dark-dividends.png) |

| 数字币总览 | 现货余额 | 合约持仓 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-dark-crypto.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 数字币总览">](docs/images/ipad-air-13/en-dark-crypto.png) | [<img src="docs/images/ipad-air-13/en-dark-crypto-spot.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 现货余额">](docs/images/ipad-air-13/en-dark-crypto-spot.png) | [<img src="docs/images/ipad-air-13/en-dark-crypto-futures.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 合约持仓">](docs/images/ipad-air-13/en-dark-crypto-futures.png) |

| 资产总览 | 设置 | 自定义股票 |
| --- | --- | --- |
| [<img src="docs/images/ipad-air-13/en-dark-assets.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 资产总览">](docs/images/ipad-air-13/en-dark-assets.png) | [<img src="docs/images/ipad-air-13/en-dark-settings.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 设置">](docs/images/ipad-air-13/en-dark-settings.png) | [<img src="docs/images/ipad-air-13/en-dark-custom-stock.png" width="220" alt="iPad Air 13 英寸 · English · Dark · 自定义股票">](docs/images/ipad-air-13/en-dark-custom-stock.png) |

</details>

## 核心功能

| 功能 | 你可以做什么 |
| --- | --- |
| 股票持仓 | 搜索并添加股票，记录买卖、手续费和派息，查看成本、盈亏与持仓详情 |
| 股息与收益 | 汇总税后股息，按市场筛选，查看今日盈亏与不同时间范围的收益曲线 |
| 数字币资产 | 连接币安账户，查看现货、合约及带单资产，并计入总资产 |
| 资产总览 | 以彩色卡片分类管理现金、存款、理财和公积金，查看资产分布，支持折叠与拖拽排序 |
| 多币种换算 | 切换显示币种，统一查看不同市场和账户的资产估值 |
| 数据同步 | 通过 iCloud 同步股票、手动资产、记录和设置 |

股票搜索覆盖美股、港股、沪深京、日本、韩国、英国及场外市场，也支持基金、债券、指数和三板。搜索、持仓与股息可按具体交易所或市场筛选，使用一致的名称和颜色标识；也可手动添加自定义股票，价格旁可直接选择货币，底部按钮完成添加。

资产卡片按名称保持固定配色，适配深浅主题；创建时间靠左、更新时间靠右，查看记录更清晰。

数字币目前仅支持币安普通账户及现货、合约带单账户，跟单组合暂不支持。仅提供资产查看，不提供交易或转账。详细范围见[数字币说明](docs/crypto-sync.md)。

## 数据与隐私

- 股票与手动资产保存在本地，支持离线查看和记录，并可通过 iCloud 同步。
- 数字币连接信息仅保存在本机 Keychain；余额与持仓仅在当前会话中保留，不参与 iCloud 同步。
- 股票搜索来自东方财富，行情来自腾讯、东方财富及 Yahoo Finance（雅虎财经）。伦敦行情来自雅虎财经；日股、韩股及场外市场在原行情不可用时使用雅虎备用报价，可能存在延迟。
- 股票搜索显示报价及货币代码；伦敦市场按实际报价币种记录，英便士 GBp/GBX 报价统一换算为英镑 GBP 显示。资产汇总时再按所选货币换算。
- 汇率及数字币估值使用公开数据和交易所查询结果。
- 股票公司图标来自 Financial Modeling Prep 和 Stocktwits。无法获取图标或已知图片不是 Logo 时显示文字占位，也可为自定义股票选择本地图标。
- 行情与估值可能存在延迟，仅供个人资产记录与参考。

## 本地运行

需要 macOS、Xcode、CocoaPods，以及 Flutter 3.44.4（与 CI 一致，Dart SDK 要求见 [pubspec.yaml](pubspec.yaml)）。

```bash
git clone https://github.com/bitlap/iAssets.git
cd iAssets
flutter pub get

# 复制签名配置，填入自己的 Apple Developer Team ID
cp ios/Config.example.xcconfig ios/Config.xcconfig

# 启动 iOS 模拟器并运行
open -a Simulator
flutter run
```

在 `ios/Config.xcconfig` 中填写 `DEVELOPMENT_TEAM`。如需使用自己的应用标识与 iCloud 配置，请打开 `ios/Runner.xcworkspace`，同步调整签名、Bundle Identifier 和 iCloud 容器。

构建与上传说明见 [iOS 发布指南](scripts/README.md)。

## 参与贡献

欢迎通过 [Issues](https://github.com/bitlap/iAssets/issues) 报告问题、提出建议，或提交 Pull Request。

提交前请运行以下检查，在 PR 中说明改动和验证结果；界面调整请附截图。

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

涉及界面的改动请沿用现有样式，并兼顾简体中文、繁体中文、英文和深浅主题。

## 许可证

本项目采用 [BSD 3-Clause License](LICENSE)。
