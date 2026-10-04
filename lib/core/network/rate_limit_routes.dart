class RateLimitRoutes {
  RateLimitRoutes._();

  static const List<String> otpRoutePrefixes = ['/auth/forgot-password/send-otp'];

  static const List<String> groqRoutePrefixes = [
    '/tapbuddy/chat',
    '/submission-review/review',
  ];
}
