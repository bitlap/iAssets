import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_config.dart';
import 'config/app_colors.dart';
import 'utils/logo_cacher.dart';
import 'widgets/stock/stock_portfolio_page.dart';
import 'widgets/asset/assets_page.dart';
import 'widgets/asset/asset_dialogs.dart';
import 'task/profit_task.dart';
import 'widgets/common/app_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogoCacher.ensureInit();
  final info = await PackageInfo.fromPlatform();
  AppConfig.appVersion = info.version;

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale(
        AppConfig.defaultLocaleLanguage,
        AppConfig.defaultLocaleCountry,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.textTertiary,
          brightness: Brightness.dark,
          background: AppColors.surface,
          surface: AppColors.surfaceElevated,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          displayLarge: TextStyle(color: AppColors.textPrimary),
          headlineMedium: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      home: const _AppShell(),
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

  void _onAddTap() {
    switch (_currentIndex) {
      case 0:
        _stockKey.currentState?.showSearchStockDialog();
      case 1:
        showAddAssetSheet(context).then((type) {
          if (type == null || !mounted) return;
          _assetKey.currentState?.onAddAsset(type);
        });
    }
  }

  void _onTabChanged(int index) {
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              children: [
                StockPortfolioPage(key: _stockKey),
                AssetsPage(
                  key: _assetKey,
                  stockTotalValue: _stockKey.currentState?.totalAssets ?? 0,
                  currency:
                      _stockKey.currentState?.selectedCurrency ??
                      AppConfig.defaultCurrency,
                  onCurrencyChanged: (c) {
                    _stockKey.currentState?.setState(
                      () => _stockKey.currentState!.selectedCurrency = c,
                    );
                    setState(() {});
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
    );
  }

  Widget _buildBottomTabBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
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
          ],
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
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.tertiaryBg, width: 0.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: index == 0 ? AppColors.accent : AppColors.warning,
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
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyles.whiteBold11),
          ],
        ),
      ),
    );
  }
}
