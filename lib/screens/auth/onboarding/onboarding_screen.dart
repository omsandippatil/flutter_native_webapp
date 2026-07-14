import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/router.dart';
import '../../../data/models/active_profile_model.dart';
import '../../../data/models/learner_state_model.dart';
import '../../../data/repositories/achievements_repository.dart';
import '../../../data/repositories/learner_state_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../models/program_content/course_index_entry_model.dart';
import '../../../providers/achievements_provider.dart';
import '../../../providers/learner_state_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/program_content_provider.dart';

class ChatBubble {
  final String sender;
  final String text;
  final Widget? customContent;
  final bool hasVoice;

  ChatBubble({
    required this.sender,
    required this.text,
    this.customContent,
    this.hasVoice = false,
  });
}

class VerticalOption {
  const VerticalOption({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
  });

  final String id;
  final String label;
  final String emoji;
  final String description;
}

const List<VerticalOption> _kVerticalOptions = [
  VerticalOption(
    id: 'science-lab',
    label: 'Science Lab',
    emoji: '🔬',
    description: 'Hands-on electronics and experiments',
  ),
  VerticalOption(
    id: 'coding',
    label: 'Coding',
    emoji: '💻',
    description: 'Build games and apps step by step',
  ),
  VerticalOption(
    id: 'financial-literacy',
    label: 'Financial Literacy',
    emoji: '📈',
    description: 'Learn how money really works',
  ),
  VerticalOption(
    id: 'arts',
    label: 'Arts',
    emoji: '🎨',
    description: 'Sketch, paint, and express yourself',
  ),
];

String _verticalLabel(String? verticalId) {
  final match = _kVerticalOptions.where((v) => v.id == verticalId);
  if (match.isNotEmpty) return match.first.label;
  return verticalId ?? '';
}

String _thumbnailFor(String courseId) =>
    'assets/data/courses/thumbnail/$courseId.webp';

class ConversationalOnboardingScreen extends ConsumerStatefulWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  ConsumerState<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends ConsumerState<ConversationalOnboardingScreen> {
  final List<ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isVoiceMuted = false;

  Map<String, Map<String, dynamic>> _allSteps = {};
  bool _isLoadingFlows = true;
  String? _loadError;

  late ActiveProfileModel _activeProfile;
  LearnerStateModel? _learnerState;

  ProfileRepository? _profileRepository;
  LearnerStateRepository? _learnerStateRepository;
  AchievementsRepository? _achievementsRepository;

  List<CourseIndexEntryModel> _courseIndex = [];

  String _currentStepId = 'OF-001';
  final Map<String, dynamic> _pendingProfileUpdates = {};
  String? _selectedVerticalId;
  String? _selectedCourseId;

  bool _isBotTyping = false;
  bool _showTextInput = false;
  String _textInputHint = 'Type here...';
  Widget? _currentInteractionWidget;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final profileRepository = await ref.read(profileRepositoryProvider.future);
      final learnerStateRepository = await ref.read(learnerStateRepositoryProvider.future);
      final achievementsRepository = await ref.read(achievementsRepositoryProvider.future);
      final programContentRepository =
          await ref.read(programContentRepositoryProvider.future);

      final activeProfile = await profileRepository.readActiveProfile();
      if (activeProfile == null) {
        setState(() {
          _loadError = 'No active profile found. Please sign in again.';
          _isLoadingFlows = false;
        });
        return;
      }

      final learnerState = await learnerStateRepository.fetchState(
        learnerId: activeProfile.learnerId,
      );

      final courseIndex = await programContentRepository.fetchCourseIndex();

      final onboardingStr = await rootBundle.loadString(
        'assets/flows/en/onboarding/student_onboarding.json',
      );

      final onboardingJson = jsonDecode(onboardingStr) as Map<String, dynamic>;

      final Map<String, Map<String, dynamic>> stepsMap = {};
      for (final step in onboardingJson['steps']) {
        stepsMap[step['step_id']] = step as Map<String, dynamic>;
      }

