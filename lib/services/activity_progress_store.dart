import 'activity_progress_store_stub.dart'
    if (dart.library.html) 'activity_progress_store_web.dart';

abstract class ActivityProgressStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
  Future<void> clear();

  factory ActivityProgressStore() => createActivityProgressStore();
}
