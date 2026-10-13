import "dart:async";
import "dart:convert";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:hive_flutter/hive_flutter.dart";

class CacheKeys {
  CacheKeys._();
  static const String _p = "v2";
  static String _k(String s) => "$_p:$s";
  static String authSession(String phone) => _k("auth:$phone");
  static String activeProfile(String phone) => _k("profile:active:$phone");
  static String learnerState(String learnerId) => _k("learner:state:$learnerId");
  static String onboardingCompleted(String learnerId) => _k("onboarding:done:$learnerId");
  static String profilesPage(String phone, int page, int pageSize) => _k("profiles:$phone:$page:$pageSize");
  static String profilesPrefix(String phone) => _k("profiles:$phone");
  static String profilesSearch(String phone, {String? grade, String? division, String? rollNumber, String? query, int page = 1}) => _k("profiles:search:$phone:${grade ?? ""}:${division ?? ""}:${rollNumber ?? ""}:${query ?? ""}:$page");
  static String rosterPrefix(String phone) => _k("roster:$phone");
  static String courseIndex(String lang) => _k("course:index:$lang");
  static String courseDetail(String courseId, String lang) => _k("course:detail:$courseId:$lang");
  static String flowManifest(String lang) => _k("flow:manifest:$lang");
  static String flow(String lang, String category, String fileName) => _k("flow:$lang:$category:$fileName");
  static String chatSurface(String profileId, String surface) => _k("chat:$profileId:$surface");
  static String chatProfileIndex(String profileId) => _k("chat:index:$profileId");
  static String chatTranscript(String phone, String learnerId) => _k("chat:$phone:$learnerId");
  static String submissionReview(String learnerId, String assignmentId, String stepId) => _k("submission:review:$learnerId:$assignmentId:$stepId");
  static String classSessionWindow(String learnerId) => _k("class:window:$learnerId");
  static String languageSetting() => _k("language:setting");
}

class LocalCacheOpenTimeoutException implements Exception {
  @override
  String toString() => "LocalCache.open() timed out";
}

class LocalCache {
  LocalCache._(this._box);
  final Box<dynamic> _box;

  static Future<LocalCache> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>("tapapp_cache").timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw LocalCacheOpenTimeoutException(),
    );
    return LocalCache._(box);
  }

  bool has(String key) => _box.containsKey(key);

  DateTime? cachedAt(String key) {
    final raw = _box.get("${key}__ts");
    if (raw == null) return null;
    final ms = raw is int ? raw : int.tryParse(raw.toString());
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Map<String, dynamic>? getForeverRaw(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  List<T>? getForeverList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;
    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded;
        } else {
          return null;
        }
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }
    return list.whereType<Map>().map((m) => fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<void> setForeverRaw(String key, Map<String, dynamic> value) async {
    await _box.put(key, value);
    await _box.put("${key}__ts", DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setForeverRawList(String key, List<Map<String, dynamic>> value) async {
    await _box.put(key, value);
    await _box.put("${key}__ts", DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.delete("${key}__ts");
  }

  Future<void> deletePrefix(String prefix) async {
    final keys = _box.keys.whereType<String>().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _box.delete(key);
    }
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  List<String> keysWithPrefix(String prefix) {
    return _box.keys.whereType<String>().where((k) => k.startsWith(prefix)).toList();
  }
}

class CachedRepo<T> {
  CachedRepo(this._localCache);
  final LocalCache _localCache;
  final Map<String, T> _memory = {};

  Future<T> getOrFetch({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required Future<T> Function() fetch,
  }) async {
    final cached = _memory[key];
    if (cached != null) return cached;
    final raw = _localCache.getForeverRaw(key);
    if (raw != null) {
      try {
        final value = fromJson(raw);
        _memory[key] = value;
        return value;
      } catch (_) {}
    }
    final value = await fetch();
    _memory[key] = value;
    await _localCache.setForeverRaw(key, toJson(value));
    return value;
  }

  void invalidate(String key) {
    _memory.remove(key);
  }
}

class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;
  static const String _phoneKey = "tap_phone";
  static const String _tokenKey = "tap_token";
  static const String _adminCodeKey = "tap_admin_code";

  Future<String?> readPhone() => _storage.read(key: _phoneKey);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readAdminCode() => _storage.read(key: _adminCodeKey);

  Future<void> saveSession({
    required String phone,
    required String token,
    String? adminCode,
  }) async {
    final writeFutures = <Future<void>>[
      _storage.write(key: _phoneKey, value: phone),
      _storage.write(key: _tokenKey, value: token),
    ];
    if (adminCode != null) {
      writeFutures.add(_storage.write(key: _adminCodeKey, value: adminCode));
    }
    await Future.wait(writeFutures);
  }

  Future<void> saveRefreshedToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.deleteAll();
}
