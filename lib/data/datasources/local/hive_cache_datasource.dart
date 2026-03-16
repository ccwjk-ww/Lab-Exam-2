import 'package:hive/hive.dart';

abstract class CacheDataSource {
  Future<String?> getCachedAiResult(String key);
  Future<void> cacheAiResult(String key, String result);
  Future<void> clearCache();
}

class HiveCacheDataSourceImpl implements CacheDataSource {
  static const String _boxName = 'ai_cache';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Cache key = MD5-like hash of OCR text (use substring for simplicity)
  String _buildKey(String text) =>
      'ai_${text.replaceAll(RegExp(r'\s+'), '').substring(0, text.length.clamp(0, 50))}';

  @override
  Future<String?> getCachedAiResult(String key) async {
    return _box.get(_buildKey(key));
  }

  @override
  Future<void> cacheAiResult(String key, String result) async {
    await _box.put(_buildKey(key), result);
  }

  @override
  Future<void> clearCache() async {
    await _box.clear();
  }
}
