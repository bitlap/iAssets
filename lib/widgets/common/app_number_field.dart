import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

/// 通用数字输入框 - 统一项目中所有数字输入框的样式
class AppNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final bool autoFocus;

  const AppNumberField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.autoFocus = false,
  });

  /// 统一的输入框装饰
  static InputDecoration _decoration(String hintText) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.textTertiary),
      ),
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.textTertiary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          style: TextStyles.inputText,
          decoration: _decoration(hintText),
        ),
      ],
    );
  }
}
