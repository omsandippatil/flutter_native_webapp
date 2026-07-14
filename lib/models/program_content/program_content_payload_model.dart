import 'course_index_entry_model.dart';

class ProgramContentPayloadModel {
  const ProgramContentPayloadModel({
    required this.courseIndex,
    required this.resolvedLanguage,
    required this.isFallback,
  });

  final List<CourseIndexEntryModel> courseIndex;
  final String resolvedLanguage;
  final bool isFallback;
}
