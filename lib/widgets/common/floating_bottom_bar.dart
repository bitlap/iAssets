import 'dart:ui';

import 'package:flutter/material.dart';

/// Three page tabs in a floating capsule with a separate circular add action.
class FloatingBottomBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  const FloatingBottomBar({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.onSelected,
    required this.onAdd,
  }) : assert(labels.length == 4),
       assert(selectedIndex >= 0 && selectedIndex < 3);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFF5B9CF6) : const Color(0xFF007AFF);
    final foreground = dark ? const Color(0xFFF5F5F7) : const Color(0xFF19191B);
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
    );
    const icons = [
      Icons.show_chart_rounded,
      Icons.currency_bitcoin_rounded,
      Icons.account_balance_wallet_rounded,
    ];

    Widget glass(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .32 : .09),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (dark ? const Color(0xFF232326) : Colors.white).withValues(
                alpha: .86,
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? .12 : .8),
                width: .75,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: glass(
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedAlign(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            alignment: AlignmentDirectional(
                              -1 + selectedIndex.toDouble(),
                              0,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 1 / 3,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF3B3B40)
                                      : const Color(0xFFEDEDEE),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(3, (index) {
                            final selected = index == selectedIndex;
                            final color = selected ? accent : foreground;
                            return Expanded(
                              child: Semantics(
                                button: true,
                                selected: selected,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(100),
                                    onTap: () => onSelected(index),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 5,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              icons[index],
                                              size: 24,
                                              color: color,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              labels[index],
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                height: 1.2,
                                                letterSpacing: 0,
                                                fontWeight: FontWeight.w600,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              glass(
                SizedBox.square(
                  dimension: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      tooltip: labels[3],
                      onPressed: onAdd,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
