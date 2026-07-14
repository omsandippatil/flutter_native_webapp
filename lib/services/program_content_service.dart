import '../data/repositories/program_content_repository.dart';
import '../models/program_content/course_detail_model.dart';
import '../models/program_content/course_index_entry_model.dart';

class ProgramContentService {
  ProgramContentService(this._repository);

  final ProgramContentRepository _repository;

  Future<List<CourseIndexEntryModel>> fetchCourseIndex({
    String lang = 'en',
    bool forceRefresh = false,
  }) =>
      _repository.fetchCourseIndex(lang: lang, forceRefresh: forceRefresh);

  Future<CourseDetailModel> fetchCourseDetail(
    String courseId, {
    String lang = 'en',
    bool forceRefresh = false,
  }) =>
      _repository.fetchCourseDetail(courseId, lang: lang, forceRefresh: forceRefresh);
}
