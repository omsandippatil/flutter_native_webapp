import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapapp/chat/chat.dart';
import 'package:tapapp/core/localization/language.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/router/router.dart';
import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/features/onboarding/onboarding.dart';
import 'package:tapapp/shared/widgets/app_header.dart';
import 'package:tapapp/shared/widgets/loading_view.dart';

const Map<String, String> _editStepFieldKeys = {
  'OF-005-EDIT-NAME': 'name',
  'OF-005-EDIT-PHONE': 'phone',
};

const String _courseChoiceStepId = 'OF-002-COURSE';
const String _academicEditStepId = 'OF-005-EDIT-ACADEMIC';

class ConversationalOnboardingScreen extends ConsumerStatefulWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  ConsumerState<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends ConsumerState<ConversationalOnboardingScreen> {
  ChatSessionKey? _sessionKey;
  StreamSubscription<CrossFlowTarget>? _crossFlowSub;
  late final OnboardingChatActionHandler _actionHandler;

  @override
  void initState() {
    super.initState();
    _actionHandler = OnboardingChatActionHandler(ref: ref);
  }

  @override
  void dispose() {
    _crossFlowSub?.cancel();
    final key = _sessionKey;
    if (key != null) {
      ChatSessionDepsRegistry.unregister(key);
    }
    super.dispose();
  }

  void _subscribeCrossFlow(ChatSessionKey key) {
    if (_crossFlowSub != null) return;
    final notifier = ref.read(chatSessionProvider(key).notifier);
    final session = notifier.session;
    if (session == null) return;
    _crossFlowSub = session.crossFlowTarget.listen((target) {
      if (!mounted) return;
      if (target.category == 'activity') {
        context.go(AppRoutes.classroom);
      }
    });
  }

  Future<void> _onOptionSelected(String stepId, String optionKey) async {
    if (stepId == _courseChoiceStepId) {
      final result = await _actionHandler.handle(
        ChatAction.enrollCourse,
        data: {'optionKey': optionKey},
      );
      final payload = result.payload;
      if (result.success && payload != null) {
        final key = _sessionKey;
        if (key != null) {
          ref.read(chatSessionProvider(key).notifier).session?.variables
              .addAll(payload);
        }
      }
      return;
    }
    if (stepId == 'OF-005-EDIT-LANG') {
      unawaited(_actionHandler.handle(
        ChatAction.saveProfile,
        data: {'values': {'language': optionKey}},
      ));
    }
  }

  Future<void> _onSubmissionAnswer(String stepId, Object answer) async {
    if (answer is! Map) return;

    final fieldKey = _editStepFieldKeys[stepId];
    if (fieldKey != null) {
      final value = answer.values.isEmpty ? '' : answer.values.first;
      unawaited(_actionHandler.handle(
        ChatAction.saveProfile,
        data: {'values': {fieldKey: value?.toString() ?? ''}},
      ));
      return;
    }

    if (stepId == _academicEditStepId) {
      unawaited(_actionHandler.handle(
        ChatAction.saveProfile,
        data: {'values': answer},
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfileAsync = ref.watch(activeProfileProvider);

    return activeProfileAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (err, stack) => const Scaffold(
        body: Center(child: Text('Could not load your profile.')),
      ),
      data: (activeProfile) {
        if (activeProfile == null) {
          return const Scaffold(
            body: Center(child: Text('No active profile found.')),
          );
        }

        final languageCode = ref.watch(languageProvider);
        final key = ChatSessionKey(
          profileId: activeProfile.learnerId,
          surface: 'onboarding',
          category: 'onboarding',
          fileName: 'onboarding_flow.json',
          entryStepId: 'OF-001',
          languageCode: languageCode,
        );
        _sessionKey = key;

        if (ChatSessionDepsRegistry.lookup(key) == null) {
          ChatSessionDepsRegistry.register(
            key,
            ChatSessionDeps(
              actionHandler: _actionHandler,
              templateContext: TemplateContext(
                studentName: activeProfile.studentName ?? 'there',
                unitName: '',
                courseDisplay: '',
              ),
              contentSource: OnboardingChatContentSource(ref: ref),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _subscribeCrossFlow(key);
        });

        final sessionState = ref.watch(chatSessionProvider(key));
        if (!sessionState.ready) return const Scaffold(body: LoadingView());

        final notifier = ref.read(chatSessionProvider(key).notifier);
        final baseCtx = notifier.renderContext(
          studentName: activeProfile.studentName ?? 'there',
        );
        final ctx = baseCtx.copyWith(
          onOptionSelected: (stepId, optionKey) {
            baseCtx.onOptionSelected(stepId, optionKey);
            unawaited(_onOptionSelected(stepId, optionKey));
          },
          onSubmissionAnswer: (stepId, answer) {
            baseCtx.onSubmissionAnswer(stepId, answer);
            unawaited(_onSubmissionAnswer(stepId, answer));
          },
        );

        return Scaffold(
          backgroundColor: AppTheme.onboardingBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeaderBack(
                  title: 'TAP Onboarding',
                  onBack: () {
                    if (notifier.session?.canGoBack == true) {
                      notifier.goBack();
                    }
                  },
                ),
                Expanded(
                  child: ChatLayout.resolve(
                    context: context,
                    mode: ChatLayoutMode.column,
                    chatList: ChatListView(
                      items: sessionState.items,
                      renderContext: ctx,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}