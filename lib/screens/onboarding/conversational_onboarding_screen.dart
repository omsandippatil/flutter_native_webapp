import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/router.dart';

class ChatBubble {
  final String sender; // 'bot' or 'user'
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

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final List<ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isVoiceMuted = false;

  // JSON flow containers
  Map<String, Map<String, dynamic>> _allSteps = {};
  bool _isLoadingFlows = true;

  // Active state
  String _currentStepId = 'OF-001';
  final Map<String, dynamic> _cachedFields = {
    'name': 'Aarav',
    'phone': '',
    'selected_course': 'science',
  };

  bool _isBotTyping = false;
  bool _showTextInput = false;
  bool _isPasswordInput = false;
  String _textInputHint = 'Type here...';
  Widget? _currentInteractionWidget;

  @override
  void initState() {
    super.initState();
    _loadFlowData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // Load and parse both JSON files dynamically
  Future<void> _loadFlowData() async {
    try {
      final authStr = await rootBundle.loadString(
        'assets/flows/en/auth/auth_flow.json',
      );
      final onboardingStr = await rootBundle.loadString(
        'assets/flows/en/onboarding/student_onboarding.json',
      );

      final authJson = jsonDecode(authStr) as Map<String, dynamic>;
      final onboardingJson = jsonDecode(onboardingStr) as Map<String, dynamic>;

      final Map<String, Map<String, dynamic>> stepsMap = {};

      for (var step in authJson['steps']) {
        stepsMap[step['step_id']] = step as Map<String, dynamic>;
      }

      for (var step in onboardingJson['steps']) {
        stepsMap[step['step_id']] = step as Map<String, dynamic>;
      }

      setState(() {
        _allSteps = stepsMap;
        _isLoadingFlows = false;
      });

      // Start the flow
      _executeStep();
    } catch (e) {
      // Fallback in case of asset loading errors
      debugPrint('Error loading flows: $e');
      setState(() {
        _isLoadingFlows = false;
      });
    }
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

  // General Flow Engine
  void _executeStep() {
    final step = _allSteps[_currentStepId];
    if (step == null) return;

    setState(() {
      _isBotTyping = true;
      _currentInteractionWidget = null;
      _showTextInput = false;
    });

    // Simulate natural response delays
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

    // 1. Resolve text message (supporting variants and template fields)
    String text = '';
    if (step.containsKey('variants')) {
      final variants = step['variants'] as Map<String, dynamic>;
      final variantKey = _cachedFields['selected_course'] ?? 'science';
      if (variants.containsKey(variantKey)) {
        text = variants[variantKey]['display_text'] ?? '';
      }
    } else {
      text = step['display_text'] ?? '';
    }

    // 2. Perform text formatting
    text = text
        .replaceAll('{{name}}', _cachedFields['name'] ?? 'Aarav')
        .replaceAll('{{phone}}', _cachedFields['phone'] ?? '')
        .replaceAll(
          '{{course_display}}',
          _getCourseDisplayName(_cachedFields['selected_course']),
        );

    // Dynamic overrides to exactly match mockups
    if (_currentStepId == 'OF-002') {
      text =
          'Hello Aarav, here are your subjects!\nIf you want to continue with the same course click "Continue"|If you want to change your course then select and click Confirm!';
    } else if (_currentStepId == 'OF-003') {
      final courseName = _getCourseDisplayName(
        _cachedFields['selected_course'],
      );
      text =
          'YAY!! You selected "$courseName"\n\nIs it correct?|Please note: Once selected you cannot change it for one academic session (1 year)';
    } else if (_currentStepId == 'OF-004') {
      text = '';
    }

    // 3. Render confetti / success celebration if designated
    Widget? customContent;
    if (text.contains('[confetti]') || _currentStepId == 'OF-004') {
      text = text.replaceAll('[confetti]', '').trim();
      customContent = _buildCelebrateCard();
    }

    // 4. Render profile verification card component if specified
    if (component == 'ProfileVerifyCard') {
      customContent = _buildProfileVerifyCard();
    }

    // Add bot message
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

    // 5. Handle inputs based on the step configuration
    if (inputMode == 'free_text') {
      setState(() {
        _showTextInput = true;
        _isPasswordInput = component == 'PasswordInput';
        _textInputHint = _currentStepId == 'AU-002'
            ? 'Enter phone number (e.g. 999 for welcome back)'
            : 'Type your answer...';
      });
    } else if (inputMode == 'buttons_only' || inputMode == 'radio') {
      final List<dynamic>? options = step['options'];
      if (options != null) {
        if (_currentStepId == 'OF-002') {
          // Render course selection grid custom card widget
          setState(() {
            _currentInteractionWidget = _buildCourseSelectionInteraction(
              options,
            );
          });
        } else {
          // Render standard option buttons
          setState(() {
            _currentInteractionWidget = _buildButtonsInteraction(options, (
              selectedValue,
              nextStepId,
            ) {
              final selectedOption = options.firstWhere(
                (opt) => opt['value'] == selectedValue,
              );
              _addUserMessage(selectedOption['label'] ?? selectedValue);

              // Cache field if applicable
              final List<dynamic>? cacheFields = step['cache_fields'];
              if (cacheFields != null && cacheFields.isNotEmpty) {
                _cachedFields[cacheFields.first.toString()] = selectedValue;
              }

              // Route next step
              if (selectedOption.containsKey('next_flow')) {
                if (selectedOption['next_flow'] == 'activity_flow') {
                  Timer(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      context.go(AppRoutes.home);
                    }
                  });
                } else {
                  _showCompleteDialog();
                }
                return;
              } else if (nextStepId != null) {
                _currentStepId = nextStepId;
              } else if (step.containsKey('next_step')) {
                _currentStepId = step['next_step'];
              }

              _executeStep();
            });
          });
        }
      }
    } else if (inputMode == 'static') {
      // Automatic transition for static output steps
      if (step.containsKey('next_step') && step['next_step'] != null) {
        _currentStepId = step['next_step'];
        _executeStep();
      } else if (step.containsKey('next_step_rule')) {
        final rules = step['next_step_rule'] as Map<String, dynamic>;
        // Default rule routing for verify correct or password confirm steps
        if (rules.containsKey('if_new_signup')) {
          _currentStepId = rules['if_new_signup'];
          _executeStep();
        } else if (_currentStepId == 'AU-SET-PASSWORD-CONFIRM') {
          _currentStepId = 'AU-SIGNUP-COMPLETE';
          _executeStep();
        }
      } else if (step.containsKey('next_flow')) {
        // Auth Flow complete, transition to next flow
        if (step['next_flow'] == 'onboarding_flow') {
          Timer(const Duration(milliseconds: 1500), () {
            setState(() {
              _currentStepId = step['next_flow_step'] ?? 'OF-001';
            });
            _executeStep();
          });
        } else if (step['next_flow'] == 'activity_flow') {
          Timer(const Duration(milliseconds: 1500), () {
            if (mounted) {
              context.go(AppRoutes.home);
            }
          });
        }
      }
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatBubble(sender: 'user', text: text));
    });
    _scrollToBottom();
  }

  String _getCourseDisplayName(String? code) {
    switch (code) {
      case 'science':
        return 'Science';
      case 'coding':
        return 'Coding';
      case 'financial-verticals':
        return 'Financial Literacy';
      case 'visual-arts':
        return 'Visual Arts';
      default:
        return 'Science';
    }
  }

  // Text inputs handler (phone, OTP, password, edit-name)
  void _handleTextSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    _addUserMessage(_isPasswordInput ? '••••••••' : text);

    final step = _allSteps[_currentStepId];
    if (step == null) return;

    // Cache the input field
    final List<dynamic>? cacheFields = step['cache_fields'];
    if (cacheFields != null && cacheFields.isNotEmpty) {
      _cachedFields[cacheFields.first.toString()] = text;
    }

    if (_currentStepId == 'AU-002') {
      // Check phone number for password existence simulation
      if (text == '999' || text == '123') {
        _currentStepId = 'AU-PASSWORD-LOGIN';
        _executeStep();
      } else {
        // Route to verify phone step (no account exists)
        if (step.containsKey('next_step_rule')) {
          final rules = step['next_step_rule'] as Map<String, dynamic>;
          _currentStepId = rules['if_no_account'] ?? 'AU-VERIFY-PHONE';
        } else {
          _currentStepId = 'AU-VERIFY-PHONE';
        }
        _executeStep();
      }
    } else if (_currentStepId == 'AU-PASSWORD-LOGIN') {
      // Password checking simulation (1234 is correct)
      if (text == '1234') {
        if (step.containsKey('next_step_rule')) {
          final rules = step['next_step_rule'] as Map<String, dynamic>;
          _currentStepId = rules['if_correct'] ?? 'AU-PASSWORD-CORRECT';
        } else {
          _currentStepId = 'AU-PASSWORD-CORRECT';
        }
      } else {
        if (step.containsKey('next_step_rule')) {
          final rules = step['next_step_rule'] as Map<String, dynamic>;
          _currentStepId = rules['if_incorrect'] ?? 'AU-PASSWORD-WRONG';
        } else {
          _currentStepId = 'AU-PASSWORD-WRONG';
        }
      }
      _executeStep();
    } else if (_currentStepId == 'AU-VERIFY-PHONE') {
      // Route OTP verification correct
      if (step.containsKey('next_step_rule')) {
        final rules = step['next_step_rule'] as Map<String, dynamic>;
        _currentStepId = rules['if_correct'] ?? 'AU-VERIFY-CORRECT';
      } else {
        _currentStepId = 'AU-VERIFY-CORRECT';
      }
      _executeStep();
    } else if (_currentStepId == 'AU-SET-PASSWORD') {
      // Route password lock success
      if (step.containsKey('next_step_rule')) {
        final rules = step['next_step_rule'] as Map<String, dynamic>;
        _currentStepId = rules['if_valid'] ?? 'AU-SET-PASSWORD-CONFIRM';
      } else {
        _currentStepId = 'AU-SET-PASSWORD-CONFIRM';
      }
      _executeStep();
    } else if (_currentStepId == 'OF-005-EDIT-NAME') {
      // Finished name editing, return to profile check
      _currentStepId = step['next_step'] ?? 'OF-005';
      _executeStep();
    } else {
      if (step.containsKey('next_step')) {
        _currentStepId = step['next_step'];
        _executeStep();
      }
    }
  }

  // --- Dynamic Option Buttons Builder ---
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
              val == 'confirm' ||
              val == 'yes' ||
              val == 'start' ||
              val == 'start_learning';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ElevatedButton(
                onPressed: () => onSelect(val, nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrimary
                      ? const Color(0xFF5B5BD6)
                      : const Color(0xFFE8E8FB),
                  foregroundColor: isPrimary
                      ? Colors.white
                      : const Color(0xFF5B5BD6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Dynamic Course Selection Grid Widget ---
  Widget _buildCourseSelectionInteraction(List<dynamic> options) {
    String localSelected = _cachedFields['selected_course'] ?? 'science';

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
                  childAspectRatio: 0.85,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final val = opt['value']?.toString() ?? '';
                  final rawLabel = opt['label']?.toString() ?? '';
                  final isSelected = localSelected == val;

                  // Beautify labels
                  String title = rawLabel;
                  if (title.contains('Science')) title = 'Science';
                  if (title.contains('Coding')) title = 'Coding';
                  if (title.contains('Financial')) title = 'Financial Literacy';
                  if (title.contains('Visual')) title = 'Visual Arts';

                  return GestureDetector(
                    onTap: () {
                      setLocalState(() {
                        localSelected = val;
                      });
                      setState(() {
                        _cachedFields['selected_course'] = val;
                      });
                    },
                    child: Container(
                      clipBehavior: Clip
                          .antiAlias, // so children don't overflow the rounded corners
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8E8FB)
                            : Colors.white,
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
                              // Upper Text Part
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12.0,
                                  right: 12.0,
                                  top: 12.0,
                                  bottom: 4.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1C1C21),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'One liner lorem ipsum text about the course will comer here',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF6E6E7A),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Lower Gray Box with centered Blue Play Button
                              Container(
                                width: double.infinity,
                                height: 44,
                                color: const Color(0xFFF1F1F5),
                                child: Center(
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF5B5BD6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    _addUserMessage('Continue');
                    // Find the next step from the selected course option
                    final selectedOpt = options.firstWhere(
                      (opt) => opt['value'] == localSelected,
                    );
                    _currentStepId = selectedOpt['next_step'] ?? 'OF-003';
                    _executeStep();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B5BD6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Dynamic Celebrate Card ---
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

  // --- Profile Verification Card ---
  Widget _buildProfileVerifyCard() {
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
          _buildProfileRow('Name', _cachedFields['name'] ?? 'Aarav'),
          const Divider(height: 16),
          _buildProfileRow('Phone', _cachedFields['phone'] ?? '9876543210'),
          const Divider(height: 16),
          _buildProfileRow(
            'Course',
            _getCourseDisplayName(_cachedFields['selected_course']),
          ),
          const Divider(height: 16),
          _buildProfileRow('School', 'MCD Primary School'),
          const Divider(height: 16),
          _buildProfileRow('Grade', 'Class 5th'),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
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
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C21),
          ),
        ),
      ],
    );
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Setup Complete! 🎉',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF5B5BD6),
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'Aarav is now successfully enrolled in ${_getCourseDisplayName(_cachedFields['selected_course'])}!',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF6E6E7A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.splash);
              },
              child: Text(
                'Restart Demo',
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
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/logos/tap_logo.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
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
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                          mainAxisAlignment: isBot
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.end,
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
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.android,
                                                color: Color(0xFF5B5BD6),
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isBot
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  if (message.text.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: isDesktop
                                                ? 480
                                                : size.width * 0.78,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isBot
                                                ? const Color(0xFFF1F1F5)
                                                : const Color(0xFFE8FAF1),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                20,
                                              ),
                                              topRight: const Radius.circular(
                                                20,
                                              ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  message.text,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: isBot
                                                        ? const Color(
                                                            0xFF1C1C21,
                                                          )
                                                        : const Color(
                                                            0xFF0F5132,
                                                          ),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                              if (isBot &&
                                                  message.hasVoice) ...[
                                                const SizedBox(width: 8),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _isVoiceMuted =
                                                              !_isVoiceMuted;
                                                        });
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4.0,
                                                            ),
                                                        child: Icon(
                                                          _isVoiceMuted
                                                              ? Icons
                                                                    .volume_off_rounded
                                                              : Icons
                                                                    .volume_up_rounded,
                                                          size: 18,
                                                          color: const Color(
                                                            0xFF5B5BD6,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (!isBot)
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              left: 4.0,
                                              bottom: 4.0,
                                            ),
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
                                        maxWidth: isDesktop
                                            ? 450
                                            : size.width * 0.75,
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
                      border: Border(
                        top: BorderSide(color: Color(0xFFE8E8FB), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F1F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocusNode,
                              obscureText: _isPasswordInput,
                              keyboardType: _isPasswordInput
                                  ? TextInputType.visiblePassword
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                hintText: _textInputHint,
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF6E6E7A),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _handleTextSubmit(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: _handleTextSubmit,
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
              children: [_buildDot(0), _buildDot(150), _buildDot(300)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
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
