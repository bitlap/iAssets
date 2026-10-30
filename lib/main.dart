import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_config.dart';
import 'widgets/common/app_colors.dart';
import 'widgets/common/app_theme.dart';
import 'widgets/common/floating_bottom_bar.dart';
import 'l10n/l10n.dart';
import 'services/settings_service.dart';
import 'services/pro_service.dart';
import 'services/crypto/crypto_store.dart';
import 'services/exchange_rate_service.dart';
import 'utils/currency_util.dart';
import 'widgets/crypto/crypto_page.dart';
import 'utils/logo_cacher.dart';
import 'widgets/stock/stock_portfolio_page.dart';
import 'widgets/asset/assets_page.dart';
import 'widgets/asset/asset_dialogs.dart';
import 'widgets/common/section_title.dart';
import 'widgets/common/app_ui.dart';
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

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<StockPortfolioPageState> _stockKey = GlobalKey();
  final GlobalKey<AssetsPageState> _assetKey = GlobalKey();
  final GlobalKey<CryptoPageState> _cryptoKey = GlobalKey();
  final CryptoStore _crypto = CryptoStore.instance;
  Timer? _cryptoTimer;
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
    ProService.instance.addListener(_onProChanged);
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
    }
  }

  void _syncStockTotalValue() {
    final v = _stockKey.currentState?.totalAssets;
    if (v != null) _stockTotalValue = v;
  }

  void _refreshHeader() {
    _syncStockTotalValue();
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
  }

  void _onAddTap() {
    switch (_currentIndex) {
      case 0:
        _stockKey.currentState?.showAddStockMenu();
      case 1:
        _cryptoKey.currentState?.addConnection();
      case 2:
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
    WidgetsBinding.instance.removeObserver(this);
    _cryptoTimer?.cancel();
    _crypto.removeListener(_refreshHeader);
    ProService.instance.removeListener(_onProChanged);
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
