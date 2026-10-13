import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/providers.dart';

enum ProfileTab { profile, settings, about }

class AboutTapLoader {
  const AboutTapLoader();

  static const String assetPath = 'assets/profile-screen/about_tap.json';

  Future<Map<String, dynamic>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

class ProfileFormController {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final language = TextEditingController();
  final grade = TextEditingController();

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    language.dispose();
    grade.dispose();
  }

  void sync({
    required ActiveProfileModel? activeProfile,
    required LearnerStateModel? learnerState,
  }) {
    final fullName =
        (learnerState?.profile?.studentName ?? activeProfile?.studentName ?? '')
            .trim();
    final parts = fullName.isEmpty
        ? <String>[]
        : fullName.split(RegExp(r'\s+'));

    firstName.text = parts.isNotEmpty ? parts.first : '';
    lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    language.text = learnerState?.profile?.language ?? '';
    grade.text = activeProfile?.grade ?? '';
  }

  String get fullName => [
    firstName.text.trim(),
    lastName.text.trim(),
  ].where((value) => value.isNotEmpty).join(' ');

  String get languageValue => language.text.trim();

  String get gradeValue => grade.text.trim();

  Map<String, dynamic> toUpdates() {
    final updates = <String, dynamic>{};
    if (fullName.isNotEmpty) updates['student_name'] = fullName;
    if (languageValue.isNotEmpty) updates['language'] = languageValue;
    if (gradeValue.isNotEmpty) updates['grade'] = gradeValue;
    return updates;
  }
}

class ProfileSettingsSnapshot {
  const ProfileSettingsSnapshot({this.activeProfile, this.learnerState});

  final ActiveProfileModel? activeProfile;
  final LearnerStateModel? learnerState;
}

class ProfileSaveResult {
  const ProfileSaveResult({
    required this.learnerState,
    required this.updatedProfile,
  });

  final LearnerStateModel learnerState;
  final ActiveProfileModel? updatedProfile;
}

class ProfileSettingsActions {
  const ProfileSettingsActions();

  Future<ProfileSettingsSnapshot> load(WidgetRef ref) async {
    final repository = await ref.read(profileRepositoryProvider.future);
    final phone = await ref.read(secureTokenStoreProvider).readPhone();
    final activeProfile = phone == null
        ? null
        : await repository.readActiveProfile(phone);
    if (activeProfile == null) {
      return const ProfileSettingsSnapshot();
    }

    final learnerStateRepository = await ref.read(
      learnerStateRepositoryProvider.future,
    );
    final learnerState =
        await learnerStateRepository.readCached(activeProfile.learnerId) ??
        await learnerStateRepository.fetchState(
          learnerId: activeProfile.learnerId,
        );

    return ProfileSettingsSnapshot(
      activeProfile: activeProfile,
      learnerState: learnerState,
    );
  }

  Future<ProfileSaveResult> save({
    required WidgetRef ref,
    required String phone,
    required ActiveProfileModel activeProfile,
    required Map<String, dynamic> updates,
    required String fullName,
    required String grade,
  }) async {
    final repository = await ref.read(profileRepositoryProvider.future);
    final updatedState = await repository.updateProfile(
      phone: phone,
      learnerId: activeProfile.learnerId,
      updates: updates,
    );

    ActiveProfileModel? updatedProfile;
    if (updates.containsKey('student_name') || updates.containsKey('grade')) {
      updatedProfile = ActiveProfileModel(
        phone: phone,
        learnerId: activeProfile.learnerId,
        studentName: updates.containsKey('student_name')
            ? fullName
            : activeProfile.studentName,
        grade: updates.containsKey('grade') ? grade : activeProfile.grade,
        division: activeProfile.division,
        avatar: activeProfile.avatar,
        onboardingCompleted: activeProfile.onboardingCompleted,
      );
      await repository.setActiveProfile(updatedProfile);
    }

    return ProfileSaveResult(
      learnerState: updatedState,
      updatedProfile: updatedProfile,
    );
  }

  Future<ProfileSettingsSnapshot> switchProfile({
    required WidgetRef ref,
    required String phone,
    required ProfileSummaryModel profile,
  }) async {
    final repository = await ref.read(profileRepositoryProvider.future);
    final learnerState = await repository.selectProfile(
      phone: phone,
      learnerId: profile.learnerId,
    );

    final activeProfile = ActiveProfileModel(
      phone: phone,
      learnerId: profile.learnerId,
      studentName: learnerState.profile?.studentName ?? profile.studentName,
      grade: profile.grade,
      division: profile.division,
      avatar: profile.avatar,
      onboardingCompleted: profile.onboardingCompleted,
    );
    await repository.setActiveProfile(activeProfile);

    return ProfileSettingsSnapshot(
      activeProfile: activeProfile,
      learnerState: learnerState,
    );
  }
}
