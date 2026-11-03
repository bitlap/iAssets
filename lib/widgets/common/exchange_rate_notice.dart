import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/exchange_rate_service.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// Shows the provenance of displayed FX valuations and flags incomplete totals.
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
            incomplete ||
            freshness == ExchangeRateFreshness.missing ||
            freshness == ExchangeRateFreshness.stale;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                warning ? Icons.warning_amber_rounded : Icons.currency_exchange,
                size: 13,
                color: warning ? AppColors.warning : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${L10n.t('exchangeRateStatus')}: $status · '
                  '${L10n.t('exchangeRateDate')}: $dateText'
                  '${incomplete ? ' · ${L10n.t('exchangeRateIncomplete')}' : ''}',
                  style: TextStyles.caption.copyWith(
                    color: warning
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
