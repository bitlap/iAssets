# 文档索引

这些文档说明当前实现与维护流程，技术说明以中文维护；界面和发布文案的语言覆盖单独核对，不把技术文档的示例语言数量当作产品支持范围。

| 文档 | 内容 |
| --- | --- |
| [多语言维护](localization.md) | 33 种语言、更新日志、产品描述源文件及平台映射。 |
| [发布前检查清单](../RELEASE_CHECKLIST.md) | 各发布阶段的检查与问题处理规则。 |
| [发布测试索引](release-testing.md) | 每项功能的测试入口、场景、设备与语言矩阵。 |
| [发布记录索引](release-checks/README.md) | 最新内测、待审及 GitHub tag/Release 的时点与历史记录。 |
| [iOS 发布指南](../scripts/README.md) | 签名、归档、TestFlight 上传及正式配置。 |
| [Pro 说明](pro.md) / [购买测试](pro-testing.md) | 免费限制、权益、固定老用户分界、StoreKit 与沙盒验证。 |
| [数字币只读同步](crypto-sync.md) | 账户范围、权限、估值、凭据与刷新边界。 |
| [资产分类](asset-categories.md) | 分类、模板、估值方式、排序与迁移。 |
| [股票财务口径](financial-terms.md) | 金额、盈亏与股息指标的统一定义。 |
| [iOS 组件](widgets.md) | 尺寸、语言、数据更新、隐私与 App Groups。 |
| [更新日志](../changelog/README.md) | 当前及历史版本说明，产品描述源文件。 |

`docs/release-checks/` 保存带时间、源码 SHA 和实际结果的历史记录，不随新语言或新流程出现而追溯标为通过。[早期文档审查](release-checks/documentation-review.md) 和 [构建 27 后文档审查](release-checks/documentation-review-build27.md) 分别记录当时的修正及验证范围。

`docs/images/` 为文档演示截图，仅说明截图对应时点和语言的界面；不代表全部 33 种语言或本轮真机流程已完成验收。
