import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/utils/logo_cacher.dart';
import 'package:assets/utils/stock_logo_urls.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/widgets/stock/stock_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGP8z8Dwn4GBgYGJAQoAHxcCAk+Uzr4AAAAASUVORK5CYII=',
  );
  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('iassets-logos-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await LogoCacher.ensureInit();
  });
  tearDownAll(() => directory.deleteSync(recursive: true));

  test(
    'known CMB photos and old website images stay out of automatic logos',
    () async {
      for (final row in [
        ('600036', '沪A'),
        ('600036', 'A股'),
        ('03968', 'HK'),
        ('3968', '港股'),
      ]) {
        final oldKey = '${row.$2}:${row.$1}';
        await LogoCacher.cacheLocalImageBytes(oldKey, png);
        await LogoCacher.cacheLocalImageBytes('$oldKey:official-v1', png);
        final key = StockLogoUrls.cacheKey(row.$1, row.$2);
        expect(key, isNot(oldKey));
        expect(key, isNot('$oldKey:official-v1'));
        expect(LogoCacher.syncCached(key), isNull);
        expect(StockLogoUrls.forStock(row.$1, row.$2), isEmpty);
        var requests = 0;
        await http.runWithClient(
          () async {
            expect(await LogoCacher.getStockLogo(row.$1, row.$2), isNull);
            expect(requests, 0);
          },
          () => MockClient((_) async {
            requests++;
            return http.Response.bytes(png, 200);
          }),
        );
      }
      expect(StockLogoUrls.cacheKey('600519', '沪A'), '沪A:600519');
    },
  );

  test(
    'global tickers preserve exchange, leading zeroes and share classes',
    () {
      for (final row in [
        ('600519', '沪A', '600519.SS'),
        ('000001', '深A', '000001.SZ'),
        ('920002', '京A', '920002.BJ'),
        ('00700', 'HK', '0700.HK'),
        ('09988', '港股', '9988.HK'),
        ('80011', 'HK', '80011.HK'),
        ('7203', 'JPX', '7203.T'),
        ('005930', 'KRX', '005930.KS'),
        ('HSBA', 'LSE', 'HSBA.L'),
        ('BT.A', 'LSE', 'BT-A.L'),
        ('NSRGY', 'OTCBB', 'NSRGY'),
      ]) {
        expect(
          StockQuoteService.getLogoUrl(row.$1, row.$2),
          'https://images.financialmodelingprep.com/symbol/${row.$3}.png',
        );
      }
      expect(
        StockLogoUrls.forStock('247540', 'KRX').last,
        endsWith('/247540.KQ.png'),
      );
      expect(StockLogoUrls.forStock('brk.b', 'NYSE'), [
        'https://logos.stocktwits-cdn.com/BRK.B.png?w=64',
        'https://images.financialmodelingprep.com/symbol/BRK-B.png',
      ]);
      expect(
        StockQuoteService.getLogoUrl('600519', 'A股', secid: '1.600519'),
        endsWith('/600519.SS.png'),
      );
      for (final market in ['基金', '债券', '指数', '三板', '自定义', 'UNKNOWN']) {
        expect(StockLogoUrls.forStock('000001', market), isEmpty);
      }
      expect(StockLogoUrls.forStock('../AAPL', 'NASDAQ'), isEmpty);
      expect(StockLogoUrls.forStock('AAPL', 'HK'), isEmpty);
    },
  );

  test(
    'cache is isolated by market while repeated requests share one download',
    () async {
      final ready = Completer<void>();
      final finish = Completer<http.Response>();
      var requests = 0;
      final usKey = StockLogoUrls.cacheKey('AZN', 'NASDAQ');
      final ukKey = StockLogoUrls.cacheKey('AZN', 'LSE');
      await http.runWithClient(
        () async {
          final a = LogoCacher.getLogo(usKey, 'https://example.com/us.png');
          final b = LogoCacher.getLogo(usKey, 'https://example.com/us.png');
          await ready.future;
          finish.complete(http.Response.bytes(png, 200));
          final images = await Future.wait([a, b]);
          expect(images[0], isA<FileImage>());
          expect(images[1], same(images[0]));
          expect(requests, 1);
          expect(LogoCacher.syncCached(ukKey), isNull);
          expect(
            await LogoCacher.getLogo(usKey, 'https://example.com/us.png'),
            isA<FileImage>(),
          );
          expect(requests, 1);
        },
        () => MockClient((_) async {
          requests++;
          ready.complete();
          return finish.future;
        }),
      );
      await http.runWithClient(() async {
        final uk =
            await LogoCacher.getLogo(ukKey, 'https://example.com/uk.png')
                as FileImage;
        final us = LogoCacher.syncCached(usKey) as FileImage;
        expect(uk.file.path, isNot(us.file.path));
      }, () => MockClient((_) async => http.Response.bytes(png, 200)));
    },
  );

  test(
    'missing or corrupt images try the backup without caching HTML as an image',
    () async {
      final requested = <String>[];
      await http.runWithClient(
        () async {
          final image = await LogoCacher.getLogo(
            'BACKUP:TEST',
            'https://example.com/missing',
            fallbackUrls: [
              'https://example.com/html',
              'https://example.com/logo',
            ],
          );
          expect(image, isA<FileImage>());
          expect(requested, ['/missing', '/html', '/logo']);
          expect((image as FileImage).file.readAsBytesSync(), png);
        },
        () => MockClient((request) async {
          requested.add(request.url.path);
          return switch (request.url.path) {
            '/missing' => http.Response('', 404),
            '/html' => http.Response('<html>Error</html>', 200),
            _ => http.Response.bytes(png, 200),
          };
        }),
      );
    },
  );

  test(
    'an absent icon returns null and does not repeat failed network requests on rebuild',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < 3; i++) {
            expect(
              await LogoCacher.getLogo(
                'MISSING:TEST',
                'https://example.com/missing',
              ),
              isNull,
            );
          }
          expect(requests, 1);
          expect(LogoCacher.syncCached('MISSING:TEST'), isNull);
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('', 404);
        }),
      );
    },
  );

  test(
    'locally selected custom logos still use their existing identifier',
    () async {
      await LogoCacher.cacheLocalImageBytes('CUSTOM_test', png);
      final custom = LogoCacher.syncCached('CUSTOM_test') as FileImage;
      expect(custom.file.readAsBytesSync(), png);
      expect(
        LogoCacher.syncCached(StockLogoUrls.cacheKey('CUSTOM_test', '沪A')),
        isNull,
      );
    },
  );
  testWidgets(
    'existing holdings without a saved logo URL load market icons in both themes',
    (tester) async {
      final stock = StockModel(
        symbol: '7203',
        companyName: 'Toyota',
        currentPrice: 3000,
        shares: 1,
        totalValue: 3000,
        profitLossPercent: 0,
        profitLossAmount: 0,
        isPositive: true,
        marketType: 'JPX',
        secid: '176.7203',
      );
      expect(stock.logoUrl, isNull);
      var requests = 0;
      await http.runWithClient(
        () async {
          for (final brightness in Brightness.values) {
            await tester.runAsync(() async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: StockCard(
                      stock: stock,
                      isExpanded: false,
                      onExpandTap: () {},
                      onRecordTap: () {},
                      onMoreTap: () {},
                    ),
                  ),
                ),
              );
              // Join the download triggered by the widget; no fixed timing delay.
              await LogoCacher.getLogo(
                StockLogoUrls.cacheKey(stock.symbol, stock.marketType),
                StockLogoUrls.forStock(stock.symbol, stock.marketType).first,
              );
            });
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: find.byType(StockCard),
                matching: find.byType(Image),
              ),
              findsOneWidget,
            );
            final image = tester.widget<Image>(find.byType(Image));
            expect(image.image, isA<FileImage>());
            expect(tester.takeException(), isNull);
          }
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.path, '/symbol/7203.T.png');
          return http.Response.bytes(png, 200);
        }),
      );
    },
  );
  testWidgets('legacy US cache remains offline and separate from London', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LogoCacher.cacheLocalImageBytes('LEGACY', png);
      await LogoCacher.cacheLocalImageBytes(
        StockLogoUrls.cacheKey('LEGACY', 'LSE'),
        png,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final market in ['NYSE', 'LSE'])
                  StockCard(
                    stock: StockModel(
                      symbol: 'LEGACY',
                      companyName: market,
                      currentPrice: 1,
                      shares: 1,
                      totalValue: 1,
                      profitLossPercent: 0,
                      profitLossAmount: 0,
                      isPositive: true,
                      marketType: market,
                      secid: '${market == 'NYSE' ? '106' : '155'}.LEGACY',
                    ),
                    isExpanded: false,
                    onExpandTap: () {},
                    onRecordTap: () {},
                    onMoreTap: () {},
                  ),
              ],
            ),
          ),
        ),
      );
    });
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    final legacy = LogoCacher.syncCached('LEGACY') as FileImage;
    expect((images[0].image as FileImage).file.path, legacy.file.path);
    expect((images[1].image as FileImage).file.path, isNot(legacy.file.path));
    expect(tester.takeException(), isNull);
  });
  test(
    'Beijing image misses use text instead of fetching company websites',
    () async {
      const oldKey = '京A:920002';
      await LogoCacher.cacheLocalImageBytes(oldKey, png);
      final key = StockLogoUrls.cacheKey('920002', '京A');
      expect(key, isNot(oldKey));
      expect(LogoCacher.syncCached(key), isNull);
      var requests = 0;
      await http.runWithClient(
        () async {
          expect(await LogoCacher.getStockLogo('920002', '京A'), isNull);
          expect(await LogoCacher.getStockLogo('920002', '京A'), isNull);
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.host, 'images.financialmodelingprep.com');
          return http.Response('', 404);
        }),
      );
    },
  );
}
