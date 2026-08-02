import 'app_config.dart';

List<Map<String, String>> get sortOptions => [
  {'key': 'profit', 'label': SettingsConfig.sortByProfit},
  {'key': 'holdings', 'label': SettingsConfig.sortByHoldings},
  {'key': 'name', 'label': SettingsConfig.sortByName},
];
