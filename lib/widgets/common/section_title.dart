import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onDividendOverview;
  final VoidCallback? onBackup;

  const SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.onAdd,
    this.onSettings,
    this.onDividendOverview,
    this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(title, style: TextStyles.headline)),
                    if (onDividendOverview != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDividendOverview,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payments_outlined,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyles.body13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBackup != null)
                GestureDetector(
                  onTap: onBackup,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.backup_outlined,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              if (onBackup != null && onSettings != null)
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
                    child: Icon(
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

/// 固定在 PageView 外层的首页标题栏。
///
/// 右侧操作按钮保持静止，左侧标题在同一位置根据页面滑动进度交叉淡入。
class AnimatedHomeHeader extends StatelessWidget {
  final double page;
  final String stockTitle;
  final String stockSubtitle;
  final String assetTitle;
  final String assetSubtitle;
  final VoidCallback onDividendOverview;
  final VoidCallback onBackup;
  final VoidCallback onSettings;

  const AnimatedHomeHeader({
    super.key,
    required this.page,
    required this.stockTitle,
    required this.stockSubtitle,
    required this.assetTitle,
    required this.assetSubtitle,
    required this.onDividendOverview,
    required this.onBackup,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final progress = page.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  _buildTitle(
                    title: stockTitle,
                    subtitle: stockSubtitle,
                    opacity: 1 - progress,
                    showDividend: true,
                  ),
                  _buildTitle(
                    title: assetTitle,
                    subtitle: assetSubtitle,
                    opacity: progress,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _circleButton(Icons.backup_outlined, onBackup),
              const SizedBox(width: 8),
              _circleButton(Icons.settings, onSettings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle({
    required String title,
    required String subtitle,
    required double opacity,
    bool showDividend = false,
  }) {
    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: opacity < 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyles.headline.copyWith(
                        fontSize: 22,
                        height: 1.2,
                      ),
                    ),
                    if (showDividend) ...[
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: opacity,
                        child: _circleButton(
                          Icons.payments_outlined,
                          onDividendOverview,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}
