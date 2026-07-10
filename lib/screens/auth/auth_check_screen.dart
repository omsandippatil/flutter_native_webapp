import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';

class StudentProfile {
  final String id;
  final String name;
  final String grade;
  final String school;
  final String course;
  final int avatarIndex;

  const StudentProfile({
    required this.id,
    required this.name,
    required this.grade,
    required this.school,
    required this.course,
    required this.avatarIndex,
  });
}

class _AuthMessage {
  final String sender;
  final String text;

  const _AuthMessage({required this.sender, required this.text});
}

enum _AuthStage { phone, notFound, otp, profileSelect, ready }

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final List<_AuthMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  _AuthStage _stage = _AuthStage.phone;
  bool _isBotTyping = false;
  bool _isLoading = false;
  String _phone = '';
  StudentProfile? _selectedProfile;
  List<StudentProfile> _profiles = const [];

  static const List<StudentProfile> _demoProfiles = [
    StudentProfile(
      id: 'profile-aarav',
      name: 'Aarav',
      grade: 'Class 6',
      school: 'MCD Primary School',
      course: 'Science',
      avatarIndex: 0,
    ),
    StudentProfile(
      id: 'profile-anaya',
      name: 'Anaya',
      grade: 'Class 4',
      school: 'MCD Primary School',
      course: 'Coding',
      avatarIndex: 1,
    ),
    StudentProfile(
      id: 'profile-kabir',
      name: 'Kabir',
      grade: 'Class 7',
      school: 'MCD Senior School',
      course: 'Visual Arts',
      avatarIndex: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    await _botSay("Hi champ, let's find your TAP profile.");
    await _botSay('What phone number is linked with your school account?');
  }

  Future<void> _botSay(String text) async {
    setState(() {
      _isBotTyping = true;
    });
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _isBotTyping = false;
      _messages.add(_AuthMessage(sender: 'bot', text: text));
    });
    _scrollToBottom();
  }

  void _userSay(String text) {
    setState(() {
      _messages.add(_AuthMessage(sender: 'user', text: text));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSubmit() async {
    final value = _inputController.text.trim();
    if (value.isEmpty || _isLoading) return;

    _inputController.clear();

    if (_stage == _AuthStage.phone) {
      await _handlePhone(value);
    } else if (_stage == _AuthStage.otp) {
      await _handleOtp(value);
    }
  }

  Future<void> _handlePhone(String value) async {
    final phone = value.replaceAll(RegExp(r'\D'), '');
    _userSay(value);

    if (phone.length < 3) {
      await _botSay('That number looks too short. Can you check it once?');
      return;
    }

    setState(() {
      _isLoading = true;
      _phone = phone;
    });

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    final profiles = _profilesForPhone(phone);
    if (profiles.isEmpty) {
      setState(() {
        _stage = _AuthStage.notFound;
      });
      await _botSay("I couldn't find a TAP profile with this number.");
      await _botSay('Try another number, or ask your teacher for help.');
      return;
    }

    setState(() {
      _profiles = profiles;
      _stage = _AuthStage.otp;
    });
    await _botSay('Great, I found your TAP account.');
    await _botSay('I sent a 4-digit code to $_phone. Type it here.');
  }

  Future<void> _handleOtp(String value) async {
    _userSay(value.replaceAll(RegExp(r'.'), '•'));

    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (value != '1234') {
      await _botSay("That code doesn't look right. Try 1234 for this demo.");
      return;
    }

    if (_profiles.length == 1) {
      final profile = _profiles.first;
      setState(() {
        _selectedProfile = profile;
        _stage = _AuthStage.ready;
      });
      await _botSay('Verified. I found ${profile.name} from ${profile.grade}.');
      await _botSay('Ready to continue?');
      return;
    }

    setState(() {
      _stage = _AuthStage.profileSelect;
    });
    await _botSay('Verified. This number has more than one student profile.');
    await _botSay('Which one is you?');
  }

  List<StudentProfile> _profilesForPhone(String phone) {
    if (phone.endsWith('999') || phone == '999') {
      return _demoProfiles;
    }
    if (phone.endsWith('123') || phone == '123') {
      return [_demoProfiles.first];
    }
    if (phone.length >= 10) {
      return _demoProfiles.take(2).toList();
    }
    return const [];
  }

  Future<void> _selectProfile(StudentProfile profile) async {
    if (_isLoading) return;
    _userSay('${profile.name}, ${profile.grade}');
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _selectedProfile = profile;
      _stage = _AuthStage.ready;
    });
    await _botSay('Perfect. I selected ${profile.name}.');
    await _botSay('Let us welcome you back.');
  }

  void _tryAnotherNumber() {
    setState(() {
      _phone = '';
      _profiles = const [];
      _selectedProfile = null;
      _stage = _AuthStage.phone;
    });
    _botSay('No problem. Enter the phone number you want me to check.');
    _inputFocusNode.requestFocus();
  }

  void _continueToWelcomeBack() {
    final name = _selectedProfile?.name ?? 'Champ';
    context.go('${AppRoutes.welcomeBack}?name=${Uri.encodeComponent(name)}');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.mutedLavender),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/logos/gov-logo.png',
              height: 36,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/logos/tap_logo.png',
              height: 28,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const Spacer(),
            Text(
              'Find Profile',
              style: GoogleFonts.inter(
                color: AppTheme.textColor,
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 620 : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildInteraction(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteraction() {
    if (_stage == _AuthStage.profileSelect) {
      return _ProfileSelectPanel(
        profiles: _profiles,
        isLoading: _isLoading,
        onSelect: _selectProfile,
        onTryAnother: _tryAnotherNumber,
      );
    }

    if (_stage == _AuthStage.ready) {
      return _ReadyPanel(
        profile: _selectedProfile,
        isLoading: _isLoading,
        onContinue: _continueToWelcomeBack,
      );
    }

    if (_stage == _AuthStage.notFound) {
      return _NotFoundPanel(
        onTryAnother: _tryAnotherNumber,
      );
    }

    return _InputPanel(
      controller: _inputController,
      focusNode: _inputFocusNode,
      isLoading: _isLoading,
      keyboardType: _stage == _AuthStage.phone
          ? TextInputType.phone
          : TextInputType.number,
      hintText: _stage == _AuthStage.phone
          ? 'Enter phone number'
          : 'Enter OTP code',
      buttonLabel: _stage == _AuthStage.phone ? 'Check' : 'Verify',
      helperText: _stage == _AuthStage.otp
          ? 'Demo OTP: 1234'
          : 'Demo: 999 has many profiles, 123 has one profile',
      onSubmit: _handleSubmit,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _AuthMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == 'bot';
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) const _BotAvatar(),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: width > 800 ? 480 : width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isBot ? AppTheme.fieldBackground : AppTheme.successBubble,
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
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isBot ? AppTheme.textColor : AppTheme.successText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.imageBgColor,
        child: ClipOval(
          child: Image.asset(
            'assets/onboarding/TAP-bot.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.buttonColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BotAvatar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.fieldBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(),
                SizedBox(width: 4),
                _Dot(),
                SizedBox(width: 4),
                _Dot(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.mutedText,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final TextInputType keyboardType;
  final String hintText;
  final String buttonLabel;
  final String helperText;
  final VoidCallback onSubmit;

  const _InputPanel({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.keyboardType,
    required this.hintText,
    required this.buttonLabel,
    required this.helperText,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(hintText),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.mutedLavender)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.inter(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.faintText,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(96, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(buttonLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: GoogleFonts.inter(
              color: AppTheme.faintText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSelectPanel extends StatelessWidget {
  final List<StudentProfile> profiles;
  final bool isLoading;
  final ValueChanged<StudentProfile> onSelect;
  final VoidCallback onTryAnother;

  const _ProfileSelectPanel({
    required this.profiles,
    required this.isLoading,
    required this.onSelect,
    required this.onTryAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile-select'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FD),
        border: Border(top: BorderSide(color: AppTheme.mutedLavender)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final profile in profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileCard(
                profile: profile,
                isLoading: isLoading,
                onTap: () => onSelect(profile),
              ),
            ),
          TextButton(
            onPressed: isLoading ? null : onTryAnother,
            child: Text(
              'Use another number',
              style: GoogleFonts.inter(
                color: AppTheme.buttonColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final StudentProfile profile;
  final bool isLoading;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.imageBgColor,
      AppTheme.streakBg,
      AppTheme.pointBg,
    ];

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors[profile.avatarIndex % colors.length],
              child: Text(
                profile.name.isEmpty ? '?' : profile.name[0],
                style: GoogleFonts.inter(
                  color: AppTheme.buttonColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: GoogleFonts.inter(
                      color: AppTheme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${profile.grade} • ${profile.course}',
                    style: GoogleFonts.inter(
                      color: AppTheme.subheadingColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.school,
                    style: GoogleFonts.inter(
                      color: AppTheme.faintText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.buttonColor,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundPanel extends StatelessWidget {
  final VoidCallback onTryAnother;

  const _NotFoundPanel({required this.onTryAnother});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('not-found'),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.mutedLavender)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: onTryAnother,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try another number'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  final StudentProfile? profile;
  final bool isLoading;
  final VoidCallback onContinue;

  const _ReadyPanel({
    required this.profile,
    required this.isLoading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.mutedLavender)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.selectedSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.mutedLavender),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.streakColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${profile!.name} is ready',
                      style: GoogleFonts.inter(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
