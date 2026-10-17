import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:assets/models/crypto/crypto_models.dart';
import 'package:assets/services/crypto/exchange_client.dart';

ExchangeConnection key(CryptoExchange exchange) => ExchangeConnection(
  id: 'a',
  exchange: exchange,
  name: 'test',
  apiKey: 'fake-key',
  secret: 'fake-secret',
  passphrase: 'fake-pass',
);
http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
void main() {
  test(
    'Spot lead reads all free plus locked balances and makes no Futures calls',
    () async {
      final paths = <String>[];
      final client = ExchangeClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return switch (request.url.path) {
            '/api/v3/account' => json({
              'uid': 'spot-project-A',
              'balances': [
                {'asset': 'BTC', 'free': '.1', 'locked': '.025'},
                {'asset': 'USDT', 'free': '100', 'locked': '0'},
                {'asset': 'ZERO', 'free': '0', 'locked': '0'},
              ],
            }),
            '/sapi/v1/account/apiRestrictions' => json({
              'enableReading': true,
              'enableSpotAndMarginTrading': false,
            }),
            '/v2/exchange-rates' => json({
              'data': {
                'rates': {'USDT': '2'},
              },
            }),
            '/api/v3/ticker/price' => json([
              {'symbol': 'BTCUSDT', 'price': '60000'},
            ]),
            _ => throw StateError('Unexpected request'),
          };
        }),
      );
      final snapshot = await client.read(
        const ExchangeConnection(
          id: 'spot-lead',
          name: 'Spot Lead',
          exchange: CryptoExchange.binance,
          role: CryptoAccountRole.lead,
          leadMarket: CryptoLeadMarket.spot,
          apiKey: 'fake-key',
          secret: 'fake-secret',
        ),
      );
      expect(snapshot.accountId, 'spot:spot-project-A');
      expect(snapshot.balances.length, 2);
      expect(snapshot.balances.first.quantity, amount('.125'));
      expect(snapshot.balances.first.available, amount('.1'));
      expect(snapshot.balances.first.frozen, amount('.025'));
      expect(
        snapshot.totalUsd,
        amount('3800'),
      ); // .125 BTC * $30000 + 100 USDT * $0.50.
      expect(snapshot.positions, isEmpty);
      expect(snapshot.wallets.single.unrealizedPnl, isNull);
      expect(snapshot.wallets.single.kind, CryptoWalletKind.lead);
      expect(snapshot.notices, isNot(contains('leadTradingPermission')));
      expect(snapshot.complete, true);
      expect(
        paths.any((p) => p.startsWith('/fapi') || p.startsWith('/dapi')),
        false,
      );
    },
  );
  test(
    'Spot lead preserves unknown-price holdings and marks valuation incomplete',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => switch (request.url.path) {
            '/api/v3/account' => json({
              'uid': 'spot-A',
              'balances': [
                {'asset': 'UNKNOWN', 'free': '1', 'locked': '2'},
              ],
            }),
            '/sapi/v1/account/apiRestrictions' => json({'enableReading': true}),
            '/api/v3/ticker/price' => json([]),
            _ => json({
              'data': {'rates': {}},
            }),
          },
        ),
      );
      final snapshot = await client.read(
        const ExchangeConnection(
          id: 'spot',
          name: 'Spot',
          exchange: CryptoExchange.binance,
          role: CryptoAccountRole.lead,
          leadMarket: CryptoLeadMarket.spot,
          apiKey: 'fake-key',
          secret: 'fake-secret',
        ),
      );
      expect(snapshot.balances.single.quantity, amount('3'));
      expect(snapshot.balances.single.priceUsd, isNull);
      expect(snapshot.complete, false);
      expect(snapshot.notices, isNot(contains('permissionUnverified')));
    },
  );
  test(
    'Spot lead never substitutes API-key identity for missing account UID',
    () async {
      final client = ExchangeClient(
        client: MockClient((request) async => json({'balances': []})),
      );
      await expectLater(
        client.read(
          const ExchangeConnection(
            id: 'spot',
            name: 'Spot',
            exchange: CryptoExchange.binance,
            role: CryptoAccountRole.lead,
            leadMarket: CryptoLeadMarket.spot,
            apiKey: 'fake-key',
            secret: 'fake-secret',
          ),
        ),
        throwsA(
          isA<CryptoSyncException>().having((e) => e.code, 'code', 'response'),
        ),
      );
    },
  );

  test(
    'Binance lead key reads its portfolio equity and PnL without Spot or COIN-M',
    () async {
      final requested = <String>[];
      final client = ExchangeClient(
        client: MockClient((request) async {
          requested.add(request.url.path);
          return switch (request.url.path) {
            '/fapi/v2/account' => json({
              'totalWalletBalance': '1000',
              'totalUnrealizedProfit': '50',
              'totalMarginBalance': '1050',
              'availableBalance': '800',
            }),
            '/fapi/v2/balance' => json([
              {'asset': 'USDT', 'accountAlias': 'portfolio-A'},
            ]),
            '/fapi/v2/positionRisk' => json([
              {
                'symbol': 'BTCUSDT',
                'positionSide': 'BOTH',
                'positionAmt': '.1',
                'markPrice': '65000',
                'unRealizedProfit': '50',
              },
            ]),
            '/sapi/v1/account/apiRestrictions' => json({'enableReading': true}),
            '/v2/exchange-rates' => json({
              'data': {
                'rates': {'USDT': '2'},
              },
            }),
            _ => throw StateError('Unexpected API'),
          };
        }),
      );
      final result = await client.read(
        const ExchangeConnection(
          id: 'lead',
          name: 'Lead',
          exchange: CryptoExchange.binance,
          role: CryptoAccountRole.lead,
          apiKey: 'key',
          secret: 'secret',
        ),
      );
      expect(result.accountId, 'usdm:portfolio-A');
      expect(
        result.totalUsd,
        amount('525'),
      ); // USDT quote is intentionally $0.50, not hardcoded $1.
      expect(result.wallets.single.walletBalance, amount('1000'));
      expect(result.wallets.single.unrealizedPnl, amount('50'));
      expect(result.notices, isNot(contains('permissionUnverified')));
      expect(result.positions.single.isLong, true);
      expect(requested, isNot(contains('/api/v3/account')));
      expect(requested, isNot(contains('/dapi/v1/account')));
    },
  );
  for (final market in CryptoLeadMarket.values) {
    for (final unverified in [false, true]) {
      test(
        'lead $market ${unverified ? "rejects unverifiable permissions" : "allows trading permissions with a risk notice"}',
        () async {
          final client = ExchangeClient(
            client: MockClient((request) async {
              return switch (request.url.path) {
                '/api/v3/account' => json({'uid': 'portfolio', 'balances': []}),
                '/fapi/v2/account' => json({
                  'totalWalletBalance': '0',
                  'totalUnrealizedProfit': '0',
                  'totalMarginBalance': '0',
                }),
                '/fapi/v2/balance' => json([
                  {'asset': 'USDT', 'accountAlias': 'portfolio'},
                ]),
                '/sapi/v1/account/apiRestrictions' =>
                  unverified
                      ? json({'code': -2015}, 401)
                      : json({
                          'enableReading': true,
                          market == CryptoLeadMarket.spot
                                  ? 'enableSpotAndMarginTrading'
                                  : 'enableFutures':
                              true,
                        }),
                '/fapi/v2/positionRisk' => json([]),
                '/api/v3/ticker/price' => json([]),
                '/v2/exchange-rates' => json({
                  'data': {
                    'rates': {'USDT': '1'},
                  },
                }),
                _ => throw StateError('Unexpected request'),
              };
            }),
          );
          final result = client.read(
            ExchangeConnection(
              id: 'lead',
              name: 'Lead',
              exchange: CryptoExchange.binance,
              role: CryptoAccountRole.lead,
              leadMarket: market,
              apiKey: 'fake-key',
              secret: 'fake-secret',
            ),
          );
          if (unverified) {
            await expectLater(
              result,
              throwsA(
                isA<CryptoSyncException>().having(
                  (e) => e.code,
                  'code',
                  'permissionUnverified',
                ),
              ),
            );
          } else {
            final snapshot = await result;
            expect(snapshot.notices, contains('tradingPermission'));
            expect(snapshot.totalUsd, amount('0'));
          }
        },
      );
    }
  }
  test(
    'Binance lead keys with unrelated write permissions remain rejected',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => switch (request.url.path) {
            '/fapi/v2/account' => json({
              'totalWalletBalance': '0',
              'totalUnrealizedProfit': '0',
              'totalMarginBalance': '0',
            }),
            '/fapi/v2/balance' => json([
              {'asset': 'USDT', 'accountAlias': 'portfolio-A'},
            ]),
            _ => json({'enableReading': true, 'enableWithdrawals': true}),
          },
        ),
      );
      await expectLater(
        client.read(
          const ExchangeConnection(
            id: 'lead',
            name: 'Lead',
            exchange: CryptoExchange.binance,
            role: CryptoAccountRole.lead,
            apiKey: 'key',
            secret: 'secret',
          ),
        ),
        throwsA(
          isA<CryptoSyncException>().having((e) => e.code, 'code', 'readOnly'),
        ),
      );
    },
  );
  test(
    'Binance follower remains explicitly unsupported without querying main-account assets',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => throw StateError('must not query'),
        ),
      );
      await expectLater(
        client.read(
          const ExchangeConnection(
            id: 'copy',
            name: 'Copy',
            exchange: CryptoExchange.binance,
            role: CryptoAccountRole.copy,
            apiKey: 'key',
            secret: 'secret',
          ),
        ),
        throwsA(
          isA<CryptoSyncException>().having(
            (e) => e.code,
            'code',
            'copyUnsupported',
          ),
        ),
      );
    },
  );

  test(
    'OKX signs exact request path using a millisecond UTC timestamp',
    () async {
      final client = ExchangeClient(
        clock: () => DateTime.utc(2026, 10, 17, 12, 0, 0, 123, 456),
        client: MockClient((request) async {
          expect(
            request.headers['OK-ACCESS-TIMESTAMP'],
            '2026-10-17T12:00:00.123Z',
          );
          expect(
            request.headers['OK-ACCESS-SIGN'],
            'EeEPUZGs2pm2wFilmUNOQhHKvRab42SO54QSkFHZq4k=',
          );
          expect(request.followRedirects, false);
          return json({'code': '0', 'data': []});
        }),
      );
      await client.okx(key(CryptoExchange.okx), '/api/v5/account/config');
    },
  );
  test(
    'Binance regular account is complete when Spot and both Futures wallets are priced',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => switch (request.url.path) {
            '/sapi/v1/account/apiRestrictions' => json({'enableReading': true}),
            '/api/v3/account' => json({
              'uid': 123,
              'balances': [
                {'asset': 'BTC', 'free': '1', 'locked': '0'},
              ],
            }),
            '/api/v3/ticker/price' => json([
              {'symbol': 'BTCUSDT', 'price': '100'},
            ]),
            '/v2/exchange-rates' => json({
              'data': {
                'rates': {'USDT': '1', 'BTC': '0.01'},
              },
            }),
            '/fapi/v3/account' => json({
              'assets': [
                {'asset': 'USDT', 'marginBalance': '50'},
              ],
            }),
            '/dapi/v1/account' => json({'assets': []}),
            '/fapi/v3/balance' ||
            '/dapi/v1/balance' ||
            '/fapi/v3/positionRisk' ||
            '/dapi/v1/positionRisk' => json([]),
            _ => throw StateError('Unexpected API'),
          },
        ),
      );
      final snapshot = await client.read(key(CryptoExchange.binance));
      expect(snapshot.totalUsd, amount('150'));
      expect(snapshot.complete, true);
      expect(snapshot.notices, isNot(contains('binanceCopyUnsupported')));
    },
  );
  test(
    'Binance regular account reports incomplete only when an owned asset lacks a price',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => switch (request.url.path) {
            '/sapi/v1/account/apiRestrictions' => json({'enableReading': true}),
            '/api/v3/account' => json({
              'uid': 123,
              'balances': [
                {'asset': 'UNKNOWN', 'free': '1', 'locked': '0'},
              ],
            }),
            '/api/v3/ticker/price' => json([]),
            '/v2/exchange-rates' => json({
              'data': {
                'rates': {'USDT': '1'},
              },
            }),
            '/fapi/v3/account' || '/dapi/v1/account' => json({'assets': []}),
            '/fapi/v3/balance' ||
            '/dapi/v1/balance' ||
            '/fapi/v3/positionRisk' ||
            '/dapi/v1/positionRisk' => json([]),
            _ => throw StateError('Unexpected API'),
          },
        ),
      );
      final snapshot = await client.read(key(CryptoExchange.binance));
      expect(snapshot.balances.single.priceUsd, isNull);
      expect(snapshot.complete, false);
    },
  );
  test(
    'Binance futures permission failure cannot masquerade as an empty wallet',
    () async {
      final client = ExchangeClient(
        client: MockClient((request) async {
          return switch (request.url.path) {
            '/sapi/v1/account/apiRestrictions' => json({'enableReading': true}),
            '/api/v3/account' => json({'uid': 123, 'balances': []}),
            '/api/v3/ticker/price' => json([]),
            '/v2/exchange-rates' => json({
              'data': {
                'rates': {'USDT': '1'},
              },
            }),
            _ => json({'code': -2015}, 401),
          };
        }),
      );
      await expectLater(
        client.read(key(CryptoExchange.binance)),
        throwsA(
          isA<CryptoSyncException>().having(
            (e) => e.code,
            'code',
            'futuresUnavailable',
          ),
        ),
      );
    },
  );
  test(
    'copy account read failure fails the snapshot instead of returning zero',
    () async {
      final client = ExchangeClient(
        client: MockClient((request) async {
          if (request.url.path == '/v2/exchange-rates') {
            return json({
              'data': {
                'rates': {'USDT': '1'},
              },
            });
          }
          if (request.url.path == '/v5/asset/asset-overview') {
            return json({'retCode': 10005, 'result': {}});
          }
          final result = switch (request.url.path) {
            '/v5/user/query-api' => {'userID': 456, 'readOnly': 1},
            '/v5/account/wallet-balance' => {
              'list': [
                {'totalEquity': '0', 'coin': []},
              ],
            },
            _ => {'list': [], 'nextPageCursor': ''},
          };
          return json({'retCode': 0, 'result': result});
        }),
      );
      await expectLater(
        client.read(key(CryptoExchange.bybit)),
        throwsA(
          isA<CryptoSyncException>().having(
            (e) => e.code,
            'code',
            'copyUnavailable',
          ),
        ),
      );
    },
  );

  test(
    'Binance rejects writable keys before loading private balances',
    () async {
      var calls = 0;
      final client = ExchangeClient(
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'GET');
          expect(request.url.path, '/sapi/v1/account/apiRestrictions');
          expect(request.headers['X-MBX-APIKEY'], 'fake-key');
          expect(request.url.queryParameters['signature'], isNotEmpty);
          return json({'enableReading': true, 'enableWithdrawals': true});
        }),
      );
      await expectLater(
        client.read(key(CryptoExchange.binance)),
        throwsA(
          isA<CryptoSyncException>().having((e) => e.code, 'code', 'readOnly'),
        ),
      );
      expect(calls, 1);
    },
  );
  test('OKX validates permissions and counts lead/copy equity once', () async {
    final client = ExchangeClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        final path = request.url.path;
        if (request.url.host == 'api.coinbase.com') {
          expect(request.headers.containsKey('OK-ACCESS-KEY'), false);
          return json({
            'data': {
              'rates': {'USDT': '1'},
            },
          });
        }
        if (path == '/api/v5/account/config') {
          expect(request.headers['OK-ACCESS-SIGN'], isNotEmpty);
          return json({
            'code': '0',
            'data': [
              {
                'uid': '123',
                'perm': 'read_only',
                'roleType': '1',
                'spotRoleType': '2',
              },
            ],
          });
        }
        if (path == '/api/v5/account/balance') {
          return json({
            'code': '0',
            'data': [
              {
                'totalEq': '1050',
                'details': [
                  {
                    'ccy': 'USDT',
                    'cashBal': '1000',
                    'spotIsoBal': '100',
                    'availBal': '800',
                    'frozenBal': '100',
                  },
                ],
              },
            ],
          });
        }
        if (path == '/api/v5/account/positions') {
          return json({
            'code': '0',
            'data': [
              {
                'instType': 'SWAP',
                'instId': 'BTC-USDT-SWAP',
                'pos': '10',
                'posSide': 'long',
                'ccy': 'USDT',
                'upl': '50',
                'markPx': '65000',
              },
            ],
          });
        }
        if (path == '/api/v5/market/tickers') {
          return json({'code': '0', 'data': []});
        }
        fail('unexpected request');
      }),
    );
    final snapshot = await client.read(key(CryptoExchange.okx));
    expect(snapshot.totalUsd, amount('1050'));
    expect(snapshot.balances.length, 2);
    expect(snapshot.positions.single.unit, 'contracts');
    expect(snapshot.positions.single.wallet, contains('Lead'));
  });
  test(
    'Bybit paginates hedge positions and includes copy categories without parent double-count',
    () async {
      var pages = 0;
      final client = ExchangeClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          final path = request.url.path;
          Object result = {};
          if (request.url.host == 'api.coinbase.com') {
            return json({
              'data': {
                'rates': {'USDT': '1', 'USDC': '1'},
              },
            });
          }
          if (path == '/v5/user/query-api') {
            result = {'userID': 456, 'readOnly': 1};
          }
          if (path == '/v5/account/wallet-balance') {
            result = {
              'list': [
                {
                  'totalEquity': '1050',
                  'coin': [
                    {
                      'coin': 'USDT',
                      'walletBalance': '1000',
                      'spotBorrow': '0',
                      'usdValue': '1050',
                    },
                  ],
                },
              ],
            };
          }
          if (path == '/v5/market/tickers') result = {'list': []};
          if (path == '/v5/position/list') {
            if (request.url.queryParameters['settleCoin'] == 'USDT') {
              pages++;
              final next = request.url.queryParameters['cursor'] == null;
              result = {
                'nextPageCursor': next ? 'page2' : '',
                'list': [
                  {
                    'symbol': 'BTCUSDT',
                    'side': next ? 'Buy' : 'Sell',
                    'size': '.1',
                    'markPrice': '65000',
                    'unrealisedPnl': '50',
                  },
                ],
              };
            } else {
              result = {'nextPageCursor': '', 'list': []};
            }
          }
          if (path == '/v5/asset/asset-overview') {
            result = {
              'list': [
                {
                  'accountType': 'CopyTrading',
                  'totalEquity': '300',
                  'categories': [
                    {
                      'category': 'Copy Trading Classic',
                      'equity': '100',
                      'coinDetail': [
                        {'coin': 'USDT', 'equity': '100'},
                      ],
                    },
                    {
                      'category': 'Copy Trading Pro',
                      'equity': '200',
                      'coinDetail': [
                        {'coin': 'USDT', 'equity': '200'},
                      ],
                    },
                  ],
                },
              ],
            };
          }
          return json({'retCode': 0, 'result': result});
        }),
      );
      final snapshot = await client.read(key(CryptoExchange.bybit));
      expect(pages, 2);
      expect(snapshot.positions.length, 2);
      expect(snapshot.positions.map((p) => p.isLong), [true, false]);
      expect(snapshot.totalUsd, amount('1350'));
      expect(snapshot.subtotal(CryptoWalletKind.copy), amount('300'));
    },
  );
  test(
    'failed or malformed private response is never an empty account',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => json({'code': '0', 'data': null}),
        ),
      );
      await expectLater(
        client.read(key(CryptoExchange.okx)),
        throwsA(isA<CryptoSyncException>()),
      );
    },
  );
  test(
    'HTTP errors expose only safe codes, never signed URL or returned credentials',
    () async {
      final client = ExchangeClient(
        client: MockClient(
          (request) async => json({
            'code': -2015,
            'msg': 'fake-secret fake-key ${request.url}',
          }, 401),
        ),
      );
      try {
        await client.read(key(CryptoExchange.binance));
        fail('expected failure');
      } on CryptoSyncException catch (e) {
        expect(e.detail, '-2015');
        expect('$e', isNot(contains('fake-secret')));
        expect('$e', isNot(contains('signature')));
      }
    },
  );
}
