import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../services/beijing_stock_logo_service.dart';
import 'market_util.dart';
import 'stock_logo_urls.dart';

/// Logo 本地缓存：并发请求共享下载结果，缺失或损坏时交给界面显示文字占位。
class LogoCacher {
  static String? _cachePath;
  static final Map<String, Future<ImageProvider?>> _downloading = {};
  static final Map<String, DateTime> _failedAt = {};
  static const _retryDelay = Duration(minutes: 1);

  static Future<void> ensureInit() async {
    if (_cachePath != null) return;
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/logos',
    );
    await dir.create(recursive: true);
    _cachePath = dir.path;
  }

  static String _filePath(String key) =>
      '$_cachePath/${Uri.encodeComponent(key.toUpperCase())}.png';

  static ImageProvider? syncCached(String key) {
    if (_cachePath == null) return null;
    final file = File(_filePath(key));
    return file.existsSync() ? FileImage(file) : null;
  }

  static Future<ImageProvider?> getStockLogo(
    String code,
    String market, {
    String secid = '',
  }) async {
    final urls = StockLogoUrls.forStock(code, market, secid: secid);
    if (urls.isEmpty) return null;
    return getLogo(
      StockLogoUrls.cacheKey(code, market),
      urls.first,
      fallbackUrls: urls.skip(1).toList(),
      fallbackLoader: market == MarketUtil.exchangeBJ
          ? () => BeijingStockLogoService().findLogos(code)
          : null,
    );
  }

  /// key 应包含市场；自定义股票继续使用原来的本地图标标识。
  static Future<ImageProvider?> getLogo(
    String key,
    String logoUrl, {
    List<String> fallbackUrls = const [],
    Future<List<String>> Function()? fallbackLoader,
  }) async {
    await ensureInit();
    key = key.toUpperCase();
    final cached = syncCached(key);
    if (cached != null) return cached;
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < _retryDelay) {
      return null;
    }
    final pending = _downloading[key];
    if (pending != null) return pending;
    final download = _downloadToCache(key, [
      logoUrl,
      ...fallbackUrls,
    ], fallbackLoader);
    _downloading[key] = download;
    try {
      return await download;
    } finally {
      _downloading.remove(key);
    }
  }

  static Future<void> cacheLocalImage(String code, String sourcePath) async {
    await ensureInit();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected image does not exist', sourcePath);
    }
    final target = File(_filePath(code));
    await source.copy(target.path);
  }

  static Future<void> cacheLocalImageBytes(String code, Uint8List bytes) async {
    await ensureInit();
    await File(_filePath(code)).writeAsBytes(bytes, flush: true);
  }

  static Future<ImageProvider?> _downloadToCache(
    String key,
    List<String> urls,
    Future<List<String>> Function()? fallbackLoader,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      for (final url in urls.toSet()) {
        try {
          final uri = Uri.parse(url);
          final response = await http
              .get(
                uri,
                headers: {
                  'User-Agent': 'Mozilla/5.0',
                  'Referer': '${uri.origin}/',
                },
              )
              .timeout(const Duration(seconds: AppConfig.httpTimeoutSec));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            continue;
          }
          // CDN 的错误页有时也返回 200，必须成功解码才能写入持久缓存。
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
          final target = File(_filePath(key));
          await target.writeAsBytes(response.bodyBytes, flush: true);
          _failedAt.remove(key);
          return FileImage(target);
        } catch (e) {
          debugPrint('[Logo] ===> 下载失败 $key: $e');
        }
      }
      if (attempt == 0 && fallbackLoader != null) {
        try {
          urls = await fallbackLoader();
        } catch (_) {
          break;
        }
      } else {
        break;
      }
    }
    _failedAt[key] = DateTime.now();
    return null;
  }
}
