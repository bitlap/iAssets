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
          child: Text(label, style: TextStyles.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
