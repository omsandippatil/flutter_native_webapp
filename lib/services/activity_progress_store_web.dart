import 'dart:convert';
import 'dart:html' as html;

import 'activity_progress_store.dart';

class WebActivityProgressStore implements ActivityProgressStore {
  static const _key = 'tap_activity_progress_v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = html.window.localStorage[_key];
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    html.window.localStorage[_key] = jsonEncode(value);
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_key);
  }
}

ActivityProgressStore createActivityProgressStore() {
  return WebActivityProgressStore();
}
