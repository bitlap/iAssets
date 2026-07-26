import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

/// 通用删除确认弹窗 - 消除项目中所有删除确认弹窗的重复代码
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  /// 显示删除确认弹窗（便捷方法）
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.separator),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: TextStyles.dialogTitle),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.separator),
                          ),
                          child: const Center(
                            child: Text(
                              AppConfig.btnCancel,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.danger.withValues(alpha: 0.85),
                          ),
                          child: const Center(
                            child: Text(
                              AppConfig.btnDelete,
                              style: TextStyles.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((v) => v ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.separator),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyles.dialogTitle),
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.separator),
                        ),
                        child: const Center(
                          child: Text(
                            AppConfig.btnCancel,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        onConfirm();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.danger.withValues(alpha: 0.85),
                        ),
                        child: const Center(
                          child: Text(
                            AppConfig.btnDelete,
                            style: TextStyles.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
