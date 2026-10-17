import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// 股票与账户表单共用的底部弹窗，处理键盘、安全区域与固定标题。
class AppFormSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final Widget? action;
  final Color? backgroundColor;
  final bool closeButtonOnRight;
  const AppFormSheet({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.action,
    this.backgroundColor,
    this.closeButtonOnRight = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Material(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.separator,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (closeButtonOnRight)
                          action ?? const SizedBox(width: 48)
                        else
                          _closeButton(context),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyles.sectionTitle,
                          ),
                        ),
                        if (closeButtonOnRight)
                          _closeButton(context)
                        else
                          action ?? const SizedBox(width: 48),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _closeButton(BuildContext context) => IconButton(
    onPressed: onClose,
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    icon: Icon(Icons.close, color: AppColors.textSecondary),
  );
}

/// 复用股票表单的圆角输入框及语义颜色。
InputDecoration appInputDecoration({
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.border),
  );
  return InputDecoration(
    labelText: labelText,
    labelStyle: TextStyles.body13Grey,
    hintText: hintText,
    hintStyle: TextStyles.hintText,
    prefixIcon: prefixIcon,
    prefixIconColor: AppColors.textSecondary,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.accent),
    ),
  );
}
