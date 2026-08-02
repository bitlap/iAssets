import '../../config/app_config.dart';

class OpenSourceLib {
  final String name;
  final String author;
  final String license;
  final String description;
  const OpenSourceLib(this.name, this.author, this.license, this.description);
}

List<OpenSourceLib> get openSourceLibs => [
  OpenSourceLib(
    'Flutter',
    'Google',
    'BSD 3-Clause',
    SettingsConfig.licenseDescFlutter,
  ),
  OpenSourceLib(
    'Dart',
    'Google',
    'BSD 3-Clause',
    SettingsConfig.licenseDescDart,
  ),
  OpenSourceLib(
    'cupertino_icons',
    'Flutter Team',
    'MIT',
    SettingsConfig.licenseDescCupertino,
  ),
  OpenSourceLib(
    'intl',
    'Dart Team',
    'BSD 3-Clause',
    SettingsConfig.licenseDescIntl,
  ),
  OpenSourceLib(
    'http',
    'Dart Team',
    'BSD 3-Clause',
    SettingsConfig.licenseDescHttp,
  ),
  OpenSourceLib(
    'url_launcher',
    'Flutter Team',
    'BSD 3-Clause',
    SettingsConfig.licenseDescUrlLauncher,
  ),
  OpenSourceLib(
    'path_provider',
    'Flutter Team',
    'BSD 3-Clause',
    SettingsConfig.licenseDescPathProvider,
  ),
  OpenSourceLib(
    'package_info_plus',
    'Flutter Team',
    'BSD 3-Clause',
    SettingsConfig.licenseDescPackageInfo,
  ),
  OpenSourceLib(
    'workmanager',
    'Flutter Team',
    'MIT',
    SettingsConfig.licenseDescWorkmanager,
  ),
];

List<OpenSourceLib> get dataSources => [
  OpenSourceLib(
    SettingsConfig.dataSourceNameEastMoney,
    SettingsConfig.dataSourceAuthorEastMoney,
    '\u2014',
    SettingsConfig.dataSourceDescEastMoney,
  ),
  OpenSourceLib(
    SettingsConfig.dataSourceNameTencent,
    SettingsConfig.dataSourceAuthorTencent,
    '\u2014',
    SettingsConfig.dataSourceDescTencent,
  ),
  OpenSourceLib(
    'ExchangeRate-API',
    'exchangerate-api.com',
    '\u2014',
    SettingsConfig.dataSourceDescExchangeRate,
  ),
];
