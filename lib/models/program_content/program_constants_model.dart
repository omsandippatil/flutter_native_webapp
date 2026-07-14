class ProgramConstantsModel {
  const ProgramConstantsModel({
    required this.supportedVerticals,
    required this.maxCoursesPerProfile,
    required this.defaultLanguageCode,
  });

  final List<String> supportedVerticals;
  final int maxCoursesPerProfile;
  final String defaultLanguageCode;

  factory ProgramConstantsModel.fromJson(Map<String, dynamic> json) => ProgramConstantsModel(
        supportedVerticals:
            (json['supported_verticals'] as List?)?.whereType<String>().toList() ?? const [],
        maxCoursesPerProfile: (json['max_courses_per_profile'] as num?)?.toInt() ?? 1,
        defaultLanguageCode: json['default_language_code'] as String? ?? 'en',
      );

  Map<String, dynamic> toJson() => {
        'supported_verticals': supportedVerticals,
        'max_courses_per_profile': maxCoursesPerProfile,
        'default_language_code': defaultLanguageCode,
      };
}
