import 'package:flutter/material.dart';
import '../../services/privacy_service.dart';

/// Never builds the original value or exposes it to accessibility while hidden.
class SensitiveText extends StatelessWidget {
  const SensitiveText(
    this.value, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String value;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: PrivacyService.instance.hideAmounts,
    builder: (context, hidden, _) => Text(
      hidden ? '••••' : value,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    ),
  );
}
