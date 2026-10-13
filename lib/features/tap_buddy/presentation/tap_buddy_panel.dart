import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tapapp/chat/chat.dart';
import 'package:tapapp/core/localization/language.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/features/tap_buddy/tap_buddy.dart';

class TapBuddyPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const TapBuddyPanel({super.key, required this.onClose});

  @override
  ConsumerState<TapBuddyPanel> createState() => _TapBuddyPanelState();
}

class _TapBuddyPanelState extends ConsumerState<TapBuddyPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatAudioPlaybackController _audioController;

  final List<ChatTurnModel> _messages = [];
  bool _historyLoaded = false;
  bool _isSending = false;
  String? _pendingRetryMessage;
  String? _errorText;
  int _seq = 0;

  String? _phone;
  String? _learnerId;

  @override
  void initState() {
    super.initState();
    _audioController = ChatAudioPlaybackController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _audioController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final phone = await ref.read(secureTokenStoreProvider).readPhone();
    if (phone == null) return;

    final activeProfile = await ref
        .read(profileRepositoryProvider.future)
        .then((repository) => repository.readActiveProfile(phone));
    if (!mounted || activeProfile == null) return;

    final repository = await ref.read(tapbuddyChatRepositoryProvider.future);
    final resolvedProfile = activeProfile;
    final transcript = await repository.readTranscript(
      resolvedProfile.phone,
      resolvedProfile.learnerId,
    );

    if (!mounted) return;
    setState(() {
      _phone = activeProfile.phone;
      _learnerId = activeProfile.learnerId;
      _messages.addAll(transcript);
      _historyLoaded = true;
    });
  }

  String _nextId() => 'tapbuddy:${_seq++}';

  // Maps TAP Buddy's plain {role, content} transcript onto the same
  // ChatItem model every other surface (onboarding/classroom) renders,
  // so bubbles, avatar, spacing and audio affordance all come from the
  // one shared block registry instead of a bespoke implementation here.
  List<ChatItem> _buildItems() {
    final items = <ChatItem>[
      for (final turn in _messages)
        TextItem(
          id: _nextId(),
          stepId: 'tapbuddy',
          sender: turn.role == 'user' ? ChatSender.user : ChatSender.bot,
          text: turn.content,
        ),
      if (_messages.isEmpty) ...[
        TextItem(
          id: _nextId(),
          stepId: 'tapbuddy',
          sender: ChatSender.bot,
          text: 'Hey there Champ!\nHow may I help you?',
        ),
        TextItem(
          id: _nextId(),
          stepId: 'tapbuddy',
          sender: ChatSender.bot,
          text: "Type your question below and I'll help you out.",
        ),
      ],
      if (_isSending)
        LoadingItem(id: _nextId(), stepId: 'tapbuddy'),
      if (_errorText != null)
        ErrorItem(
          id: _nextId(),
          stepId: 'tapbuddy',
          message: _errorText!,
          retryAction: ChatAction.retrySubmission.name,
        ),
    ];
    return items;
  }

  ChatRenderContext _renderContext() => ChatRenderContext(
    onAction: (action, {data}) {
      if (action == ChatAction.retrySubmission) {
        unawaited(_send(_pendingRetryMessage));
      }
    },
    onOptionSelected: (_, _) {},
    onSubmissionAnswer: (_, _) {},
    onRetry: (_) => unawaited(_send(_pendingRetryMessage)),
    audioController: _audioController,
    isAwaitingInput: !_isSending,
  );

  Future<void> _send([String? retryText]) async {
    final text = (retryText ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;
    if (_phone == null || _learnerId == null) return;

    setState(() {
      _isSending = true;
      _errorText = null;
      _pendingRetryMessage = null;
      if (retryText == null) {
        _messages.add(ChatTurnModel.user(text));
        _inputController.clear();
      }
    });
    _scrollToBottom();

    try {
      final repository = await ref.read(tapbuddyChatRepositoryProvider.future);
      final languageCode = ref.read(languageProvider);
      final context = await ref.read(tapBuddyContextProvider.future);

      final reply = await repository.sendMessage(
        phone: _phone!,
        learnerId: _learnerId!,
        message: text,
        grade: context.grade,
        language: languageCode,
        context: context.toJson(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add(ChatTurnModel.assistant(reply));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = "Couldn't reach TAP Buddy. Please try again.";
        _pendingRetryMessage = text;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 560 ? (width * 0.82).clamp(292.0, 330.0) : 330.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: SafeArea(
            left: false,
            child: Column(
              children: [
                _PanelHeader(onClose: widget.onClose),
                const Divider(height: 1, color: Color(0xFFE8E8EF)),
                Expanded(
                  child: !_historyLoaded
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : ChatListView(
                          items: _buildItems(),
                          renderContext: _renderContext(),
                          scrollController: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                        ),
                ),
                ChatInputBar(
                  mode: (_historyLoaded && !_isSending)
                      ? ChatInputMode.text
                      : ChatInputMode.none,
                  enabled: _historyLoaded && !_isSending,
                  hintText: 'Type here...',
                  onSubmitText: (_) => _send(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Image.asset(
              'assets/images/branding/tap_buddy_pp.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAP Buddy',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C21),
                    ),
                  ),
                  Text(
                    'YOUR LEARNING DIDI',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF777887),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: const Color(0xFF777887),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F1F5),
                fixedSize: const Size(32, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
