import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/course/course.dart';
import 'package:tapapp/core/flow/flow.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/localization/language.dart';
import 'package:tapapp/core/network/network.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/core/storage/storage.dart';

class ActiveProfileModel {
  const ActiveProfileModel({
    required this.phone,
    required this.learnerId,
    required this.studentName,
    this.grade,
    this.division,
    this.avatar,
    this.onboardingCompleted = false,
  });

  final String phone;
  final String learnerId;
  final String? studentName;
  final String? grade;
  final String? division;
  final String? avatar;
  final bool onboardingCompleted;

  factory ActiveProfileModel.fromJson(Map<String, dynamic> json) =>
      ActiveProfileModel(
        phone: json['phone'] as String,
        learnerId: json['learner_id'] as String,
        studentName: json['student_name'] as String?,
        grade: json['grade'] as String?,
        division: json['division'] as String?,
        avatar: json['avatar'] as String?,
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'learner_id': learnerId,
    'student_name': studentName,
    'grade': grade,
    'division': division,
    'avatar': avatar,
    'onboarding_completed': onboardingCompleted,
  };

  ActiveProfileModel copyWith({
    String? studentName,
    String? grade,
    String? division,
    String? avatar,
    bool? onboardingCompleted,
  }) => ActiveProfileModel(
    phone: phone,
    learnerId: learnerId,
    studentName: studentName ?? this.studentName,
    grade: grade ?? this.grade,
    division: division ?? this.division,
    avatar: avatar ?? this.avatar,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}

class ProfileSummaryModel {
  const ProfileSummaryModel({
    required this.learnerId,
    required this.ownerPhone,
    required this.studentName,
    this.rollNumber,
    this.grade,
    this.division,
    this.avatar,
    this.onboardingCompleted = false,
  });

  final String learnerId;
  final String ownerPhone;
  final String studentName;
  final int? rollNumber;
  final String? grade;
  final String? division;
  final String? avatar;
  final bool onboardingCompleted;

  static int? _parseRollNumber(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  factory ProfileSummaryModel.fromJson(
    String ownerPhone,
    Map<String, dynamic> json,
  ) => ProfileSummaryModel(
    learnerId: json['learner_id'] as String,
    ownerPhone: ownerPhone,
    studentName: json['student_name'] as String? ?? '',
    rollNumber: _parseRollNumber(json['roll_number']),
    grade: json['grade']?.toString(),
    division: json['division'] as String?,
    avatar: json['avatar']?.toString(),
    onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'learner_id': learnerId,
    'owner_phone': ownerPhone,
    'student_name': studentName,
    'roll_number': rollNumber,
    'grade': grade,
    'division': division,
    'avatar': avatar,
    'onboarding_completed': onboardingCompleted,
  };

  ProfileSummaryModel copyWith({
    String? studentName,
    int? rollNumber,
    String? grade,
    String? division,
    String? avatar,
    bool? onboardingCompleted,
  }) => ProfileSummaryModel(
    learnerId: learnerId,
    ownerPhone: ownerPhone,
    studentName: studentName ?? this.studentName,
    rollNumber: rollNumber ?? this.rollNumber,
    grade: grade ?? this.grade,
    division: division ?? this.division,
    avatar: avatar ?? this.avatar,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );

  static List<ProfileSummaryModel> listFromJson(
    String ownerPhone,
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => ProfileSummaryModel.fromJson(
            ownerPhone,
            Map<String, dynamic>.from(m),
          ),
        )
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listToJson(
    List<ProfileSummaryModel> list,
  ) => list.map((p) => p.toJson()).toList(growable: false);

  static List<ProfileSummaryModel> listFromCache(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) {
          final json = Map<String, dynamic>.from(m);
          return ProfileSummaryModel.fromJson(
            json['owner_phone'] as String,
            json,
          );
        })
        .toList(growable: false);
  }
}

class RosterSync {
  RosterSync._();

