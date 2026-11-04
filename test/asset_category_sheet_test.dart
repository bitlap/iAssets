import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/widgets/asset/asset_category_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom category can be created on a narrow English screen', (
    tester,
  ) async {
    L10n.applyLanguage(L10n.langEn);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      L10n.applyLanguage(L10n.langZh);
    });
    AssetCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showAssetCategorySheet(
                    context,
                    categories: AssetCategory.builtIns,
                    onCreate: (_) async => true,
                    onRename: (_, _) async => true,
                    onDelete: (_) async => true,
                  );
                },
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Custom Category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Property');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(selected?.customName, 'Property');
    expect(selected?.calculationType, AssetType.cash);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'US templates open by default and CN provident fund stays optional',
    (tester) async {
      final previousLocale = L10n.deviceLocale;
      L10n.deviceLocale = const Locale('en', 'US');
      L10n.applyLanguage(L10n.langEn);
      addTearDown(() {
        L10n.deviceLocale = previousLocale;
        L10n.applyLanguage(L10n.langZh);
      });
      AssetCategory? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showAssetCategorySheet(
                    context,
                    categories: AssetCategory.builtIns,
                    onCreate: (_) async => true,
                    onRename: (_, _) async => true,
                    onDelete: (_) async => true,
                  );
                },
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Investment Product'), findsOneWidget);
      expect(find.text('Provident Fund'), findsNothing);

      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      expect(find.text('United States'), findsOneWidget);
      expect(find.text('401(k) / IRA'), findsOneWidget);
      expect(find.text('Other Assets'), findsOneWidget);
      expect(find.text('Provident Fund'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mainland China').last);
      await tester.pumpAndSettle();
      expect(find.text('Provident Fund'), findsOneWidget);
      await tester.tap(find.text('Provident Fund'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'providentFund');
      expect(tester.takeException(), isNull);
    },
  );
}
