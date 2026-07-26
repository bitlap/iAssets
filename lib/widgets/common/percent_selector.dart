import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

Widget buildPercentSelector(
  BuildContext context,
  double selected,
  ValueChanged<double> onChanged,
) {
  final values = List.generate(21, (i) => i * 5.0);
  return Builder(
    builder: (btnCtx) {
      return GestureDetector(
        onTap: () async {
          final RenderBox button = btnCtx.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final result = await showMenu<double>(
            context: context,
            position: RelativeRect.fromRect(
              button.localToGlobal(Offset.zero, ancestor: overlay) &
                  button.size,
              Offset.zero & overlay.size,
            ),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            items: values.map((v) {
              final isSel = v == selected;
              return PopupMenuItem<double>(
                value: v,
                height: 36,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: isSel
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${v.toInt()}%',
                      style: TextStyles.body13.copyWith(
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
          if (result != null) onChanged(result);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${selected.toInt()}%', style: TextStyles.bodyMedium),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      );
    },
  );
}
