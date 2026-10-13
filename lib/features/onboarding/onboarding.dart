import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/chat/chat.dart';
import 'package:tapapp/core/course/course.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/providers.dart';

class LearningTrackOption {
  const LearningTrackOption({
    required this.id,
    required this.label,
    required this.description,
    required this.emoji,
  });

  final String id;
  final String label;
  final String description;
  final String emoji;
}

const learningTrackOptions = <LearningTrackOption>[
  LearningTrackOption(
    id: 'science-lab',
    label: 'Science Lab',
    description: 'Hands-on electronics and experiments',
    emoji: '🔬',
  ),
  LearningTrackOption(
    id: 'coding',
    label: 'Coding',
    description: 'Build games and apps step by step',
    emoji: '💻',
  ),
  LearningTrackOption(
    id: 'financial-literacy',
    label: 'Financial Literacy',
    description: 'Learn how money really works',
    emoji: '📈',
  ),
  LearningTrackOption(
    id: 'arts',
    label: 'Visual Arts',
    description: 'Sketch, paint, and express yourself',
    emoji: '🎨',
  ),
];

String learningTrackLabel(String? trackId) {
  for (final option in learningTrackOptions) {
    if (option.id == trackId) return option.label;
  }
  return trackId ?? '';
}

String onboardingCourseThumbnail(String courseId) =>
    'assets/data/courses/thumbnail/$courseId.webp';

List<ChatOption> buildTrackOptions() => learningTrackOptions
    .map((track) => ChatOption(key: track.id, label: track.label))
    .toList(growable: false);

List<ChatOption> buildCourseOptions(
  List<CourseIndexEntryModel> courses,
) => courses
    .map(
      (course) => ChatOption(
        key: course.id,
        label: course.name,
        imagePath: onboardingCourseThumbnail(course.id),
      ),
    )
    .toList(growable: false);

Map<String, Object?> confirmMeta(String label) => {'confirmLabel': label};

class OnboardingChatActionHandler implements ChatActionHandler {
  OnboardingChatActionHandler({required this.ref});

  final WidgetRef ref;

  Future<String?> _phone() => ref.read(secureTokenStoreProvider).readPhone();

  @override
  Future<ChatActionResult> handle(
    ChatAction action, {
    Map<String, Object?>? data,
  }) {
    switch (action) {
      case ChatAction.enrollCourse:
        return _enrollCourse(data);
      case ChatAction.saveProfile:
        return _saveProfile(data);
      case ChatAction.completeOnboarding:
        return _completeOnboarding(data);
      default:
        return Future.value(ChatActionResult.ok());
    }
  }

  Future<ChatActionResult> _enrollCourse(Map<String, Object?>? data) async {
    final phone = await _phone();
    if (phone == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final activeProfile = await profileRepository.readActiveProfile(phone);
    if (activeProfile == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final courseId =
        (data?['optionKey'] ?? data?['selected_course'] ?? data?['courseId'] ?? data?['selectedCourse'])
            ?.toString();
    if (courseId == null || courseId.isEmpty) {
      return ChatActionResult.failure('No course selected.');
    }

    try {
      final repository = await ref.read(courseRepositoryProvider.future);
      final course = await repository.fetchCourseDetail(courseId, lang: 'en');
      await profileRepository.completeOnboarding(
        phone: phone,
        learnerId: activeProfile.learnerId,
        course: courseId,
        markComplete: false,
      );
      ref.invalidate(learnerStateDataProvider(activeProfile.learnerId));
      return ChatActionResult.ok(
        payload: {
          'selectedCourse': courseId,
          'course_display': course?.name ?? courseId,
        },
      );
    } catch (_) {
      return ChatActionResult.failure(
        'Could not save your course selection. Please try again.',
      );
    }
  }

  Future<ChatActionResult> _saveProfile(Map<String, Object?>? data) async {
    final phone = await _phone();
    if (phone == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final activeProfile = await profileRepository.readActiveProfile(phone);
    if (activeProfile == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final updates = <String, dynamic>{};
    final raw = data?['values'] ?? data?['updates'] ?? data;
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value == null) return;
        if (key == 'stepId') return;
        switch (key.toString()) {
          case 'name':
            updates['student_name'] = value.toString();
          case 'language':
            updates['language'] = value.toString();
          case 'class':
            updates['grade'] = value.toString();
          case 'school':
            updates['school'] = value.toString();
          case 'subject':
            updates['subject'] = value.toString();
          default:
            updates[key.toString()] = value;
        }
      });
    }

    if (updates.isEmpty) return ChatActionResult.ok();

    try {
      final updatedState = await profileRepository.updateProfile(
        phone: phone,
        learnerId: activeProfile.learnerId,
        updates: updates,
      );
      ref.invalidate(learnerStateDataProvider(activeProfile.learnerId));

      if (updates.containsKey('student_name') || updates.containsKey('grade')) {
        final updatedProfile = ActiveProfileModel(
          phone: phone,
          learnerId: activeProfile.learnerId,
          studentName: updates['student_name'] as String? ?? activeProfile.studentName,
          grade: updates['grade'] as String? ?? activeProfile.grade,
          division: activeProfile.division,
          avatar: activeProfile.avatar,
          onboardingCompleted: activeProfile.onboardingCompleted,
        );
        await setActiveProfile(ref, updatedProfile);
      }

      return ChatActionResult.ok(payload: updatedState.toJson());
    } catch (_) {
      return ChatActionResult.failure('Could not save that change. Please try again.');
    }
  }

