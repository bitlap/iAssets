import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// Normalize decimal keyboards to the canonical numeric text parsed by forms.
class LocalizedDecimalInputFormatter extends TextInputFormatter {
  const LocalizedDecimalInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = String.fromCharCodes(
      newValue.text.runes.map((rune) {
        for (final zero in [0x0660, 0x06f0, 0x0966, 0x09e6, 0x0e50, 0xff10]) {
          if (rune >= zero && rune <= zero + 9) return rune - zero + 0x30;
        }
        return rune == 0x2c || rune == 0x066b ? 0x2e : rune;
      }),
    );
    return RegExp(r'^\d*\.?\d*$').hasMatch(normalized)
        ? newValue.copyWith(text: normalized)
        : oldValue;
  }
}

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
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.textTertiary),
      ),
      hintText: hintText,
      hintStyle: TextStyles.hintText.copyWith(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
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
            style: TextStyles.body13Bold.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [const LocalizedDecimalInputFormatter()],
          style: TextStyles.inputText,
          decoration: _decoration(hintText),
        ),
      ],
    );
  }
}
