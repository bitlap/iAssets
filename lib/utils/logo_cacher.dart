import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Logo 本地缓存服务：首次下载后缓存到本地文件，后续直接读取本地文件
class LogoCacher {
  static String? _cachePath;
  static final Set<String> _downloading = {};

  /// 初始化缓存目录（应用启动时调用一次）
  static Future<void> ensureInit() async {
    if (_cachePath != null) return;
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/logos',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 创建缓存目录: ${dir.path}',
      );
    } else {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 缓存目录已存在: ${dir.path}',
      );
    }
    _cachePath = dir.path;
  }

  static String _filePath(String code) =>
      '$_cachePath/${code.toUpperCase()}.png';

  /// 同步检查本地缓存，有则返回 FileImage（零延迟）
  static ImageProvider? syncCached(String code) {
    if (_cachePath == null) return null;
    final file = File(_filePath(code));
    if (file.existsSync()) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 缓存命中: $code',
      );
      return FileImage(file);
    }
    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 缓存未命中: $code',
    );
    return null;
  }

  /// 获取 Logo ImageProvider，有缓存直接返回，无缓存则同步下载后返回 FileImage
  static Future<ImageProvider> getLogo(String code, String logoUrl) async {
    final cached = syncCached(code);
    if (cached != null) return cached;
    final key = code.toUpperCase();
    if (!_downloading.contains(key)) {
      _downloading.add(key);
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 开始下载: $code -> $logoUrl',
      );
      await _downloadToCache(key, logoUrl);
    } else {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 已在下载队列中: $code',
      );
    }
    // 下载完成后从本地缓存读取
    final local = syncCached(code);
    if (local != null) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 下载完成，使用本地缓存: $code',
      );
    } else {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 下载后仍无缓存，fallback 到网络: $code',
      );
    }
    return local ?? NetworkImage(logoUrl);
  }

  /// 将用户选择的本地图片复制到持久化 Logo 缓存目录。
  static Future<void> cacheLocalImage(String code, String sourcePath) async {
    await ensureInit();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected image does not exist', sourcePath);
    }
    final target = File(_filePath(code));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  /// 将图片字节保存为持久化 Logo，适用于相册和文件选择器。
  static Future<void> cacheLocalImageBytes(String code, Uint8List bytes) async {
    await ensureInit();
    final target = File(_filePath(code));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
  }

  /// 下载图片到本地（等待完成）
  static Future<void> _downloadToCache(String code, String logoUrl) async {
    try {
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200) {
        final file = File(_filePath(code));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint(
          '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 缓存成功: $code (${response.bodyBytes.length} bytes)',
        );
      } else {
        debugPrint(
          '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 下载失败 HTTP ${response.statusCode}: $code',
        );
      }
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][Logo] ===> 下载异常 $code: $e',
      );
    }
    _downloading.remove(code);
  }
}
