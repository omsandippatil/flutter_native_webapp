import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/constants/app_constants.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/core/storage/storage.dart';

import 'package:flutter/services.dart' show rootBundle;

class CourseIndexEntryModel {
  const CourseIndexEntryModel({
    required this.id,
    required this.name,
    required this.vertical,
    required this.level,
    required this.kitLess,
    required this.unitsCount,
  });

  final String id;
  final String name;
  final String vertical;
  final String level;
  final bool kitLess;
  final int unitsCount;

  factory CourseIndexEntryModel.fromJson(Map<String, dynamic> j) =>
      CourseIndexEntryModel(
        id: j['id'] as String? ?? j['_id'] as String? ?? '',
        name: j['nm'] as String? ?? j['name'] as String? ?? '',
        vertical: j['vrt'] as String? ?? '',
        level: j['lvl'] as String? ?? '',
        kitLess: j['kit_less'] as bool? ?? false,
        unitsCount: (j['units_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nm': name,
        'vrt': vertical,
        'lvl': level,
        'kit_less': kitLess,
        'units_count': unitsCount,
      };
}

class CourseVideoModel {
  const CourseVideoModel({
    required this.id,
    required this.name,
    required this.description,
    required this.youtubeId,
    required this.points,
    required this.duration,
  });

  final int id;
  final String name;
  final String description;
  final String youtubeId;
  final int points;
  final String duration;

  factory CourseVideoModel.fromJson(Map<String, dynamic> j) =>
      CourseVideoModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['nm'] as String? ?? j['name'] as String? ?? '',
        description: j['desc'] as String? ?? '',
        youtubeId: j['yt'] as String? ?? '',
        points: (j['pts'] as num?)?.toInt() ?? 0,
        duration: j['dur'] as String? ?? '',
      );
}

class CourseQuizQuestionModel {
  const CourseQuizQuestionModel({
    required this.question,
    required this.options,
    required this.answerKey,
    required this.hint,
    required this.explanation,
    required this.points,
  });

  final String question;
  final Map<String, String> options;
  final String answerKey;
  final String hint;
  final String explanation;
  final int points;

  factory CourseQuizQuestionModel.fromJson(Map<String, dynamic> j) {
    final rawOpts = j['opts'] ?? j['options'];
    final opts = <String, String>{};
    if (rawOpts is Map) {
      rawOpts.forEach((k, v) => opts[k.toString()] = v.toString());
    }
    return CourseQuizQuestionModel(
      question: j['q'] as String? ?? j['question'] as String? ?? '',
      options: opts,
      answerKey: j['ans'] as String? ?? j['answer_key'] as String? ?? '',
      hint: j['hnt'] as String? ?? j['hint'] as String? ?? '',
      explanation: j['exp'] as String? ?? j['explanation'] as String? ?? '',
      points: (j['pts'] as num?)?.toInt() ?? 0,
    );
  }
}

class CourseQuizModel {
  const CourseQuizModel({
    required this.id,
    required this.name,
    required this.questions,
  });

  final int id;
  final String name;
  final List<CourseQuizQuestionModel> questions;

  factory CourseQuizModel.fromJson(Map<String, dynamic> j) {
    final rawQs = j['qs'] ?? j['questions'];
    final qs = rawQs is List
        ? rawQs.whereType<Map>().map((m) => CourseQuizQuestionModel.fromJson(Map<String, dynamic>.from(m))).toList()
        : <CourseQuizQuestionModel>[];
    return CourseQuizModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['nm'] as String? ?? j['name'] as String? ?? '',
      questions: qs,
    );
  }
}

class CourseAssignmentStepModel {
  const CourseAssignmentStepModel({
    required this.step,
    required this.label,
    required this.subTypes,
    this.guidedText,
    required this.unguidedText,
    this.validCriteria,
  });

  final int step;
  final String label;
  final String subTypes;
  final String? guidedText;
  final String unguidedText;
  final String? validCriteria;

