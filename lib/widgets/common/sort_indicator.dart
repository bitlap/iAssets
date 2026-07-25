import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

class SortIndicator extends StatelessWidget {
  final bool isActive;
  final bool isAscending;
  final double size;
  final Color? activeColor;

  const SortIndicator({
    super.key,
    this.isActive = false,
    this.isAscending = false,
    this.size = 12,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: isActive
          ? Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: size,
              color: activeColor ?? Colors.white,
            )
          : null,
    );
  }
}
