import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

/// 通用信息行组件 - 左侧标签 + 右侧值，用于弹窗中的信息展示
class InfoRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const InfoRowWidget({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 70,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
