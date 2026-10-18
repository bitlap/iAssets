import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_ui.dart';
import 'form_sheet.dart';

/// Shared selector for portfolio filters, including the nullable “all” option.
class AppFilterDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const AppFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = items.any((item) => item.value == value)
        ? value
        : null;
    return ButtonTheme.fromButtonThemeData(
      data: ButtonTheme.of(context).copyWith(alignedDropdown: true),
      child: DropdownButtonFormField<T>(
        key: ValueKey((selectedValue, items.length)),
        initialValue: selectedValue,
        decoration: appInputDecoration(),
        dropdownColor: AppColors.surface,
        style: TextStyles.body13,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: MediaQuery.sizeOf(context).height * .45,
        iconEnabledColor: AppColors.textSecondary,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