  static Future<void> patchRow(
    LocalCache localCache, {
    required String phone,
    required String learnerId,
    String? studentName,
    int? rollNumber,
    String? grade,
    String? division,
    String? avatar,
    bool? onboardingCompleted,
  }) async {
    final prefixes = [
      CacheKeys.rosterPrefix(phone),
      CacheKeys.profilesPrefix(phone),
    ];

    for (final prefix in prefixes) {
      for (final key in localCache.keysWithPrefix(prefix)) {
        final raw = localCache.getForeverList(key, (json) => json);
        if (raw == null) continue;
        final rows = ProfileSummaryModel.listFromCache(raw);
        final idx = rows.indexWhere((r) => r.learnerId == learnerId);
        if (idx == -1) continue;

        final updated = rows[idx].copyWith(
          studentName: studentName,
          rollNumber: rollNumber,
          grade: grade,
          division: division,
          avatar: avatar,
          onboardingCompleted: onboardingCompleted,
        );
        final newRows = List<ProfileSummaryModel>.from(rows)..[idx] = updated;
        await localCache.setForeverRawList(
          key,
          ProfileSummaryModel.listToJson(newRows),
        );
      }
    }
  }

  static Future<void> patchManyRows(
    LocalCache localCache, {
    required String phone,
    required Map<String, Map<String, dynamic>> updatesByLearnerId,
  }) async {
    final prefixes = [
      CacheKeys.rosterPrefix(phone),
      CacheKeys.profilesPrefix(phone),
    ];

    for (final prefix in prefixes) {
      for (final key in localCache.keysWithPrefix(prefix)) {
        final raw = localCache.getForeverList(key, (json) => json);
        if (raw == null) continue;
        var rows = ProfileSummaryModel.listFromCache(raw);
        var changed = false;

        for (final entry in updatesByLearnerId.entries) {
          final idx = rows.indexWhere((r) => r.learnerId == entry.key);
          if (idx == -1) continue;
          final u = entry.value;
          rows = List<ProfileSummaryModel>.from(rows)
            ..[idx] = rows[idx].copyWith(
              studentName: u['student_name'] as String?,
              rollNumber: (u['roll_number'] as num?)?.toInt(),
              grade: u['grade'] as String?,
              division: u['division'] as String?,
              avatar: u['avatar'] as String?,
            );
          changed = true;
        }

        if (changed) {
          await localCache.setForeverRawList(
            key,
            ProfileSummaryModel.listToJson(rows),
          );
        }
      }
    }
  }
}

class ProfileRepository {
  ProfileRepository(this._http, this._localCache, this._learnerStateRepository);

  final HttpClient _http;
  final LocalCache _localCache;
  final LearnerStateRepository _learnerStateRepository;

  Future<List<ProfileSummaryModel>> readCachedProfilesPage(
    String phone,
    int page,
    int pageSize,
  ) async {
    final raw = _localCache.getForeverList(
      CacheKeys.profilesPage(phone, page, pageSize),
      (json) => json,
    );
    return raw == null
        ? const []
        : _withLocalOnboardingState(ProfileSummaryModel.listFromCache(raw));
  }

  Future<List<ProfileSummaryModel>> fetchProfilesPage({
    required String phone,
    int page = 1,
    int pageSize = 10,
    bool forceRefresh = false,
  }) async {
    final key = CacheKeys.profilesPage(phone, page, pageSize);
    if (!forceRefresh && _localCache.has(key)) {
      return readCachedProfilesPage(phone, page, pageSize);
    }

    final data = await _http.get(
      ApiEndpoints.profiles,
      query: {'phone': phone, 'page': page, 'page_size': pageSize},
    );
    final rows = _withLocalOnboardingState(
      ProfileSummaryModel.listFromJson(phone, data['profiles']),
    );
    await _localCache.setForeverRawList(
      key,
      ProfileSummaryModel.listToJson(rows),
    );
    return rows;
  }

