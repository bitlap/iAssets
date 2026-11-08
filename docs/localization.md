# 多语言维护与发布文案

## 语言来源与覆盖

以 [`L10n.languages`](../lib/l10n/l10n.dart) 为语言注册表，目前为 33 种。App 字符串、iOS 权限说明、小组件及当前版本更新日志都按该表逐一核对。中简、中繁和英文仅是其中三种，不能代替全量检查。

[2.2.0 更新日志](../changelog/2.2.0.md) 已提供全部 33 种语言，每种 8 条且主题顺序一致。新增译文已做结构、数量和术语一致性检查，尚未经过全部母语人工校对，结构校验不代表翻译质量验收。

产品描述的本地源文件也覆盖全部语言。[搜索关键词源文件](../changelog/app_store/keywords.json) 按 App 代码保存；发布时沿用既有平台关键词并补齐新语言的必填项，逐条核对 100 字符上限及后台回读。原有三份文件保留路径；新增描述复用对应语言目录中的功能、隐私和 Pro 文案，不自动修改后台。TestFlight 的 What to Test 应在更新说明之外补充本构建的测试重点和已知限制。

## 平台语言映射

下表是准备文案时的 App Store locale 参考，不代表后台已建立该语言，也不保证 TestFlight 接受相同代码。发布时分别确认 App Store 与 TestFlight 的可用语言、保存结果及回退，并按构建记录实际状态。

Apple 的[可本地化语言列表](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)列有 Bangla，未列 Filipino 和 Persian 的专属语言。不能因界面支持这些语言就宣称商店同样支持；也不能把英文回退记为完成翻译。元数据最终展示受已配置语言、主语言、用户设备和商店地区影响，见 [Apple 本地化说明](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)。平台支持范围会变化，发布时重新核对。

| App 代码 | 更新日志标题 | App Store 参考 locale | 本地产品描述 |
| --- | --- | --- | --- |
| `zh` | 简体中文 | `zh-Hans` | [文案](../changelog/app_store.txt) |
| `zh_Hant` | 繁體中文 | `zh-Hant` | [文案](../changelog/app_store_hant.txt) |
| `en` | English | `en-US` | [文案](../changelog/app_store_en.txt) |
| `ja` | 日本語 | `ja` | [文案](../changelog/app_store/ja.txt) |
| `ko` | 한국어 | `ko` | [文案](../changelog/app_store/ko.txt) |
| `fr` | Français | `fr-FR` | [文案](../changelog/app_store/fr.txt) |
| `de` | Deutsch | `de-DE` | [文案](../changelog/app_store/de.txt) |
| `es` | Español | `es-ES` | [文案](../changelog/app_store/es.txt) |
| `pt_BR` | Português (Brasil) | `pt-BR` | [文案](../changelog/app_store/pt_BR.txt) |
| `it` | Italiano | `it` | [文案](../changelog/app_store/it.txt) |
| `ru` | Русский | `ru` | [文案](../changelog/app_store/ru.txt) |
| `ar` | العربية | `ar-SA` | [文案](../changelog/app_store/ar.txt) |
| `hi` | हिन्दी | `hi` | [文案](../changelog/app_store/hi.txt) |
| `id` | Bahasa Indonesia | `id` | [文案](../changelog/app_store/id.txt) |
| `vi` | Tiếng Việt | `vi` | [文案](../changelog/app_store/vi.txt) |
| `th` | ไทย | `th` | [文案](../changelog/app_store/th.txt) |
| `tr` | Türkçe | `tr` | [文案](../changelog/app_store/tr.txt) |
| `nl` | Nederlands | `nl-NL` | [文案](../changelog/app_store/nl.txt) |
| `pl` | Polski | `pl` | [文案](../changelog/app_store/pl.txt) |
| `pt_PT` | Português (Portugal) | `pt-PT` | [文案](../changelog/app_store/pt_PT.txt) |
| `uk` | Українська | `uk` | [文案](../changelog/app_store/uk.txt) |
| `ms` | Bahasa Melayu | `ms` | [文案](../changelog/app_store/ms.txt) |
| `fil` | Filipino | 未列专属语言；按平台回退 | [文案](../changelog/app_store/fil.txt) |
| `bn` | বাংলা | `bn-BD` | [文案](../changelog/app_store/bn.txt) |
| `fa` | فارسی | 未列专属语言；按平台回退 | [文案](../changelog/app_store/fa.txt) |
| `he` | עברית | `he` | [文案](../changelog/app_store/he.txt) |
| `sv` | Svenska | `sv` | [文案](../changelog/app_store/sv.txt) |
| `da` | Dansk | `da` | [文案](../changelog/app_store/da.txt) |
| `nb` | Norsk bokmål | `no` | [文案](../changelog/app_store/nb.txt) |
| `fi` | Suomi | `fi` | [文案](../changelog/app_store/fi.txt) |
| `cs` | Čeština | `cs` | [文案](../changelog/app_store/cs.txt) |
| `ro` | Română | `ro` | [文案](../changelog/app_store/ro.txt) |
| `el` | Ελληνικά | `el` | [文案](../changelog/app_store/el.txt) |

2.2.0 正式版准备阶段已保存并回读 32 个 App Store 版本语言条目：31 种平台支持的项目语言，加上保留的 `en-GB`；描述和更新说明均逐项一致。主语言为 `zh-Hans`，Filipino/波斯语使用平台回退，不能计为商店翻译。原有三语截图沿用，新增语言尚无单独翻译截图，按平台规则回退。后台保存不等于审核通过或上架，见 [2.2.0（22）正式发布记录](release-checks/2.2.0-22-app-store.md)。TestFlight 的最近一次记录仍仅覆盖三语，见 [内测记录](release-checks/2.2.0-10-testflight.md)。全部母语校对仍未完成。

## 更新与验证

1. 修改语言注册表和 `lib/l10n/strings_*.dart`，保持键及动态参数一致。
2. 执行 `python3 scripts/sync_native_l10n.py`，核对原生权限说明、组件文案和语言声明。
3. 为当前 `changelog/<版本>.md` 增加同名语言段，保持对应条目的含义、顺序和必要限制一致，并准备产品描述源文件。
4. 执行 `python3 scripts/check_release_notes.py` 和 `python3 scripts/test_release_notes.py`。缺少语言、英文整段回退、条目数量不一致、产品描述缺失或缺少条款链接都会失败。
5. 发布文案时按平台映射逐语言保存并回读，区分本地准备、后台保存、人工校对及实际可见状态。

检查脚本默认使用 `pubspec.yaml` 的当前版本；`--version` 可指定需按当前语言范围校验的版本，不用于把旧版本自动补成新版本的语言范围。历史更新日志保留当时的功能、语言及发布事实，见 [更新日志索引](../changelog/README.md)。

GitHub 草稿工作流在创建草稿前执行语言覆盖检查，再同步完整 changelog；公开发表仍需单独确认版本、tag、发布类型和实际 App Store/TestFlight 状态。
