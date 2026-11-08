# 发布记录索引

每份记录描述其执行时点的源码、构建和验证结果。旧记录中的“当前”“本轮”和 Latest 等状态只适用于当时，不代表最新后台状态；后续操作通过新记录说明，不把新功能或验收结果倒填到旧构建。

截至 2026-11-08 构建 27 重新送审后的最后一次回读：

| 阶段 | 结果 | 记录 |
| --- | --- | --- |
| TestFlight | 2.2.0（27）已处理并可供内部测试；含紧凑菜单与最终卡片顺序 | [构建 27 内测](2.2.0-27-testflight.md) |
| GitHub | 原 v2.2.0 Release 为 Latest，tag 指向构建 27 源码 91dab20d5090fda2447b1478835bbb9ce48b2784；没有额外预发布或 IPA 附件 | [构建 27 内测及 Release 同步](2.2.0-27-testflight.md) |
| App Store | 已撤回原构建 22 的审核，替换为构建 27 并重新送审；WAITING_FOR_REVIEW，审核通过后自动发布 | [构建 27 送审](2.2.0-27-app-store.md) |
| 人工验收 | 自动转存跨日/重启、升级及数据保留、iCloud 多设备、真实购买/恢复与生产老用户 Pro 等仍需真机结果 | [测试索引](../release-testing.md) |

## 2.2.0 历史过程

| 阶段 | 记录 |
| --- | --- |
| 构建 10 初始内测 | [发布记录](2.2.0-10-testflight.md) |
| 构建 22 送审及文案 | [送审](2.2.0-22-app-store.md)、[元数据同步](2.2.0-22-metadata-sync.md)、[文案对齐](2.2.0-22-copy-parity.md) |
| 构建 23 分类修改及手动转存 | [内测](2.2.0-23-testflight.md)、[Release 更新](2.2.0-23-github-release.md)、[tag 调整](2.2.0-23-github-retag.md) |
| 构建 24 自动转存 | [内测](2.2.0-24-testflight.md) |
| 构建 26 样式与说明 | [正式包准备](2.2.0-26-app-store.md)、[临时预发布](2.2.0-26-notes-release.md)、[删除预发布并修正原 tag](2.2.0-26-github-retag.md) |
| 构建 27 紧凑菜单及内测 | [发布记录](2.2.0-27-testflight.md) |
| 构建 27 替换待审版本 | [准备、用户取消人工验收门槛与送审结果](2.2.0-27-app-store.md) |
| GitHub 草稿流程 | [草稿修复](2.2.0-github-draft.md) |
| 文档审查 | [早期审查](documentation-review.md)、[构建 27 后审查](documentation-review-build27.md) |

发布记录中的 `build/` 与 `/tmp/` 证据路径指执行机器上的本地文件，不是 GitHub 下载附件；归档、IPA 和 dSYM 另行保存。发布前仍须重新执行 [检查清单](../../RELEASE_CHECKLIST.md)，不能沿用历史“通过”。
