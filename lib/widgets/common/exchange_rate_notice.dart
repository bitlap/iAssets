import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/exchange_rate_service.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// 展示汇率估值的数据来源，并标记无法完整估值的总额。
class ExchangeRateNotice extends StatelessWidget {
  final bool incomplete;

  const ExchangeRateNotice({super.key, this.incomplete = false});

  @override
  Widget build(BuildContext context) {
    final service = ExchangeRateService();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final freshness = service.freshness;
        final status = switch (freshness) {
          ExchangeRateFreshness.live => L10n.t('exchangeRateLive'),
          ExchangeRateFreshness.cached => L10n.t('exchangeRateCached'),
          ExchangeRateFreshness.stale => L10n.t('exchangeRateStale'),
          ExchangeRateFreshness.missing => L10n.t('exchangeRateMissing'),
        };
        final date = service.lastUpdatedAt;
        final dateText = date == null
            ? L10n.t('exchangeRateDateUnknown')
            : '${date.year.toString().padLeft(4, '0')}-'
                  '${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}';
        final warning =
            freshness == ExchangeRateFreshness.missing ||
            freshness == ExchangeRateFreshness.stale;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: .5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  Icon(
                    warning
                        ? Icons.warning_amber_rounded
                        : Icons.currency_exchange,
                    size: 13,
                    color: warning
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  Text(
                    '${L10n.t('exchangeRateStatus')}: $status',
                    style: TextStyles.caption.copyWith(
                      color: warning
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (date != null) ...[
                    Text(
                      dateText,
                      semanticsLabel:
                          '${L10n.t('exchangeRateDate')}: $dateText',
                      style: TextStyles.caption,
                    ),
                  ],
                ],
              ),
              if (incomplete) ...[
                const SizedBox(height: 4),
                Text(
                  L10n.t('exchangeRateIncomplete'),
                  textAlign: TextAlign.center,
                  style: TextStyles.caption.copyWith(color: AppColors.warning),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