  Future<ChatActionResult> _completeOnboarding(
    Map<String, Object?>? data,
  ) async {
    final phone = await _phone();
    if (phone == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final activeProfile = await profileRepository.readActiveProfile(phone);
    if (activeProfile == null) {
      return ChatActionResult.failure('No active profile found.');
    }

    final courseId =
        (data?['selectedCourse'] ?? data?['selected_course'] ?? data?['courseId'])?.toString();

    try {
      await profileRepository.completeOnboarding(
        phone: phone,
        learnerId: activeProfile.learnerId,
        course: courseId,
        markComplete: true,
      );

      final learnerStateRepository = await ref.read(
        learnerStateRepositoryProvider.future,
      );
      await learnerStateRepository.prepareLocalUnit(
        learnerId: activeProfile.learnerId,
        unitIndex: 0,
      );

      final updatedProfile = activeProfile.copyWith(
        onboardingCompleted: true,
      );
      await setActiveProfile(ref, updatedProfile);
      ref.invalidate(learnerStateDataProvider(activeProfile.learnerId));

      return ChatActionResult.ok();
    } catch (_) {
      return ChatActionResult.failure(
        'Could not finish setting up your account. Please try again.',
      );
    }
  }
}

class OnboardingChatContentSource implements ChatContentSource {
  OnboardingChatContentSource({required this.ref});

  final WidgetRef ref;

  @override
  Set<ChatItemKind> get boundKinds => const {
    ChatItemKind.choice,
    ChatItemKind.profileVerify,
    ChatItemKind.scorecard,
  };

  @override
  Future<ChatItem?> bind(FlowNode node, ChatBindContext ctx) async {
    switch (node.component) {
      case 'VerticalSelectCard':
        return _trackChoice(node, ctx);
      case 'CourseSelectCard':
        return _courseChoice(node, ctx);
      case 'ProfileVerifyCard':
        return _profileVerify(node, ctx);
      case 'SkillPassportCard':
        return _scorecard(node, ctx);
    }
    return null;
  }

  ChatItem _trackChoice(FlowNode node, ChatBindContext ctx) {
    return ChoiceItem(
      id: ctx.id,
      stepId: node.stepId,
      layout: 'cards',
      options: buildTrackOptions(),
      meta: confirmMeta('Continue'),
    );
  }

  Future<ChatItem> _courseChoice(FlowNode node, ChatBindContext ctx) async {
    final repository = await ref.read(courseRepositoryProvider.future);
    final selectedVertical = ctx.variables['selected_vertical'] as String?;
    final index = await repository.fetchCourseIndex(lang: 'en');
    final filtered = selectedVertical == null
        ? index
        : index
              .where((course) => course.vertical == selectedVertical)
              .toList(growable: false);

    return ChoiceItem(
      id: ctx.id,
      stepId: node.stepId,
      layout: 'cards',
      options: buildCourseOptions(filtered.isEmpty ? index : filtered),
      meta: confirmMeta('Continue'),
    );
  }

  Future<ChatItem> _profileVerify(FlowNode node, ChatBindContext ctx) async {
    final phone = await ref.read(secureTokenStoreProvider).readPhone();
    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final activeProfile = phone == null
        ? null
        : await profileRepository.readActiveProfile(phone);

    final learnerStateRepository = await ref.read(
      learnerStateRepositoryProvider.future,
    );
    final learnerState = activeProfile == null
        ? null
        : await learnerStateRepository.readCached(activeProfile.learnerId);

    String resolve(String variableKey, String? fallback) {
      final override = ctx.variables[variableKey] as String?;
      if (override != null && override.isNotEmpty) return override;
      return fallback ?? '';
    }

    final fields = <String, String>{
      'name': resolve(
        'name',
        learnerState?.profile?.studentName ?? activeProfile?.studentName,
      ),
      'phone': resolve('phone', activeProfile?.phone),
      'language': resolve('language', learnerState?.profile?.language),
      'school': resolve('school', learnerState?.profile?.schoolName),
      'class': resolve('class', activeProfile?.grade),
      'subject': resolve('subject', activeProfile?.division),
    };

    return ProfileVerifyItem(
      id: ctx.id,
      stepId: node.stepId,
      fields: fields,
      editable: true,
    );
  }

  ChatItem _scorecard(FlowNode node, ChatBindContext ctx) {
    final points = (node.data['points_awarded'] as num?)?.toInt() ?? 0;
    return ScorecardItem(
      id: ctx.id,
      stepId: node.stepId,
      rows: [ScoreRow(label: 'Joining bonus', value: '+$points pts')],
      total: '+$points pts',
    );
  }
}