  Future<List<ProfileSummaryModel>> searchProfiles({
    required String phone,
    String? grade,
    String? division,
    String? rollNumber,
    String? query,
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final key = CacheKeys.profilesSearch(
      phone,
      grade: grade,
      division: division,
      rollNumber: rollNumber,
      query: query,
      page: page,
    );
    if (!forceRefresh && _localCache.has(key)) {
      final raw = _localCache.getForeverList(key, (json) => json);
      return raw == null
          ? const []
          : _withLocalOnboardingState(ProfileSummaryModel.listFromCache(raw));
    }

    final data = await _http.get(
      ApiEndpoints.profilesSearch,
      query: {
        'phone': phone,
        'grade': ?grade,
        'division': ?division,
        'roll_number': ?rollNumber,
        'query': ?query,
        'page': page,
        'page_size': pageSize,
      },
    );
    final rows = _withLocalOnboardingState(
      ProfileSummaryModel.listFromJson(phone, data['profiles']),
    );
    await _localCache.setForeverRawList(
      key,
      ProfileSummaryModel.listToJson(rows),
    );
    return rows;
  }

  Future<LearnerStateModel> selectProfile({
    required String phone,
    required String learnerId,
  }) async {
    final data = await _http.post(
      ApiEndpoints.profilesSelect,
      body: {'phone': phone, 'learner_id': learnerId},
    );
    final model = LearnerStateModel.fromFullJson(learnerId, data);
    final profileData = data['profile'];
    if (data['onboarding_completed'] == true ||
        (profileData is Map && profileData['onboarding_completed'] == true)) {
      await _markOnboardingCompleted(learnerId);
    }
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      model.toJson(),
    );
    return _learnerStateRepository.restoreLocalProgress(model);
  }

  Future<void> setActiveProfile(ActiveProfileModel profile) async {
    await _localCache.setForeverRaw(
      CacheKeys.activeProfile(profile.phone),
      profile.toJson(),
    );
    if (profile.onboardingCompleted) {
      await _markOnboardingCompleted(profile.learnerId);
    }
  }

  Future<ActiveProfileModel?> readActiveProfile(String phone) async {
    final raw = _localCache.getForeverRaw(CacheKeys.activeProfile(phone));
    if (raw == null) return null;
    final profile = ActiveProfileModel.fromJson(raw);
    if (profile.onboardingCompleted) {
      await _markOnboardingCompleted(profile.learnerId);
    }
    return profile;
  }

  Future<void> clearActiveProfile(String phone) async {
    await _localCache.delete(CacheKeys.activeProfile(phone));
  }

  Future<String> updateAvatar({
    required String phone,
    required String learnerId,
    required String avatar,
  }) async {
    final data = await _http.post(
      ApiEndpoints.profilesAvatar,
      body: {'phone': phone, 'learner_id': learnerId, 'avatar': avatar},
    );
    final resolvedAvatar = data['avatar'] as String? ?? avatar;
    if (data['success'] == true) {
      await RosterSync.patchRow(
        _localCache,
        phone: phone,
        learnerId: learnerId,
        avatar: resolvedAvatar,
      );
    }
    return resolvedAvatar;
  }

  Future<LearnerStateModel> updateProfile({
    required String phone,
    required String learnerId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _http.post(
      ApiEndpoints.profilesUpdate,
      body: {'phone': phone, 'learner_id': learnerId, 'updates': updates},
    );

    if (updates.containsKey('student_name')) {
      await RosterSync.patchRow(
        _localCache,
        phone: phone,
        learnerId: learnerId,
        studentName: updates['student_name'] as String?,
      );
    }

    final existing = await _learnerStateRepository.readCached(learnerId);
    final model = existing == null
        ? LearnerStateModel.fromFullJson(learnerId, data)
        : existing.mergeFrom(data);
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      model.toJson(),
    );
    return model;
  }

  Future<LearnerStateModel> completeOnboarding({
    required String phone,
    required String learnerId,
    Map<String, dynamic>? updates,
    String? course,
    bool markComplete = true,
  }) async {
    await _http.post(
      ApiEndpoints.onboardingComplete,
      body: {
        'phone': phone,
        'learner_id': learnerId,
        if (updates != null && updates.isNotEmpty)
          'updates': updates,
        'course': ?course,
        'mark_complete': markComplete ? 1 : 0,
      },
    );

    if (markComplete) {
      await _markOnboardingCompleted(learnerId);
      await RosterSync.patchRow(
        _localCache,
        phone: phone,
        learnerId: learnerId,
        onboardingCompleted: true,
      );
    }

    if (updates != null && updates.containsKey('student_name')) {
      await RosterSync.patchRow(
        _localCache,
        phone: phone,
        learnerId: learnerId,
        studentName: updates['student_name'] as String?,
      );
    }

    final refreshed = await _learnerStateRepository.fetchState(
      learnerId: learnerId,
      forceRefresh: true,
    );
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      refreshed.toJson(),
    );
    return refreshed;
  }

  bool isOnboardingCompleted(String learnerId, {bool fallback = false}) =>
      fallback ||
      _localCache.getForeverRaw(
            CacheKeys.onboardingCompleted(learnerId),
          )?['completed'] ==
          true;

  List<ProfileSummaryModel> _withLocalOnboardingState(
    List<ProfileSummaryModel> profiles,
  ) => profiles
      .map(
        (profile) =>
            isOnboardingCompleted(
              profile.learnerId,
              fallback: profile.onboardingCompleted,
            )
            ? profile.copyWith(onboardingCompleted: true)
            : profile,
      )
      .toList(growable: false);

  Future<void> _markOnboardingCompleted(String learnerId) =>
      _localCache.setForeverRaw(CacheKeys.onboardingCompleted(learnerId), {
        'completed': true,
      });
}

