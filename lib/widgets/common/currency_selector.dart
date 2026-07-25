import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../../services/exchange_rate_service.dart';

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
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dropdownWidth,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1C1C1E)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
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
                          Text(
                            StockConfig.assetSelectCurrency,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _close,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(thickness: 0.5, color: Color(0xFF1C1C1E)),
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
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      currency,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$symbol ${CurrencyUtil.formatRate(rate)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : Color(0xFF8E8E93),
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
