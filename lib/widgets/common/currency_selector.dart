import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../../services/exchange_rate_service.dart';
import 'app_ui.dart';

/// 通用货币选择浮动弹窗 - 与股票汇总卡片的样式一致
class CurrencySelector {
  static OverlayEntry? _entry;

  static void show({
    required BuildContext context,
    required String selectedCurrency,
    required ValueChanged<String> onCurrencyChanged,
    VoidCallback? onOpen,
  }) {
    onOpen?.call();
    _close();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dropdownWidth = screenWidth * 2 / 3;

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dropdownWidth,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              StockConfig.assetSelectCurrency,
                              style: TextStyles.bodyMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: _close,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(thickness: 0.5, color: AppColors.border),
                    Flexible(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: ExchangeRateService.supportedCurrencies.map((
                          currency,
                        ) {
                          final isSelected = currency == selectedCurrency;
                          final rate =
                              ExchangeRateService().effectiveRates[currency]!;
                          final symbol = CurrencyUtil.getSymbol(currency);
                          return InkWell(
                            onTap: () {
                              onCurrencyChanged(currency);
                              _close();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: AppColors.textPrimary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      currency,
                                      style: TextStyles.listTileTitle,
                                    ),
                                  ),
                                  Flexible(
                                    flex: 2,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '$symbol ${CurrencyUtil.formatRate(rate)}',
                                        style: TextStyles.body13Grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  static void _close() {
    _entry?.remove();
    _entry = null;
  }
}

/// 顶部汇总卡片共用的货币入口，与 CurrencySelector 浮层配合。
class CurrencySelectorButton extends StatelessWidget {
  final String currency;
  final VoidCallback onTap;
  const CurrencySelectorButton({
    super.key,
    required this.currency,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currency,
            style: TextStyles.body13.copyWith(
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textPrimary),
        ],
      ),
    ),
  );
}
