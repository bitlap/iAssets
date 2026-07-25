import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onDividendOverview;

  const SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.onAdd,
    this.onSettings,
    this.onDividendOverview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyles.headline),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDividendOverview != null)
                GestureDetector(
                  onTap: onDividendOverview,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              if (onDividendOverview != null && onSettings != null)
                const SizedBox(width: 8),
              if (onSettings != null)
                GestureDetector(
                  onTap: onSettings,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
