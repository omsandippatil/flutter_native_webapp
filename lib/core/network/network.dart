import "package:tapapp/core/constants/app_constants.dart";
import "package:tapapp/core/storage/storage.dart";
import "package:dio/dio.dart";

class ApiEndpoints {
  ApiEndpoints._();
  static const String checkPhone = "/auth/check-phone";
  static const String login = "/auth/login";
  static const String forgotPasswordSendOtp = "/auth/forgot-password/send-otp";
  static const String forgotPasswordVerifyOtp = "/auth/forgot-password/verify-otp";
  static const String resetPassword = "/auth/reset-password";
  static const String profiles = "/profiles";
  static const String profilesSearch = "/profiles/search";
  static const String profilesSelect = "/profiles/select";
  static const String profilesAvatar = "/profiles/avatar";
  static const String profilesUpdate = "/profiles/update";
  static const String studentsSearch = "/students/search";
  static const String students = "/students";
  static const String studentsUpdate = "/students/update";
  static const String studentsBulkUpdate = "/students/bulk-update";
  static const String learnerState = "/learner/state";
  static const String learnerEnroll = "/learner/enroll";
  static const String learnerSubmitProgress = "/learner/submit-progress";
  static const String tapbuddyChat = "/tapbuddy/chat";
  static const String submissionReview = "/submission-review/review";
  static const String onboardingComplete = "/onboarding/complete";
}

class AuthException implements Exception {
  AuthException(this.code);
  final String code;
  bool get requiresReLogin => code == "token_phone_mismatch" || code == "invalid_signature";
  @override
  String toString() => "AuthException($code)";
}

class RateLimitedException implements Exception {
  RateLimitedException(this.bucket);
  final String bucket;
  static String bucketForPath(String path) {
    if (path.startsWith("/auth/forgot-password/send-otp")) return "otp";
    if (path.startsWith("/tapbuddy/chat") || path.startsWith("/submission-review/review")) return "groq";
    return "default";
  }
  @override
  String toString() => "RateLimitedException($bucket)";
}

class HttpClient {
  HttpClient(this._tokenStore) {
    _dio.options.baseUrl = AppConstants.workerBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.contentType = Headers.jsonContentType;
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStore.readToken();
        if (token != null) options.headers["Authorization"] = "Bearer $token";
        handler.next(options);
      },
      onResponse: (response, handler) async {
        await _persistTokenIfPresent(response.data);
        handler.next(response);
      },
      onError: (error, handler) async {
        await _persistTokenIfPresent(error.response?.data);
        handler.next(error);
      },
    ));
  }

  final Dio _dio = Dio();
  final TokenStore _tokenStore;

  Future<void> _persistTokenIfPresent(dynamic data) async {
    if (data is Map && data["token"] is String) {
      await _tokenStore.saveRefreshedToken(data["token"] as String);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _send("GET", path, query: query);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) => _send("POST", path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? query, Map<String, dynamic>? body}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        queryParameters: method == "GET" ? query : null,
        data: method == "GET" ? null : body,
        options: Options(method: method),
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
      if (status == 401) throw AuthException(map["error"] as String? ?? "invalid_or_expired_token");
      if (status == 429) throw RateLimitedException(RateLimitedException.bucketForPath(path));
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