  factory CourseAssignmentStepModel.fromJson(Map<String, dynamic> j) =>
      CourseAssignmentStepModel(
        step: (j['step'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? '',
        subTypes: j['sub_types'] as String? ?? '',
        guidedText: j['guided_text'] as String?,
        unguidedText: j['unguided_text'] as String? ?? '',
        validCriteria: j['valid_criteria'] as String?,
      );
}

class CourseAssignmentModel {
  const CourseAssignmentModel({
    required this.id,
    required this.seq,
    required this.name,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.steps,
  });

  final String id;
  final int seq;
  final String name;
  final String description;
  final String type;
  final String difficulty;
  final List<CourseAssignmentStepModel> steps;

  factory CourseAssignmentModel.fromJson(Map<String, dynamic> j) {
    final rawSteps = j['steps'];
    final steps = rawSteps is List
        ? rawSteps.whereType<Map>().map((m) => CourseAssignmentStepModel.fromJson(Map<String, dynamic>.from(m))).toList()
        : <CourseAssignmentStepModel>[];
    return CourseAssignmentModel(
      id: j['id'] as String? ?? j['_id'] as String? ?? '',
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      name: j['nm'] as String? ?? j['name'] as String? ?? '',
      description: j['desc'] as String? ?? '',
      type: j['type'] as String? ?? '',
      difficulty: j['diff'] as String? ?? '',
      steps: steps,
    );
  }
}

class CourseUnitModel {
  const CourseUnitModel({
    required this.name,
    required this.description,
    required this.difficulty,
    required this.xp,
    required this.videos,
    this.quiz,
    required this.assignments,
  });

  final String name;
  final String description;
  final String difficulty;
  final int xp;
  final List<CourseVideoModel> videos;
  final CourseQuizModel? quiz;
  final List<CourseAssignmentModel> assignments;

  factory CourseUnitModel.fromJson(Map<String, dynamic> j) {
    final rawVids = j['vids'] ?? j['videos'];
    final vids = rawVids is List
        ? rawVids.whereType<Map>().map((m) => CourseVideoModel.fromJson(Map<String, dynamic>.from(m))).toList()
        : <CourseVideoModel>[];
    final rawQuiz = j['quiz'];
    final quiz = rawQuiz is Map ? CourseQuizModel.fromJson(Map<String, dynamic>.from(rawQuiz)) : null;
    final rawAssigns = j['assigns'] ?? j['assignments'];
    final assigns = rawAssigns is List
        ? rawAssigns.whereType<Map>().map((m) => CourseAssignmentModel.fromJson(Map<String, dynamic>.from(m))).toList()
        : <CourseAssignmentModel>[];
    return CourseUnitModel(
      name: j['nm'] as String? ?? j['name'] as String? ?? '',
      description: j['desc'] as String? ?? '',
      difficulty: j['diff'] as String? ?? '',
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      videos: vids,
      quiz: quiz,
      assignments: assigns,
    );
  }
}

class CourseDetailModel {
  const CourseDetailModel({
    required this.id,
    required this.name,
    required this.vertical,
    required this.level,
    required this.kitLess,
    required this.description,
    required this.units,
  });

  final String id;
  final String name;
  final String vertical;
  final String level;
  final bool kitLess;
  final String description;
  final List<CourseUnitModel> units;

  factory CourseDetailModel.fromJson(Map<String, dynamic> j) {
    final rawUnits = j['units'];
    final units = rawUnits is List
        ? rawUnits.whereType<Map>().map((m) => CourseUnitModel.fromJson(Map<String, dynamic>.from(m))).toList()
        : <CourseUnitModel>[];
    return CourseDetailModel(
      id: j['id'] as String? ?? j['_id'] as String? ?? '',
      name: j['nm'] as String? ?? j['name'] as String? ?? '',
      vertical: j['vrt'] as String? ?? '',
      level: j['lvl'] as String? ?? '',
      kitLess: j['kit_less'] as bool? ?? false,
      description: j['desc'] as String? ?? '',
      units: units,
    );
  }
}

class CourseRepository {
  CourseRepository(this._localCache);

  final LocalCache _localCache;

  Future<List<CourseIndexEntryModel>> fetchCourseIndex({required String lang}) async {
    final cacheKey = CacheKeys.courseIndex(lang);
    final cached = _localCache.getForeverRaw(cacheKey);
    if (cached != null) {
      final list = cached['entries'];
      if (list is List) {
        return list.whereType<Map>().map((m) => CourseIndexEntryModel.fromJson(Map<String, dynamic>.from(m))).toList();
      }
    }
    try {
      final raw = await rootBundle.loadString('assets/data/courses/$lang/index.json');
      final decoded = jsonDecode(raw);
      final entries = decoded is List ? decoded : (decoded is Map ? decoded['courses'] ?? decoded['entries'] ?? [] : []);
      final models = (entries as List).whereType<Map>().map((m) => CourseIndexEntryModel.fromJson(Map<String, dynamic>.from(m))).toList();
      await _localCache.setForeverRaw(cacheKey, {'entries': models.map((e) => e.toJson()).toList()});
      return models;
    } catch (_) {
      return const [];
    }
  }

  Future<CourseDetailModel?> fetchCourseDetail(String courseId, {required String lang}) async {
    final cacheKey = CacheKeys.courseDetail(courseId, lang);
    final cached = _localCache.getForeverRaw(cacheKey);
    if (cached != null) {
      try {
        return CourseDetailModel.fromJson(cached);
      } catch (_) {}
    }
    try {
      final raw = await rootBundle.loadString('assets/data/courses/$lang/$courseId.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final model = CourseDetailModel.fromJson(decoded);
      await _localCache.setForeverRaw(cacheKey, decoded);
      return model;
    } catch (_) {
      return null;
    }
  }
}

final courseRepositoryProvider = FutureProvider<CourseRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return CourseRepository(localCache);
});

final courseIndexDataProvider = FutureProvider.autoDispose.family<List<CourseIndexEntryModel>, String>((ref, lang) async {
  final repo = await ref.watch(courseRepositoryProvider.future);
  return repo.fetchCourseIndex(lang: lang);
});

final courseDetailDataProvider = FutureProvider.autoDispose.family<CourseDetailModel?, String>((ref, courseId) async {
  final repo = await ref.watch(courseRepositoryProvider.future);
  return repo.fetchCourseDetail(courseId, lang: AppConstants.defaultLanguageCode);
});
