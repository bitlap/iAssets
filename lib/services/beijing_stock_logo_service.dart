import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// 北交所图标源未收录时，从已核对股票代码的公司资料查找官网 Logo。
class BeijingStockLogoService {
  Future<List<String>> findLogos(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return [];
    final client = http.Client();
    try {
      final profile = await client
          .get(
            Uri.https(
              'emweb.securities.eastmoney.com',
              '/PC_HSF10/CompanySurvey/PageAjax',
              {'code': 'BJ$code'},
            ),
            headers: {'User-Agent': 'Mozilla/5.0'},
          )
          .timeout(const Duration(seconds: AppConfig.httpTimeoutSec));
      if (profile.statusCode != 200) return [];
      final data = jsonDecode(profile.body) as Map<String, dynamic>;
      final rows = data['jbzl'] as List?;
      if (rows == null || rows.isEmpty) return [];
      final company = rows.first as Map<String, dynamic>;
      if (company['SECUCODE'] != '$code.BJ' ||
          company['SECURITY_CODE'] != code) {
        return [];
      }
      final web = company['ORG_WEB'];
      if (web is! String || web.trim().isEmpty) return [];
      final rawSite = web.trim().split(RegExp(r'[,;；，\s]+')).first;
      var site = Uri.tryParse(
        rawSite.contains('://') ? rawSite : 'https://$rawSite',
      );
      if (site == null || !_publicWeb(site)) return [];
      site = site.replace(scheme: 'https');
      final page = await client
          .get(site, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: AppConfig.httpTimeoutSec));
      if (page.statusCode != 200) return [];
      final logos = <String>{};
      for (final tag in RegExp(
        r'<img\b[^>]*>',
        caseSensitive: false,
      ).allMatches(page.body)) {
        final attributes = <String, String>{
          for (final attr in RegExp(
            r'''([\w-]+)\s*=\s*["']([^"']*)["']''',
          ).allMatches(tag.group(0)!))
            attr.group(1)!.toLowerCase(): attr.group(2)!,
        };
        final src =
            attributes['data-src'] ??
            attributes['data-original'] ??
            attributes['src'];
        if (src == null ||
            ![
              src,
              attributes['class'],
              attributes['id'],
              attributes['alt'],
            ].join(' ').toLowerCase().contains('logo')) {
          continue;
        }
        final image = site
            .resolve(src.replaceAll('&amp;', '&'))
            .replace(scheme: 'https');
        // Flutter 的普通 Image 不支持 SVG；不把图表、横幅或站点图标当公司 Logo。
        if (!_publicWeb(image) || image.path.toLowerCase().endsWith('.svg')) {
          continue;
        }
        logos.add(image.toString());
        if (logos.length == 4) break;
      }
      return logos.toList();
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  bool _publicWeb(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(uri.host);
}
