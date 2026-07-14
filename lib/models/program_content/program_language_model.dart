class ProgramLanguageModel {
  const ProgramLanguageModel({required this.languageCode, required this.availableCourseIds});

  final String languageCode;
  final List<String> availableCourseIds;

  factory ProgramLanguageModel.fromJson(Map<String, dynamic> json) => ProgramLanguageModel(
        languageCode: json['language_code'] as String? ?? 'en',
        availableCourseIds:
            (json['available_course_ids'] as List?)?.whereType<String>().toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'language_code': languageCode,
        'available_course_ids': availableCourseIds,
      };
}
