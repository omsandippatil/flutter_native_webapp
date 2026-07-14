
import '../../core/cache/cache_keys.dart';
import '../../core/cache/local_cache.dart';
import '../models/learner_state_model.dart';
import '../models/profile_summary_model.dart';
import '../remote/api_endpoints.dart';
import '../remote/http_client.dart';
import 'learner_state_repository.dart';
import 'roster_cache_sync.dart';

class BulkChange {
  const BulkChange({required this.learnerId, required this.updates});
  final String learnerId;
  final Map<String, dynamic> updates;

  Map<String, dynamic> toJson() => {'learner_id': learnerId, 'updates': updates};
}

class RosterRepository {
  RosterRepository(this._http, this._localCache, this._learnerStateRepository);

  final HttpClient _http;
  final LocalCache _localCache;
  final LearnerStateRepository _learnerStateRepository;

  Future<List<ProfileSummaryModel>> readCachedRoster(
    String phone, {
    String? grade,
    String? division,
    String? query,
  }) async {
    final key = CacheKeys.roster(phone, grade: grade, division: division, query: query);
    final raw = _localCache.getForeverList(key, (json) => json);
    return raw == null ? const [] : ProfileSummaryModel.listFromCache(raw);
  }

  Future<Map<String, dynamic>> searchStudent({
    required String phone,
    required String grade,
    required String rollNumber,
    required String division,
    bool forceRefresh = false,
  }) async {
    final key = CacheKeys.studentSearch(phone, grade, rollNumber, division);
    if (!forceRefresh && _localCache.has(key)) {
      final cached = _localCache.getForeverRaw(key);
      if (cached != null) return cached;
    }

    final data = await _http.get(ApiEndpoints.studentsSearch, query: {
      'phone': phone,
      'grade': grade,
      'roll_number': rollNumber,
      'division': division,
    });
    final learnerId = data['learner_id'] as String?;
    final state = data['state'];
    if (learnerId != null && state is Map) {
      final model = LearnerStateModel.fromFullJson(learnerId, Map<String, dynamic>.from(state));
      await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
    }
    await _localCache.setForeverRaw(key, data);
    return data;
  }

  Future<List<ProfileSummaryModel>> fetchStudents({
    required String phone,
    String? grade,
    String? division,
    int page = 1,
    int pageSize = 100,
    bool forceRefresh = false,
  }) async {
    final rosterKey = CacheKeys.roster(phone, grade: grade, division: division);
    if (!forceRefresh && _localCache.has(rosterKey)) {
      return readCachedRoster(phone, grade: grade, division: division);
    }

    final data = await _http.get(ApiEndpoints.students, query: {
      'phone': phone,
      if (grade != null) 'grade': grade,
      if (division != null) 'division': division,
      'page': page,
      'page_size': pageSize,
    });
    final rows = ProfileSummaryModel.listFromJson(phone, data['students']);
    await _localCache.setForeverRawList(rosterKey, ProfileSummaryModel.listToJson(rows));

    final rawStudents = data['students'];
    if (rawStudents is List) {
      for (final raw in rawStudents.whereType<Map>()) {
        final learnerId = raw['learner_id'] as String?;
        final state = raw['state'];
        if (learnerId != null && state is Map) {
          final model = LearnerStateModel.fromFullJson(learnerId, Map<String, dynamic>.from(state));
          await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
        }
      }
    }
    return rows;
  }

  Future<LearnerStateModel> updateStudent({
    required String phone,
    required String learnerId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _http.post(ApiEndpoints.studentsUpdate, body: {
      'phone': phone,
      'learner_id': learnerId,
      'updates': updates,
    });

    final touchesRosterFields = updates.containsKey('student_name') ||
        updates.containsKey('grade') ||
        updates.containsKey('division') ||
        updates.containsKey('roll_number') ||
        updates.containsKey('avatar');

    if (touchesRosterFields) {
      await RosterCacheSync.patchRow(
        _localCache,
        phone: phone,
        learnerId: learnerId,
        studentName: updates['student_name'] as String?,
        rollNumber: (updates['roll_number'] as num?)?.toInt(),
        grade: updates['grade'] as String?,
        division: updates['division'] as String?,
        avatar: updates['avatar'] as String?,
      );
    }

    final existing = await _learnerStateRepository.readCached(learnerId);
    final model = existing == null
        ? LearnerStateModel.fromFullJson(learnerId, data)
        : existing.mergeFrom(data);
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
    return model;
  }

  Future<Map<String, dynamic>> bulkUpdateStudents({
    required String phone,
    required List<BulkChange> changes,
    bool atomic = false,
  }) async {
    final changesJson = changes.map((c) => c.toJson()).toList();
    final data = await _http.post(ApiEndpoints.studentsBulkUpdate, body: {
      'phone': phone,
      'atomic': atomic,
      'changes': changesJson,
    });

    final results = data['results'];
    if (results is List) {
      final succeededIds = <String>{
        for (final r in results.whereType<Map>())
          if (r['success'] == true && r['learner_id'] != null) r['learner_id'] as String,
      };

      if (succeededIds.isNotEmpty) {
        final updatesByLearnerId = <String, Map<String, dynamic>>{
          for (final change in changesJson)
            if (succeededIds.contains(change['learner_id']))
              change['learner_id'] as String: Map<String, dynamic>.from(change['updates'] as Map),
        };
        await RosterCacheSync.patchManyRows(
          _localCache,
          phone: phone,
          updatesByLearnerId: updatesByLearnerId,
        );
      }
    }
    return data;
  }
}
