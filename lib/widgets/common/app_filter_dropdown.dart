import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_ui.dart';
import 'form_sheet.dart';

/// Shared selector for portfolio filters, including the nullable “all” option.
class AppFilterDropdown<T> extends StatefulWidget {
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
  State<AppFilterDropdown<T>> createState() => _AppFilterDropdownState<T>();
}

class _AppFilterDropdownState<T> extends State<AppFilterDropdown<T>> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = widget.items.any((item) => item.value == widget.value)
        ? widget.value
        : null;
    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: ButtonTheme.fromButtonThemeData(
        data: ButtonTheme.of(context).copyWith(alignedDropdown: true),
        child: DropdownButtonFormField<T>(
          key: ValueKey((selectedValue, widget.items.length)),
          initialValue: selectedValue,
          focusNode: _focusNode,
          decoration: appInputDecoration(),
          dropdownColor: AppColors.surface,
          style: TextStyles.body13,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          menuMaxHeight: MediaQuery.sizeOf(context).height * .45,
          iconEnabledColor: AppColors.textSecondary,
          items: widget.items,
          onChanged: (value) {
            _focusNode.unfocus();
            widget.onChanged(value);
          },
        ),
      ),
    );
  }
}