      setState(() {
        _profileRepository = profileRepository;
        _learnerStateRepository = learnerStateRepository;
        _achievementsRepository = achievementsRepository;
        _activeProfile = activeProfile;
        _learnerState = learnerState;
        _courseIndex = courseIndex;
        _selectedCourseId = learnerState.enrollment?.course;
        _selectedVerticalId = _verticalIdForCourse(_selectedCourseId);
        _allSteps = stepsMap;
        _isLoadingFlows = false;
      });

      _executeStep();
    } catch (e) {
      debugPrint('Error bootstrapping onboarding: $e');
      setState(() {
        _loadError = 'Something went wrong loading your profile.';
        _isLoadingFlows = false;
      });
    }
  }

  String? _verticalIdForCourse(String? courseId) {
    if (courseId == null) return null;
    final match = _courseIndex.where((c) => c.id == courseId);
    if (match.isEmpty) return null;
    return match.first.vertical;
  }

  List<CourseIndexEntryModel> get _coursesInSelectedVertical {
    if (_selectedVerticalId == null) return const [];
    return _courseIndex.where((c) => c.vertical == _selectedVerticalId).toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get _studentName =>
      _learnerState?.profile?.studentName ?? _activeProfile.studentName ?? 'there';

  String get _studentPhone => _activeProfile.phone;

  void _executeStep() {
    final step = _allSteps[_currentStepId];
    if (step == null) return;

    setState(() {
      _isBotTyping = true;
      _currentInteractionWidget = null;
      _showTextInput = false;
    });

    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      setState(() {
        _isBotTyping = false;
      });

      _processStep(step);
      _scrollToBottom();
    });
  }

  void _processStep(Map<String, dynamic> step) {
    final String inputMode = step['input_mode'] ?? 'static';
    final String? component = step['component'];

    String text = step['display_text'] ?? '';

    text = text
        .replaceAll('{{name}}', _studentName)
        .replaceAll('{{phone}}', _studentPhone)
        .replaceAll('{{vertical_display}}', _verticalLabelSelected())
        .replaceAll('{{course_display}}', _getCourseDisplayName(_selectedCourseId));

    Widget? customContent;
    if (text.contains('[confetti]') || _currentStepId == 'OF-004') {
      text = text.replaceAll('[confetti]', '').trim();
      customContent = _buildCelebrateCard();
    }

    if (component == 'ProfileVerifyCard') {
      customContent = _buildProfileVerifyCard();
    }

    if (text.isNotEmpty) {
      final List<String> parts = text.split('|');
      for (int i = 0; i < parts.length; i++) {
        final p = parts[i].trim();
        if (p.isNotEmpty) {
          setState(() {
            _messages.add(
              ChatBubble(
                sender: 'bot',
                text: p,
                customContent: (i == parts.length - 1) ? customContent : null,
                hasVoice: step.containsKey('audio_id'),
              ),
            );
          });
        }
      }
    } else if (customContent != null) {
      setState(() {
        _messages.add(
          ChatBubble(
            sender: 'bot',
            text: '',
            customContent: customContent,
            hasVoice: step.containsKey('audio_id'),
          ),
        );
      });
    }

    if (component == 'VerticalSelectCard') {
      setState(() {
        _currentInteractionWidget = _buildVerticalSelectionInteraction();
      });
      return;
    }

    if (component == 'CourseSelectCard') {
      setState(() {
        _currentInteractionWidget = _buildCourseSelectionInteraction();
      });
      return;
    }

    if (inputMode == 'free_text') {
      setState(() {
        _showTextInput = true;
        _textInputHint = _fieldHintFor(_currentStepId);
      });
    } else if (inputMode == 'buttons_only' || inputMode == 'radio') {
      final List<dynamic>? options = step['options'];
      if (options != null) {
        if (_currentStepId == 'OF-005') {
          setState(() {
            _currentInteractionWidget = _buildProfileVerifyButtons(options);
          });
        } else if (_currentStepId == 'OF-005-EDIT') {
          setState(() {
            _currentInteractionWidget = _buildEditFieldPicker(options);
          });
        } else if (_currentStepId == 'OF-005-EDIT-LANG') {
          setState(() {
            _currentInteractionWidget = _buildButtonsInteraction(options, (
              selectedValue,
              nextStepId,
            ) {
              _addUserMessage(_labelFor(options, selectedValue));
              _pendingProfileUpdates['language'] = selectedValue;
              _currentStepId = nextStepId ?? 'OF-005';
              _commitProfileUpdates();
            });
          });
        } else {
          setState(() {
            _currentInteractionWidget = _buildButtonsInteraction(options, (
              selectedValue,
              nextStepId,
            ) {
              final selectedOption = options.firstWhere(
                (opt) => opt['value'] == selectedValue,
              );
              _addUserMessage(selectedOption['label'] ?? selectedValue);

              if (selectedOption.containsKey('next_flow')) {
                if (selectedOption['next_flow'] == 'activity_flow') {
                  Timer(const Duration(milliseconds: 1000), () {
                    if (mounted) context.go(AppRoutes.home);
                  });
                } else {
                  _finishOnboarding();
                }
                return;
              }

              if (selectedValue == 'repick') {
                _selectedVerticalId = null;
                _selectedCourseId = null;
              }

              if (nextStepId != null) {
                _currentStepId = nextStepId;
              } else if (step.containsKey('next_step')) {
                _currentStepId = step['next_step'];
              }
              _executeStep();
            });
          });
        }
      }
    } else if (inputMode == 'form') {
      setState(() {
        _currentInteractionWidget = _buildAcademicForm(step);
      });
    } else if (inputMode == 'static') {
      if (step.containsKey('next_step') && step['next_step'] != null) {
        _currentStepId = step['next_step'];
        _executeStep();
      } else if (step.containsKey('next_flow')) {
        if (step['next_flow'] == 'activity_flow') {
          Timer(const Duration(milliseconds: 1500), () {
            if (mounted) context.go(AppRoutes.home);
          });
        }
      }
    }
  }

  String _fieldHintFor(String stepId) {
    switch (stepId) {
      case 'OF-005-EDIT-NAME':
        return 'Type the correct name...';
      case 'OF-005-EDIT-PHONE':
        return 'Phone number cannot be changed';
      default:
        return 'Type your answer...';
    }
  }

  String _labelFor(List<dynamic> options, String value) {
    final match = options.firstWhere(
      (opt) => opt['value'] == value,
      orElse: () => {'label': value},
    );
    return match['label']?.toString() ?? value;
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatBubble(sender: 'user', text: text));
    });
    _scrollToBottom();
  }

  String _verticalLabelSelected() => _verticalLabel(_selectedVerticalId);

  String _getCourseDisplayName(String? courseId) {
    if (courseId == null) return '';
    final match = _courseIndex.where((c) => c.id == courseId);
    if (match.isEmpty) return courseId;
    return match.first.name;
  }

  Future<void> _enrollInCourse(String courseId) async {
    final repository = _learnerStateRepository;
    if (repository == null) return;
    try {
      final updated = await repository.enrollCourse(
        learnerId: _activeProfile.learnerId,
        course: courseId,
      );
      setState(() {
        _learnerState = updated;
        _selectedCourseId = courseId;
      });
      ref.invalidate(learnerStateDataProvider(_activeProfile.learnerId));
    } catch (e) {
      debugPrint('Enroll failed: $e');
      _showErrorSnack('Could not save your course selection. Please try again.');
    }
  }

  Future<void> _commitProfileUpdates() async {
    final repository = _profileRepository;
    if (repository == null || _pendingProfileUpdates.isEmpty) {
      _executeStep();
      return;
    }
    final updates = Map<String, dynamic>.from(_pendingProfileUpdates);
    _pendingProfileUpdates.clear();
    try {
      final updated = await repository.updateProfile(
        phone: _activeProfile.phone,
        learnerId: _activeProfile.learnerId,
        updates: updates,
      );
      setState(() {
        _learnerState = updated;
      });
      ref.invalidate(learnerStateDataProvider(_activeProfile.learnerId));
      if (updates.containsKey('student_name')) {
        await _profileRepository?.setActiveProfile(
          ActiveProfileModel(
            phone: _activeProfile.phone,
            learnerId: _activeProfile.learnerId,
            studentName: updates['student_name'] as String,
            grade: _activeProfile.grade,
            division: _activeProfile.division,
            avatar: _activeProfile.avatar,
          ),
        );
      }
    } catch (e) {
      debugPrint('Profile update failed: $e');
      _showErrorSnack('Could not save that change. Please try again.');
    }
    _executeStep();
  }

  Future<void> _awardOnboardingCompletionBonus() async {
    final repository = _achievementsRepository;
    if (repository == null) return;
    try {
      await repository.awardAchievement(
        learnerId: _activeProfile.learnerId,
        achievement: 'onboarding_complete',
        level: 1,
      );
    } catch (e) {
      debugPrint('Achievement award failed: $e');
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleTextSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_currentStepId == 'OF-005-EDIT-PHONE') {
      _inputController.clear();
      return;
    }

    _inputController.clear();
    _addUserMessage(text);

    final step = _allSteps[_currentStepId];
    if (step == null) return;

    if (_currentStepId == 'OF-005-EDIT-NAME') {
      _pendingProfileUpdates['student_name'] = text;
      _currentStepId = step['next_step'] ?? 'OF-005';
      _commitProfileUpdates();
      return;
    }

    if (step.containsKey('next_step')) {
      _currentStepId = step['next_step'];
      _executeStep();
    }
  }

  Widget _buildButtonsInteraction(
    List<dynamic> options,
    Function(String, String?) onSelect,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFFF8F9FD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: options.map((opt) {
          final label = opt['label']?.toString() ?? '';
          final val = opt['value']?.toString() ?? '';
          final nextStep = opt['next_step']?.toString();

          final isPrimary =
              val == 'confirm' || val == 'yes' || val == 'start' || val == 'start_learning';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ElevatedButton(
                onPressed: () => onSelect(val, nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPrimary ? const Color(0xFF5B5BD6) : const Color(0xFFE8E8FB),
                  foregroundColor: isPrimary ? Colors.white : const Color(0xFF5B5BD6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVerticalSelectionInteraction() {
    String? localSelected = _selectedVerticalId;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF8F9FD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _kVerticalOptions.length,
                itemBuilder: (context, index) {
                  final vertical = _kVerticalOptions[index];
                  final isSelected = localSelected == vertical.id;
                  final availableCount = _courseIndex
                      .where((c) => c.vertical == vertical.id)
                      .length;

                  return GestureDetector(
                    onTap: () {
                      setLocalState(() => localSelected = vertical.id);
                      setState(() => _selectedVerticalId = vertical.id);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE8E8FB) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5B5BD6)
                              : const Color(0xFFE8E8FB),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vertical.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  vertical.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1C1C21),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  vertical.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF6E6E7A),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Text(
                                  '$availableCount courses',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5B5BD6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF198754),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: localSelected == null
                      ? null
                      : () {
                          setState(() {
                            _messages.add(
                              ChatBubble(
                                sender: 'bot',
                                text: '',
                                customContent:
                                    _buildVerticalSelectionSnapshot(localSelected!),
                              ),
                            );
                            _currentInteractionWidget = null;
                          });
                          _addUserMessage(_verticalLabel(localSelected));
                          _currentStepId = 'OF-002-COURSE';
                          _executeStep();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B5BD6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBDC3C7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseSelectionInteraction() {
    String? localSelected = _selectedCourseId;
    final courses = _coursesInSelectedVertical;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF8F9FD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  final isSelected = localSelected == course.id;

                  return GestureDetector(
                    onTap: () {
                      setLocalState(() => localSelected = course.id);
                      setState(() => _selectedCourseId = course.id);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE8E8FB) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5B5BD6)
                              : const Color(0xFFE8E8FB),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.5,
                                child: Image.asset(
                                  _thumbnailFor(course.id),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: const Color(0xFFF1F1F5),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: Color(0xFFB9BBC8),
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1C1C21),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${course.unitsCount} units',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF6E6E7A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF198754),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          _addUserMessage('Change track');
                          _selectedVerticalId = null;
                          _selectedCourseId = null;
                          _currentStepId = 'OF-002';
                          _executeStep();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B5BD6),
                          side: const BorderSide(color: Color(0xFF5B5BD6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Change track',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: localSelected == null
                            ? null
                            : () {
                                setState(() {
                                  _messages.add(
                                    ChatBubble(
                                      sender: 'bot',
                                      text: '',
                                      customContent:
                                          _buildCourseSelectionSnapshot(localSelected!),
                                    ),
                                  );
                                  _currentInteractionWidget = null;
                                });
                                _addUserMessage(
                                  _getCourseDisplayName(localSelected),
                                );
                                _currentStepId = 'OF-003';
                                _executeStep();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B5BD6),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFBDC3C7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalSelectionSnapshot(String selectedId) {
    final vertical = _kVerticalOptions.firstWhere((v) => v.id == selectedId);
    final availableCount =
        _courseIndex.where((c) => c.vertical == vertical.id).length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B5BD6), width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(vertical.emoji, style: const TextStyle(fontSize: 24)),
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF198754),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vertical.label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vertical.description,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF6E6E7A),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$availableCount courses',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5B5BD6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSelectionSnapshot(String selectedCourseId) {
    final match = _courseIndex.where((c) => c.id == selectedCourseId);
    if (match.isEmpty) return const SizedBox.shrink();
    final course = match.first;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B5BD6), width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: Image.asset(
                  _thumbnailFor(course.id),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF1F1F5),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Color(0xFFB9BBC8),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF198754),
                  size: 20,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C21),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.unitsCount} units',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF6E6E7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileVerifyButtons(List<dynamic> options) {
    return _buildButtonsInteraction(options, (selectedValue, nextStepId) {
      final selectedOption = options.firstWhere((opt) => opt['value'] == selectedValue);
      _addUserMessage(selectedOption['label'] ?? selectedValue);

      if (selectedValue == 'confirm') {
        _enrollInCourse(_selectedCourseId ?? '').then((_) {
          _currentStepId = nextStepId ?? 'OF-006';
          _executeStep();
        });
        return;
      }

      _currentStepId = nextStepId ?? 'OF-005-EDIT';
      _executeStep();
    });
  }

  Widget _buildEditFieldPicker(List<dynamic> options) {
    final editableOptions = options
        .where((opt) => opt['value'] != 'edit_phone' && opt['value'] != 'edit_academic')
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFFF8F9FD),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: editableOptions.map((opt) {
          final label = opt['label']?.toString() ?? '';
          final val = opt['value']?.toString() ?? '';
          return OutlinedButton(
            onPressed: () {
              _addUserMessage(label);
              switch (val) {
                case 'edit_name':
                  _currentStepId = 'OF-005-EDIT-NAME';
                  break;
                case 'edit_language':
                  _currentStepId = 'OF-005-EDIT-LANG';
                  break;
                default:
                  _currentStepId = 'OF-005-EDIT-ACADEMIC';
              }
              _executeStep();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B5BD6),
              side: const BorderSide(color: Color(0xFF5B5BD6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAcademicForm(Map<String, dynamic> step) {
    final gradeController = TextEditingController(text: _activeProfile.grade ?? '');
    final divisionController = TextEditingController(text: _activeProfile.division ?? '');
    final rollController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF8F9FD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFormTextField('Grade', gradeController),
              const SizedBox(height: 12),
              _buildFormTextField('Division', divisionController),
              const SizedBox(height: 12),
              _buildFormTextField('Roll Number', rollController),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    _addUserMessage('Updated grade / division / roll number');
                    if (gradeController.text.trim().isNotEmpty) {
                      _pendingProfileUpdates['grade'] = gradeController.text.trim();
                    }
                    if (divisionController.text.trim().isNotEmpty) {
                      _pendingProfileUpdates['division'] =
                          divisionController.text.trim().toUpperCase();
                    }
                    if (rollController.text.trim().isNotEmpty) {
                      _pendingProfileUpdates['roll_number'] = rollController.text.trim();
                    }
                    _currentStepId = step['next_step'] ?? 'OF-005';
                    _commitProfileUpdates();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B5BD6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormTextField(String label, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8FB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: const Color(0xFF6E6E7A), fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCelebrateCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 280),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/onboarding/sussess_celebrate.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.celebration,
            size: 120,
            color: Color(0xFF5B5BD6),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileVerifyCard() {
    final profile = _learnerState?.profile;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileRow('Name', _studentName),
          const Divider(height: 16),
          _buildProfileRow('Phone', _studentPhone, locked: true),
          const Divider(height: 16),
          _buildProfileRow('Language', profile?.language ?? '—'),
          const Divider(height: 16),
          _buildProfileRow('Course', _getCourseDisplayName(_selectedCourseId)),
          const Divider(height: 16),
          _buildProfileRow('School', profile?.school ?? '—', locked: true),
          const Divider(height: 16),
          _buildProfileRow('Grade', _activeProfile.grade ?? '—'),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, {bool locked = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6E6E7A),
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C21),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF6E6E7A)),
            ],
          ],
        ),
      ],
    );
  }

  void _finishOnboarding() {
    _awardOnboardingCompletionBonus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Setup Complete! 🎉',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF5B5BD6), size: 80),
              const SizedBox(height: 16),
              Text(
                '$_studentName is now successfully enrolled in ${_getCourseDisplayName(_selectedCourseId)}!',
                style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6E6E7A)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.home);
              },
              child: Text(
                'Start Learning',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B5BD6),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    if (_isLoadingFlows) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF5B5BD6)),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6E6E7A)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E8FB), height: 1.0),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/logos/gov-logo.png',
              height: 36,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/logos/tap_logo.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            const Spacer(),
            Text(
              'TAP Onboarding',
              style: GoogleFonts.inter(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C21),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicatorBubble();
                      }

                      final message = _messages[index];
                      final isBot = message.sender == 'bot';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (isBot)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFE8E8FB),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/onboarding/TAP-bot.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.android, color: Color(0xFF5B5BD6)),
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment:
                                    isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  if (message.text.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: isDesktop ? 480 : size.width * 0.78,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isBot
                                                ? const Color(0xFFF1F1F5)
                                                : const Color(0xFFE8FAF1),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(20),
                                              topRight: const Radius.circular(20),
                                              bottomLeft: isBot
                                                  ? const Radius.circular(4)
                                                  : const Radius.circular(20),
                                              bottomRight: isBot
                                                  ? const Radius.circular(20)
                                                  : const Radius.circular(4),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  message.text,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: isBot
                                                        ? const Color(0xFF1C1C21)
                                                        : const Color(0xFF0F5132),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                              if (isBot && message.hasVoice) ...[
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _isVoiceMuted = !_isVoiceMuted;
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Icon(
                                                      _isVoiceMuted
                                                          ? Icons.volume_off_rounded
                                                          : Icons.volume_up_rounded,
                                                      size: 18,
                                                      color: const Color(0xFF5B5BD6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (!isBot)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4.0, bottom: 4.0),
                                            child: Icon(
                                              Icons.done_all,
                                              size: 16,
                                              color: Color(0xFF198754),
                                            ),
                                          ),
                                      ],
                                    ),
                                  if (message.customContent != null)
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: isDesktop ? 450 : size.width * 0.75,
                                      ),
                                      child: message.customContent!,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _currentInteractionWidget ?? const SizedBox.shrink(),
                if (_showTextInput)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE8E8FB), width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _currentStepId == 'OF-005-EDIT-PHONE'
                                  ? const Color(0xFFF1F1F5).withValues(alpha: 0.5)
                                  : const Color(0xFFF1F1F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocusNode,
                              enabled: _currentStepId != 'OF-005-EDIT-PHONE',
                              decoration: InputDecoration(
                                hintText: _textInputHint,
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF6E6E7A),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => _handleTextSubmit(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: _currentStepId == 'OF-005-EDIT-PHONE'
                              ? null
                              : _handleTextSubmit,
                          backgroundColor: const Color(0xFF5B5BD6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          child: const Icon(Icons.send, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE8E8FB),
              child: ClipOval(
                child: Image.asset(
                  'assets/onboarding/TAP-bot.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.android, color: Color(0xFF5B5BD6)),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F5),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildDot(), _buildDot(), _buildDot()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: Color(0xFF6E6E7A),
        shape: BoxShape.circle,
      ),
    );
  }
}