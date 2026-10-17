# iOS Release 编译与上传

使用 App Store Connect **团队 API Key**，从 App Store Connect 获取 Key ID、Issuer ID 和 `.p8` 私钥；账号/API Key 需要具有该 App 的上传权限。私钥保存在仓库外，本机需安装 Flutter、完整 Xcode、CocoaPods，并准备签名证书或启用 Xcode 自动签名。

以下命令均在项目根目录执行。

```bash
cp scripts/release_ios.env.example scripts/release_ios.env
# 编辑 scripts/release_ios.env，填写密钥路径、Key ID 和 Issuer ID

# 检查配置、查看命令，不编译或上传
./scripts/release_ios.sh --dry-run

# 一键编译、签名、导出 IPA 并上传 App Store Connect
./scripts/release_ios.sh
```

脚本自动读取同目录的 `release_ios.env`，无需手动 `source`。外部环境变量优先于文件配置，例如：

```bash
BUILD_NUMBER=1.6.2 ./scripts/release_ios.sh
```

版本默认读取 `pubspec.yaml`，构建号读取 `+` 后缀（缺省为 `1`），可通过 `BUILD_NAME`、`BUILD_NUMBER` 覆盖。团队默认读取 `ios/Config.xcconfig`，也可指定 `APPLE_TEAM_ID`。Xcode 在上传时管理构建号以避免重复，因此上传后的构建号可能与本地导出的 IPA 不同。

归档、IPA、导出配置及各阶段日志保存在 `build/ios/releases/` 的独立目录；可用 `RELEASE_OUTPUT_DIR` 指定一个尚不存在的目录。任何阶段失败立即停止，上传成功后仍需等待 Apple 处理，不会自动提交审核或发布。
