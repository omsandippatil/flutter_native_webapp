import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  LocalCache._(this._box);

  static const String _boxName = 'tap_forever_cache';
  final Box<String> _box;

  static Future<LocalCache> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    return LocalCache._(box);
  }

  bool has(String key) => _box.containsKey(key);

  T? getForever<T>(String key, T Function(Map<String, dynamic> json) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return fromJson(Map<String, dynamic>.from(decoded));
    return null;
  }

  List<T>? getForeverList<T>(String key, T Function(Map<String, dynamic> json) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }
    return null;
  }

  Map<String, dynamic>? getForeverRaw(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> setForever<T>(String key, T value, Map<String, dynamic> Function(T value) toJson) async {
    await _box.put(key, jsonEncode(toJson(value)));
  }

  Future<void> setForeverList<T>(String key, List<T> values, Map<String, dynamic> Function(T value) toJson) async {
    await _box.put(key, jsonEncode(values.map(toJson).toList()));
  }

  Future<void> setForeverRaw(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  Future<void> setForeverRawList(String key, List<Map<String, dynamic>> value) async {
    await _box.put(key, jsonEncode(value));
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  List<String> keysWithPrefix(String prefix) =>
      _box.keys.map((k) => k.toString()).where((k) => k.startsWith(prefix)).toList();

  Future<void> deletePrefix(String prefix) async {
    final keys = _box.keys.where((k) => k.toString().startsWith(prefix)).toList();
    await _box.deleteAll(keys);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
