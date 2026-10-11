import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:tapapp/core/learner/learner.dart";
import "package:tapapp/core/network/network.dart";
import "package:tapapp/core/profile/profile.dart";
import "package:tapapp/core/providers.dart";
import "package:tapapp/core/storage/storage.dart";

class AuthSessionModel {
  const AuthSessionModel({required this.phone, this.teacher, this.adminCode});
  final String phone;
  final String? teacher;
  final String? adminCode;
  factory AuthSessionModel.fromJson(Map<String, dynamic> json) => AuthSessionModel(
    phone: json["phone"] as String, teacher: json["teacher"] as String?, adminCode: json["admin_code"] as String?,
  );
  Map<String, dynamic> toJson() => {"phone": phone, "teacher": teacher, "admin_code": adminCode};
}

class AuthRepository {
  AuthRepository(this._http, this._localCache, this._tokenStore);
  final HttpClient _http;
  final LocalCache _localCache;
  final TokenStore _tokenStore;

  Future<Map<String, dynamic>> checkPhone(String phone) => _http.post(ApiEndpoints.checkPhone, body: {"phone": phone});

  Future<Map<String, dynamic>> login({required String phone, required String password}) async {
    final data = await _http.post(ApiEndpoints.login, body: {"phone": phone, "password": password});
    if (data["success"] == true) await _persistLoginPayload(data);
    return data;
  }

  Future<Map<String, dynamic>> sendForgotPasswordOtp(String phone) =>
      _http.post(ApiEndpoints.forgotPasswordSendOtp, body: {"phone": phone});

  Future<Map<String, dynamic>> verifyForgotPasswordOtp({required String phone, required String otp}) =>
      _http.post(ApiEndpoints.forgotPasswordVerifyOtp, body: {"phone": phone, "otp": otp});

  Future<Map<String, dynamic>> resetPassword({required String phone, required String newPassword, required String resetToken}) async {
    await _tokenStore.saveRefreshedToken(resetToken);
    final data = await _http.post(ApiEndpoints.resetPassword, body: {"phone": phone, "password": newPassword});
    if (data["success"] == true) await _persistLoginPayload(data);
    return data;
  }

  Future<AuthSessionModel?> readCachedSession(String phone) async {
    final raw = _localCache.getForeverRaw(CacheKeys.authSession(phone));
    return raw == null ? null : AuthSessionModel.fromJson(raw);
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    await _localCache.clearAll();
  }

  Future<void> _persistLoginPayload(Map<String, dynamic> data) async {
    final phone = data["phone"] as String;
    final token = data["token"] as String;
    final adminCode = data["admin_code"] as String?;
    await _tokenStore.saveSession(phone: phone, token: token, adminCode: adminCode);
    final session = AuthSessionModel.fromJson(data);
    await _localCache.setForeverRaw(CacheKeys.authSession(phone), session.toJson());
    final rawProfiles = data["profiles"];
    if (rawProfiles is List) {
      final summaries = <ProfileSummaryModel>[];
      for (final raw in rawProfiles.whereType<Map>()) {
        try { summaries.add(ProfileSummaryModel.fromJson(phone, Map<String, dynamic>.from(raw))); } catch (_) { continue; }
      }
      await _localCache.setForeverRawList(
        CacheKeys.profilesPage(phone, data["page"] as int? ?? 1, data["page_size"] as int? ?? 10),
        ProfileSummaryModel.listToJson(summaries),
      );
      for (final raw in rawProfiles.whereType<Map>()) {
        final learnerId = raw["learner_id"] as String?;
        final state = raw["state"];
        if (learnerId == null || state is! Map) continue;
        try {
          final model = LearnerStateModel.fromFullJson(learnerId, Map<String, dynamic>.from(state));
          await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
        } catch (_) { continue; }
      }
    }
  }
}

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final localCache = await ref.read(localCacheProvider.future);
  return AuthRepository(ref.read(httpClientProvider), localCache, ref.read(secureTokenStoreProvider));
});

final authSessionDataProvider = FutureProvider.family<AuthSessionModel?, String>((ref, phone) async {
  final repository = await ref.read(authRepositoryProvider.future);
  return repository.readCachedSession(phone);
});
