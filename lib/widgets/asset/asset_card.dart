import 'package:flutter/material.dart';
import '../../config/asset_config.dart';
import '../common/app_colors.dart';
import '../common/app_ui.dart';
import 'asset_style.dart';

class AssetCardFrame extends StatelessWidget {
  final IconData icon;
  final String name;
  final String colorSeed;
  final String currency;
  final String amount;
  final String? detail;
  final Color? detailColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final Widget? leading;

  const AssetCardFrame({
    super.key,
    required this.icon,
    required this.name,
    required this.colorSeed,
    required this.currency,
    required this.amount,
    this.detail,
    this.detailColor,
    this.createdAt,
    this.updatedAt,
    required this.onTap,
    this.leading,
  });

  String _f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = AssetStyle.nameColor(colorSeed);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: AppColors.isDark ? .12 : .08),
          AppColors.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: ColoredBox(
              color: color.withValues(alpha: .65),
              child: const SizedBox(width: 3),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  leading ?? const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 17, color: color),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.subtitle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currency,
                                style: TextStyles.label.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              amount,
                              style: TextStyles.sectionTitle.copyWith(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (detail != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              detail!,
                              style: TextStyles.caption.copyWith(
                                color: detailColor ?? AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (createdAt != null || updatedAt != null) ...[
                            const SizedBox(height: 10),
                            Divider(
                              height: 1,
                              color: color.withValues(alpha: .14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (createdAt != null)
                                  Expanded(
                                    child: Text(
                                      AssetConfig.createdLabel.replaceAll(
                                        '{date}',
                                        _f(createdAt!),
                                      ),
                                      style: TextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                if (createdAt != null && updatedAt != null)
                                  const SizedBox(width: 12),
                                if (updatedAt != null)
                                  Expanded(
                                    child: Text(
                                      AssetConfig.updatedLabel.replaceAll(
                                        '{date}',
                                        _f(updatedAt!),
                                      ),
                                      style: TextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