final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final learnerStateRepository = await ref.watch(
    learnerStateRepositoryProvider.future,
  );
  return ProfileRepository(
    ref.watch(httpClientProvider),
    localCache,
    learnerStateRepository,
  );
});

class ProfilesPageRequest {
  const ProfilesPageRequest({
    required this.phone,
    this.page = 1,
    this.pageSize = 10,
  });
  final String phone;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is ProfilesPageRequest &&
      other.phone == phone &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(phone, page, pageSize);
}

final profilesPageDataProvider = FutureProvider.autoDispose
    .family<List<ProfileSummaryModel>, ProfilesPageRequest>((
      ref,
      request,
    ) async {
      final repository = await ref.watch(profileRepositoryProvider.future);
      final cached = await repository.readCachedProfilesPage(
        request.phone,
        request.page,
        request.pageSize,
      );
      try {
        return await repository.fetchProfilesPage(
          phone: request.phone,
          page: request.page,
          pageSize: request.pageSize,
          forceRefresh: true,
        );
      } catch (_) {
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    });

final selectProfileProvider = FutureProvider.autoDispose
    .family<LearnerStateModel, ({String phone, String learnerId})>((
      ref,
      args,
    ) async {
      final repository = await ref.watch(profileRepositoryProvider.future);
      return repository.selectProfile(
        phone: args.phone,
        learnerId: args.learnerId,
      );
    });

final activeProfileProvider = FutureProvider<ActiveProfileModel?>((ref) async {
  final repository = await ref.watch(profileRepositoryProvider.future);
  final secureTokenStore = ref.watch(secureTokenStoreProvider);
  final phone = await secureTokenStore.readPhone();
  if (phone == null || phone.isEmpty) return null;
  return repository.readActiveProfile(phone);
});

Future<void> setActiveProfile(WidgetRef ref, ActiveProfileModel profile) async {
  final repository = await ref.read(profileRepositoryProvider.future);
  await repository.setActiveProfile(profile);
  ref.invalidate(activeProfileProvider);
  unawaited(_warmCache(ref, profile));
}

Future<void> clearActiveProfile(WidgetRef ref) async {
  final repository = await ref.read(profileRepositoryProvider.future);
  final secureTokenStore = ref.read(secureTokenStoreProvider);
  final phone = await secureTokenStore.readPhone();
  if (phone != null && phone.isNotEmpty) {
    await repository.clearActiveProfile(phone);
  }
  ref.invalidate(activeProfileProvider);
}

Future<void> _warmCache(WidgetRef ref, ActiveProfileModel profile) async {
  try {
    final learnerStateRepository = await ref.read(
      learnerStateRepositoryProvider.future,
    );
    final learnerState = await learnerStateRepository.fetchState(
      learnerId: profile.learnerId,
    );
    final courseId = learnerState.enrollment?.course;
    if (courseId == null) return;

    final lang = ref.read(languageProvider);
    final flowManifestRepository = await ref.read(
      flowManifestRepositoryProvider.future,
    );
    final courseRepository = await ref.read(
      courseRepositoryProvider.future,
    );
    final flowRepository = await ref.read(flowRepositoryProvider.future);

    await Future.wait([
      flowManifestRepository.load(lang),
      courseRepository.fetchCourseIndex(lang: lang),
      courseRepository.fetchCourseDetail(courseId, lang: lang),
    ]);

    await flowRepository.loadFlow(
      category: 'activity',
      fileName: 'activity_flow.json',
      languageCode: lang,
    );
  } catch (_) {
    return;
  }
}