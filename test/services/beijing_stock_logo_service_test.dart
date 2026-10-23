import 'dart:convert';
import 'package:assets/services/beijing_stock_logo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response profile({
    String code = '920002',
    String web = 'www.example.com',
  }) => http.Response(
    jsonEncode({
      'jbzl': [
        {'SECUCODE': '$code.BJ', 'SECURITY_CODE': code, 'ORG_WEB': web},
      ],
    }),
    200,
  );

  test(
    'verified Beijing company profile resolves only explicit website logo images',
    () async {
      final requests = <Uri>[];
      await http.runWithClient(
        () async {
          expect(await BeijingStockLogoService().findLogos('920002'), [
            'https://www.example.com/images/company-logo.png',
            'https://cdn.example.com/logo.jpg?a=1&b=2',
          ]);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'emweb.securities.eastmoney.com') {
            expect(request.url.queryParameters['code'], 'BJ920002');
            return profile();
          }
          expect(request.url.toString(), 'https://www.example.com');
          return http.Response('''<img src="/banner.png"><img src="/logo.svg">
        <img src="/images/company-logo.png"><img src="/images/company-logo.png">
        <img class="logo" data-src="//cdn.example.com/logo.jpg?a=1&amp;b=2">
        <img class="logo" src="http://127.0.0.1/logo.png">''', 200);
        }),
      );
      expect(requests, hasLength(2));
    },
  );

  test(
    'mismatched stocks and invalid company websites never fetch a website',
    () async {
      for (final r in [
        profile(code: '920599'),
        profile(web: 'https://localhost'),
        profile(web: 'http://127.0.0.1'),
        profile(web: 'https://user:secret@example.com'),
        http.Response('{"jbzl":[]}', 200),
        http.Response('invalid', 200),
      ]) {
        var requests = 0;
        await http.runWithClient(
          () async {
            expect(
              await BeijingStockLogoService().findLogos('920002'),
              isEmpty,
            );
            expect(requests, 1);
          },
          () => MockClient((_) async {
            requests++;
            return r;
          }),
        );
      }
    },
  );

  test(
    'no explicit logo or unavailable company page keeps the text fallback',
    () async {
      for (final response in [
        http.Response('<img src="/product.jpg">', 200),
        http.Response('', 503),
      ]) {
        await http.runWithClient(
          () async {
            expect(
              await BeijingStockLogoService().findLogos('920599'),
              isEmpty,
            );
            expect(
              await BeijingStockLogoService().findLogos('../invalid'),
              isEmpty,
            );
          },
          () => MockClient(
            (r) async => r.url.host == 'emweb.securities.eastmoney.com'
                ? profile(code: '920599')
                : response,
          ),
        );
      }
    },
  );
}
