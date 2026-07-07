import 'activity_progress_store.dart';

class MemoryActivityProgressStore implements ActivityProgressStore {
  static Map<String, dynamic>? _value;

  @override
  Future<Map<String, dynamic>?> read() async {
    return _value == null ? null : Map<String, dynamic>.from(_value!);
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    _value = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

ActivityProgressStore createActivityProgressStore() {
  return MemoryActivityProgressStore();
}
