import 'package:flutter/material.dart';
import '../../config/asset_config.dart';
import '../../config/app_colors.dart';
import '../common/app_ui.dart';

class AssetCardFrame extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Widget trailing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? leading;

  const AssetCardFrame({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.name,
    this.createdAt,
    this.updatedAt,
    required this.trailing,
    required this.onTap,
    required this.onLongPress,
    this.leading,
  });

  String _f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _timestamps(DateTime? c, DateTime? u) {
    return SizedBox(
      height: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (c != null)
            Text(
              AssetConfig.createdLabel.replaceAll('{date}', _f(c)),
              style: TextStyles.label.copyWith(color: AppColors.textTertiary),
            ),
          if (c != null && u != null) const SizedBox(height: 2),
          if (u != null)
            Text(
              AssetConfig.updatedLabel.replaceAll('{date}', _f(u)),
              style: TextStyles.label.copyWith(color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              leading ?? const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyles.subtitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _timestamps(createdAt, updatedAt),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: trailing),
            ],
          ),
        ),
      ),
    );
  }
}
