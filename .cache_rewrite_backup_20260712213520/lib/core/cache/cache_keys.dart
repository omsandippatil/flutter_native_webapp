class CacheKeys {
  CacheKeys._();

  static String flow(String lang, String category, String fileName) =>
      'flow:$lang:$category:$fileName';

  static String flowManifest() => 'flow:manifest';

  static String authSession(String phone) => 'auth:$phone:session';

  static String profilesPage(String phone, int page, int pageSize) =>
      'profiles:$phone:page$page:$pageSize';

  static String profilesSearch(
    String phone, {
    String? grade,
    String? division,
    String? rollNumber,
    String? query,
    int page = 1,
  }) =>
      'profiles:$phone:search:${grade ?? '*'}:${division ?? '*'}:${rollNumber ?? '*'}:${query ?? '*'}:$page';

  static String learnerState(String learnerId) => 'learner:$learnerId:state';

  static String roster(String phone, {String? grade, String? division, String? query}) =>
      'roster:$phone:${grade ?? '*'}:${division ?? '*'}:${query ?? '*'}';

  static String students(String phone, {String? grade, String? division, int page = 1}) =>
      'students:$phone:${grade ?? '*'}:${division ?? '*'}:$page';

  static String studentSearch(String phone, String grade, String rollNumber, String division) =>
      'students:$phone:search:$grade:$rollNumber:$division';

  static String achievements(String learnerId) => 'achievements:$learnerId';

  static String submissionReview(String learnerId, String question, String submissionText) =>
      'review:$learnerId:${Object.hash(question, submissionText)}';

  static String chatTranscript(String phone, String learnerId) => 'chat:$phone:$learnerId';

  static String languageSetting() => 'settings:language_code';
}
