import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';

class DraggableFab extends StatefulWidget {
  final VoidCallback onTap;
  final double maxHeight;

  const DraggableFab({super.key, required this.onTap, required this.maxHeight});

  @override
  State<DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<DraggableFab> {
  late double _fabY;
  bool _initialized = false;
  static const double _fabSize = 56.0;

  double get _maxTop => 20;
  double get _minTop => widget.maxHeight - _fabSize - 20;

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _fabY = (widget.maxHeight - _fabSize) / 2;
      _initialized = true;
    }
    _fabY = _fabY.clamp(_maxTop, _minTop);

    return Positioned(
      right: 16,
      top: _fabY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _fabY = (_fabY + details.delta.dy).clamp(_maxTop, _minTop);
          });
        },
        onTap: widget.onTap,
        child: Container(
          width: _fabSize,
          height: _fabSize,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
