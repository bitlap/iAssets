# 发布工作约定

执行发布相关任务（上传 TestFlight、提交 App Store 审核、正式发布、创建或修正 GitHub tag/Release）前，先阅读并按阶段执行 [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)，同时阅读 [iOS 发布指南](scripts/README.md)。仅修改代码或文档时，执行与变更相关的检查；本清单不扩大用户授权的发布范围。

每次发布单独记录版本、实际构建号、完整提交 SHA、检查结果与证据。发现问题先向用户提示，再在已授权范围内修复并复查。影响发布正确性的问题未解决时停止后续发布操作；未执行或无法验证的项目必须明确标记，不能宣称通过。
