import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_filter_dropdown.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('reselecting all releases dropdown focus in $brightness', (
      tester,
    ) async {
      AppColors.applyBrightness(brightness);
      String? value;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(brightness).copyWith(
            textTheme: AppTheme.data(brightness).textTheme.apply(
              fontFamily: 'ReviewFont',
              fontFamilyFallback: ['ReviewCJK'],
            ),
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  AppFilterDropdown<String>(
                    value: value,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部')),
                      DropdownMenuItem(value: 'us', child: Text('美股')),
                    ],
                    onChanged: (next) => setState(() => value = next),
                  ),
                  const SizedBox(height: 100),
                  const Text('其他区域'),
                ],
              ),
            ),
          ),
        ),
      );
      final field = find.byType(DropdownButtonFormField<String>);
      final button = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: field,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(button.style!.fontFamily, 'ReviewFont');
      expect(button.style!.fontFamilyFallback, ['ReviewCJK']);
      FocusNode focus() => tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: field,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .focusNode!;
      for (var i = 0; i < 2; i++) {
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text('全部').last);
        await tester.pumpAndSettle();
        expect(value, isNull);
        expect(focus().hasFocus, isFalse);
        expect(
          tester
              .widget<InputDecorator>(
                find.descendant(
                  of: field,
                  matching: find.byType(InputDecorator),
                ),
              )
              .isFocused,
          isFalse,
        );
      }
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('美股').last);
      await tester.pumpAndSettle();
      expect(value, 'us');
      expect(focus().hasFocus, isFalse);
      // Outside taps also dismiss focus acquired through keyboard navigation.
      focus().requestFocus();
      await tester.pump();
      expect(focus().hasFocus, isTrue);
      await tester.tap(find.text('其他区域'));
      await tester.pumpAndSettle();
      expect(focus().hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
