import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_config.dart';
import 'config/app_colors.dart';
import 'config/app_theme.dart';
import 'l10n/l10n.dart';
import 'services/settings_service.dart';
import 'utils/logo_cacher.dart';
import 'widgets/stock/stock_portfolio_page.dart';
import 'widgets/asset/assets_page.dart';
import 'widgets/asset/asset_dialogs.dart';
import 'widgets/common/section_title.dart';
import 'task/profit_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogoCacher.ensureInit();
  final info = await PackageInfo.fromPlatform();
  AppConfig.appVersion = info.version;

  L10n.deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final preferredLanguage = await SettingsService.getPreferredLanguage();
  L10n.applyLanguage(preferredLanguage);
  AppTheme.apply(await SettingsService.getThemeMode());
  AppColors.applyMarketColorPreference(
    await SettingsService.getRedUpGreenDown(),
  );

  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'profit-snapshot',
    'profitSnapshot',
    frequency: const Duration(minutes: 10),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.marketColorNotifier,
      builder: (context, redUpGreenDown, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppTheme.notifier,
          builder: (context, themeMode, _) {
            final effectiveBrightness = switch (AppTheme.mode) {
              ThemeMode.light => Brightness.light,
              ThemeMode.dark => Brightness.dark,
              ThemeMode.system =>
                WidgetsBinding.instance.platformDispatcher.platformBrightness,
            };
            AppColors.applyBrightness(effectiveBrightness);
            return ValueListenableBuilder<String>(
              valueListenable: L10n.notifier,
              builder: (context, lang, _) => MaterialApp(
                title: AppConfig.appName,
                debugShowCheckedModeBanner: false,
                locale: L10n.currentLocale,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: L10n.supportedLocales,
                theme: AppTheme.data(Brightness.light),
                darkTheme: AppTheme.data(Brightness.dark),
                themeMode: AppTheme.mode,
                home: const _AppShell(),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;
  final GlobalKey<StockPortfolioPageState> _stockKey = GlobalKey();
  final GlobalKey<AssetsPageState> _assetKey = GlobalKey();
  final PageController _pageController = PageController();
  String _selectedCurrency = AppConfig.defaultCurrency;
  double _stockTotalValue = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    final saved = await SettingsService.getDefaultCurrency();
    if (saved != null && mounted) {
      setState(() => _selectedCurrency = saved);
    }
  }

  void _syncStockTotalValue() {
    final v = _stockKey.currentState?.totalAssets;
    if (v != null) _stockTotalValue = v;
  }

  void _refreshHeader() {
    if (mounted) setState(() {});
  }

  String get _stockSubtitle =>
      _stockKey.currentState?.headerSubtitle ??
      StockConfig.homeSubtitleRefresh.replaceAll('{time}', '-');

  String get _assetSubtitle =>
      _assetKey.currentState?.headerSubtitle ??
      AssetConfig.assetSubtitleRefresh.replaceAll('{time}', '-');

  void _onAddTap() {
    switch (_currentIndex) {
      case 0:
        _stockKey.currentState?.showAddStockMenu();
      case 1:
        showAddAssetSheet(context).then((type) {
          if (type == null || !mounted) return;
          _assetKey.currentState?.onAddAsset(type);
        });
    }
  }

  void _onTabChanged(int index) {
    _syncStockTotalValue();
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppTheme.notifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: L10n.notifier,
          builder: (context, lang, _) => Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: AppColors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, _) => AnimatedHomeHeader(
                      page: _pageController.hasClients
                          ? (_pageController.page ?? _currentIndex.toDouble())
                          : _currentIndex.toDouble(),
                      stockTitle: StockConfig.homeTitle,
                      stockSubtitle: _stockSubtitle,
                      assetTitle: StockConfig.tabAsset,
                      assetSubtitle: _assetSubtitle,
                      onDividendOverview: () =>
                          _stockKey.currentState?.showDividendOverview(),
                      onBackup: () =>
                          _stockKey.currentState?.showBackupDialog(),
                      onSettings: () =>
                          _stockKey.currentState?.showSettingsPage(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        PageView(
                          controller: _pageController,
                          onPageChanged: (i) {
                            _syncStockTotalValue();
                            setState(() => _currentIndex = i);
                          },
                          children: [
                            StockPortfolioPage(
                              key: _stockKey,
                              selectedCurrency: _selectedCurrency,
                              onHeaderChanged: _refreshHeader,
                              onCurrencyChanged: (c) {
                                setState(() {
                                  _selectedCurrency = c;
                                  _stockTotalValue =
                                      _stockKey.currentState?.totalAssets ??
                                      _stockTotalValue;
                                });
                                SettingsService.setDefaultCurrency(c);
                              },
                            ),
                            AssetsPage(
                              key: _assetKey,
                              stockTotalValue: _stockTotalValue,
                              currency: _selectedCurrency,
                              onHeaderChanged: _refreshHeader,
                              onCurrencyChanged: (c) {
                                _stockKey.currentState?.setState(
                                  () =>
                                      _stockKey.currentState!.selectedCurrency =
                                          c,
                                );
                                setState(() {
                                  _selectedCurrency = c;
                                  _stockTotalValue =
                                      _stockKey.currentState?.totalAssets ??
                                      _stockTotalValue;
                                });
                                SettingsService.setDefaultCurrency(c);
                              },
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildBottomTabBar(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomTabBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(
                    icon: StockConfig.iconTabStock,
                    label: StockConfig.tabStock,
                    index: 0,
                  ),
                  const SizedBox(width: 4),
                  _buildTabItem(
                    icon: StockConfig.iconTabAsset,
                    label: StockConfig.tabAsset,
                    index: 1,
                  ),
                  const SizedBox(width: 4),
                  _buildAddItem(
                    icon: StockConfig.iconAdd,
                    label: AppConfig.btnAdd,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final selectedColor = index == 0 ? AppColors.accent : AppColors.warning;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: AppColors.isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: selectedColor.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? selectedColor : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItem({required IconData icon, required String label}) {
    return GestureDetector(
      onTap: _onAddTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
