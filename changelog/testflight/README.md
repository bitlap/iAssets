# TestFlight 测试重点与已知限制

`<版本>/<App 语言代码>.txt` 保存各语言的测试重点、已知限制与反馈入口，目前 2.2.0 对应全部 33 种 App 语言。这些文件是测试说明的补充部分，不代替对应版本的多语言更新日志。

生成 What to Test：

```bash
python3 scripts/testflight_release_notes.py --version 2.2.0 --build 22 --language zh
```

生成器依次输出实际版本/构建号、该语言 changelog、测试重点与已知限制，并检查 4000 字符上限。后台必须逐构建、逐平台语言保存和回读。不要把新修复复制到尚未包含相应代码的旧构建；平台不支持的语言仅保留本地文案并记录回退，不声称线上已翻译。

本轮构建 10 和 22 的实际语言覆盖见 [同步记录](../../docs/release-checks/2.2.0-22-metadata-sync.md)。完整发布流程见 [发布指南](../../scripts/README.md)。
