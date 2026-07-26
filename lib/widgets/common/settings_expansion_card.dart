import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

/// 设置页通用折叠卡片 - 统一设置页中所有 ExpansionTile 卡片的样式
class SettingsExpansionCard extends StatefulWidget {
  final Widget title;
  final Widget? trailing;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const SettingsExpansionCard({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<SettingsExpansionCard> createState() => _SettingsExpansionCardState();
}

class _SettingsExpansionCardState extends State<SettingsExpansionCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: widget.onExpansionChanged,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            title: widget.title,
            trailing: widget.trailing,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// 设置页可选列表项 - 用于 ExpansionTile 内的每一行
class SettingsSelectableItem extends StatelessWidget {
  final String label;
  final String? trailingText;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const SettingsSelectableItem({
    super.key,
    required this.label,
    this.trailingText,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: isSelected
                  ? const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.white,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyles.bodyMedium)),
            if (trailingText != null)
              Text(trailingText!, style: TextStyles.body13Grey),
          ],
        ),
      ),
    );
  }
}
