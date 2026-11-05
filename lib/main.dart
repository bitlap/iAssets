import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_config.dart';
import 'widgets/common/app_colors.dart';
import 'widgets/common/app_theme.dart';
import 'widgets/common/floating_bottom_bar.dart';
import 'l10n/l10n.dart';
import 'services/settings_service.dart';
import 'services/privacy_service.dart';
import 'services/widget_snapshot_service.dart';
import 'services/asset_data_manager.dart';
import 'services/stock_data_manager.dart';
import 'services/pro_service.dart';
import 'services/crypto/crypto_store.dart';
import 'services/exchange_rate_service.dart';
import 'utils/currency_util.dart';
import 'utils/asset_calculator.dart';
import 'widgets/crypto/crypto_page.dart';
import 'utils/logo_cacher.dart';
import 'widgets/stock/stock_portfolio_page.dart';
import 'widgets/asset/assets_page.dart';
import 'widgets/common/section_title.dart';
import 'widgets/common/app_ui.dart';
import 'widgets/common/privacy_gate.dart';
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
    await SettingsService.getRedUpGreenDown(deviceLocale: L10n.deviceLocale),
  );
  await PrivacyService.instance.initialize();

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

  unawaited(ProService.instance.initialize());
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
  void didChangeLocales(List<Locale>? locales) {
    if (locales == null || locales.isEmpty) return;
    L10n.deviceLocale = locales.first;
    if (L10n.followSystem) L10n.applyLanguage(L10n.langSystem);
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
                builder: (context, child) =>
                    PrivacyGate(child: child ?? const SizedBox.shrink()),
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

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  static const _widgetNavigation = MethodChannel(
    'org.bitlap.assets/widget-navigation',
  );
  int _currentIndex = 0;
  final GlobalKey<StockPortfolioPageState> _stockKey = GlobalKey();
  final GlobalKey<AssetsPageState> _assetKey = GlobalKey();
  final GlobalKey<CryptoPageState> _cryptoKey = GlobalKey();
  final CryptoStore _crypto = CryptoStore.instance;
  Timer? _cryptoTimer;
  Timer? _widgetSnapshotTimer;
  int _widgetSnapshotGeneration = 0;
  bool _foreground = true;
  final PageController _pageController = PageController();
  String _selectedCurrency = AppConfig.defaultCurrency;
  double _stockTotalValue = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrency();
    WidgetsBinding.instance.addObserver(this);
    _crypto.addListener(_refreshHeader);
    ExchangeRateService().addListener(_refreshHeader);
    ProService.instance.addListener(_onProChanged);
    PrivacyService.instance.hideAmounts.addListener(_scheduleWidgetSnapshot);
    PrivacyService.instance.biometricLock.addListener(_scheduleWidgetSnapshot);
    L10n.notifier.addListener(_scheduleWidgetSnapshot);
    _widgetNavigation.setMethodCallHandler((call) async {
      if (call.method == 'openDestination' && call.arguments == 'assets') {
        _openAssetsFromWidget();
      }
    });
    unawaited(_consumeWidgetDestination());
    unawaited(_refreshCrypto());
    _cryptoTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_foreground) unawaited(_refreshCrypto());
    });
  }

  void _onProChanged() {
    _refreshHeader();
    if (ProService.instance.isPro) unawaited(_refreshCrypto());
  }

  Future<void> _refreshCrypto() async {
    if (!ProService.instance.isPro) return;
    await _crypto.refresh();
    await ExchangeRateService().fetchRates();
    _refreshHeader();
    await _publishWidgetSnapshotNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(ProService.instance.refresh());
      unawaited(_refreshCrypto());
    }
  }

  Future<void> _loadDefaultCurrency() async {
    final saved = await SettingsService.getDefaultCurrency();
    if (saved != null && mounted) {
      setState(() => _selectedCurrency = saved);
      _scheduleWidgetSnapshot();
    }
  }

  void _scheduleWidgetSnapshot() {
    final generation = ++_widgetSnapshotGeneration;
    _widgetSnapshotTimer?.cancel();
    _widgetSnapshotTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_publishWidgetSnapshot(generation));
    });
  }

  Future<void> _publishWidgetSnapshotNow() async {
    final generation = ++_widgetSnapshotGeneration;
    _widgetSnapshotTimer?.cancel();
    await _publishWidgetSnapshot(generation);
  }

  Future<void> _consumeWidgetDestination() async {
    try {
      final destination = await _widgetNavigation.invokeMethod<String>(
        'consumePendingDestination',
      );
      if (destination == 'assets') _openAssetsFromWidget();
    } on MissingPluginException {
      // No native widget navigation on non-iOS platforms.
    }
  }

  void _openAssetsFromWidget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onTabChanged(2);
    });
  }

  Future<void> _publishWidgetSnapshot(int generation) async {
    // Read the Keychain connection list before a temporary Free result can
    // replace a previously verified crypto balance with zero.
    await _crypto.initialize();
    if (!mounted || generation != _widgetSnapshotGeneration) return;
    final pro = ProService.instance;
    if (!WidgetSnapshotService.isPortfolioReady(
      entitlementLoading: pro.loading,
      entitlementFailed: pro.error != null,
      isPro: pro.isPro,
      cryptoInitialized: _crypto.initialized,
      cryptoSyncing: _crypto.syncing,
      cryptoConnectionCount: _crypto.connections.length,
      cryptoSnapshotCount: _crypto.connections
          .where((connection) => _crypto.snapshot(connection.id) != null)
          .length,
    )) {
      return;
    }
    try {
      final stock = _stockKey.currentState;
      late final double stocks;
      late final DateTime stockUpdatedAt;
      if (stock != null && stock.isLoaded && stock.lastRefreshedAt != null) {
        stocks = stock.totalAssets;
        stockUpdatedAt = stock.lastRefreshedAt!;
      } else {
        // The PageView may not have built the stock tab when a widget opens
        // directly into Assets. Read the same saved portfolio independently.
        final (holdings, operations, dividends) =
            await StockDataManager.loadStocks();
        if (!mounted || generation != _widgetSnapshotGeneration) return;
        stocks = StockDataManager.calculateAssetSummary(
          holdings,
          operations,
          dividends,
          _selectedCurrency,
        ).totalAssets;
        stockUpdatedAt = DateTime.now();
      }
      final (assets, _, _) = await AssetDataManager.loadCategoryState();
      if (!mounted || generation != _widgetSnapshotGeneration) return;
      final other = AssetCalculator.calculateTotalAssets(
        assets,
        0,
        _selectedCurrency,
      );
      final crypto = CurrencyUtil.convertCurrency(
        pro.isPro ? _crypto.totalUsd.toDouble() : 0,
        'USD',
        _selectedCurrency,
      );
      final dates = <DateTime>[
        stockUpdatedAt,
        if (pro.isPro &&
            _crypto.connections.isNotEmpty &&
            _crypto.oldestUpdate != null)
          _crypto.oldestUpdate!,
      ]..sort();
      await WidgetSnapshotService.publish(
        total: stocks + crypto + other,
        stocks: stocks,
        crypto: crypto,
        other: other,
        currency: _selectedCurrency,
        updatedAt: dates.first,
        incomplete: pro.isPro && _crypto.incomplete,
      );
    } catch (error) {
      // A failed local/iCloud read must never publish a misleading zero total.
      debugPrint('[WidgetSnapshot] Could not publish: $error');
    }
  }

  void _syncStockTotalValue() {
    final v = _stockKey.currentState?.totalAssets;
    if (v != null) _stockTotalValue = v;
  }

  void _refreshHeader() {
    _syncStockTotalValue();
    _scheduleWidgetSnapshot();
    if (mounted) setState(() {});
  }

  String get _stockSubtitle =>
      _stockKey.currentState?.headerSubtitle ??
      StockConfig.homeSubtitleRefresh.replaceAll('{time}', '-');

  String get _cryptoSubtitle => StockConfig.homeSubtitleRefresh.replaceAll(
    '{time}',
    _crypto.oldestUpdate == null
        ? '-'
        : formatRefreshTime(_crypto.oldestUpdate!),
  );

  String get _assetSubtitle =>
      _assetKey.currentState?.headerSubtitle ??
      AssetConfig.assetSubtitleRefresh.replaceAll('{time}', '-');

  void _changeCurrency(String currency) {
    final stock = _stockKey.currentState;
    if (stock != null) stock.setState(() => stock.selectedCurrency = currency);
    setState(() {
      _selectedCurrency = currency;
      _syncStockTotalValue();
    });
    SettingsService.setDefaultCurrency(currency);
    _scheduleWidgetSnapshot();
  }

  void _onAddTap() {
    switch (_currentIndex) {
      case 0:
        _stockKey.currentState?.showAddStockMenu();
      case 1:
        _cryptoKey.currentState?.addConnection();
      case 2:
        _assetKey.currentState?.showAddAssetPicker();
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
    WidgetsBinding.instance.removeObserver(this);
    _cryptoTimer?.cancel();
    _widgetSnapshotTimer?.cancel();
    _crypto.removeListener(_refreshHeader);
    ExchangeRateService().removeListener(_refreshHeader);
    ProService.instance.removeListener(_onProChanged);
    PrivacyService.instance.hideAmounts.removeListener(_scheduleWidgetSnapshot);
    PrivacyService.instance.biometricLock.removeListener(
      _scheduleWidgetSnapshot,
    );
    L10n.notifier.removeListener(_scheduleWidgetSnapshot);
    _widgetNavigation.setMethodCallHandler(null);
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
                      cryptoTitle: L10n.t('cryptoTitle'),
                      cryptoSubtitle: _cryptoSubtitle,
                      assetTitle: StockConfig.tabAsset,
                      assetSubtitle: _assetSubtitle,
                      onDividendOverview: () =>
                          _stockKey.currentState?.showDividendOverview(),
                      onBackup: () =>
                          _stockKey.currentState?.showBackupDialog(),
                      onSettings: () =>
                          _stockKey.currentState?.showSettingsPage(),
                      onPrivacy: () async {
                        final service = PrivacyService.instance;
                        try {
                          await service.setHideAmounts(
                            !service.hideAmounts.value,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(L10n.t('privacySaveFailed')),
                              ),
                            );
                          }
                        }
                      },
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
                              onCurrencyChanged: _changeCurrency,
                            ),
                            CryptoPage(
                              key: _cryptoKey,
                              store: _crypto,
                              currency: _selectedCurrency,
                              onCurrencyChanged: _changeCurrency,
                              onRefresh: _refreshCrypto,
                            ),
                            AssetsPage(
                              key: _assetKey,
                              stockTotalValue: _stockTotalValue,
                              cryptoTotalValue: CurrencyUtil.convertCurrency(
                                ProService.instance.isPro
                                    ? _crypto.totalUsd.toDouble()
                                    : 0,
                                'USD',
                                _selectedCurrency,
                              ),
                              cryptoIncomplete:
                                  ProService.instance.isPro &&
                                  _crypto.incomplete,
                              cryptoUpdatedAt: ProService.instance.isPro
                                  ? _crypto.oldestUpdate
                                  : null,
                              onRefreshCrypto: ProService.instance.isPro
                                  ? () => _refreshCrypto()
                                  : null,
                              currency: _selectedCurrency,
                              onHeaderChanged: _refreshHeader,
                              onCurrencyChanged: _changeCurrency,
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

  Widget _buildBottomTabBar() => FloatingBottomBar(
    selectedIndex: _currentIndex,
    labels: [
      StockConfig.tabStock,
      L10n.t('cryptoTitle'),
      StockConfig.tabAsset,
      AppConfig.btnAdd,
    ],
    onSelected: _onTabChanged,
    onAdd: _onAddTap,
  );
}
