import 'course_index_entry_model.dart';

class ProgramLangBundleModel {
  const ProgramLangBundleModel({required this.languageCode, required this.courses});

  final String languageCode;
  final List<CourseIndexEntryModel> courses;

  factory ProgramLangBundleModel.fromJson(String languageCode, Map<String, dynamic> json) =>
      ProgramLangBundleModel(
        languageCode: languageCode,
        courses: CourseIndexEntryModel.listFromJson(json['courses']),
      );
}
