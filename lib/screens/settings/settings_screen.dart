import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../models/active_profile_model.dart';
import '../../models/learner_state_model.dart';
import '../../models/profile_summary_model.dart';
import '../../providers/http_client_provider.dart';
import '../../providers/learner_state_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_nav.dart';

enum _ProfileTab { profile, settings, about }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _ProfileTab _activeTab = _ProfileTab.profile;

  Map<String, dynamic>? _aboutData;
  bool _aboutLoading = false;
  bool _aboutError = false;

  bool _isEditing = false;
  bool _isSaving = false;
  String? _saveError;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final bool _hasSibling = false;

  ActiveProfileModel? _activeProfile;
  LearnerStateModel? _learnerState;
  bool _isLoadingProfile = true;
  bool _profileLoadFailed = false;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _bootstrapProfile();
  }

  @override
  void dispose() {
    _disposed = true;
    _firstNameController.dispose();
    _lastNameController.dispose();
    _languageController.dispose();
    _gradeController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  bool get _canUpdate => mounted && !_disposed;

  Future<void> _bootstrapProfile() async {
    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      final activeProfile = await repository.readActiveProfile();

      if (!_canUpdate) return;

      if (activeProfile == null) {
        setState(() {
          _isLoadingProfile = false;
          _profileLoadFailed = false;
        });
        return;
      }

      final learnerStateRepository = await ref.read(
        learnerStateRepositoryProvider.future,
      );
      if (!_canUpdate) return;

      final learnerState =
          await learnerStateRepository.readCached(activeProfile.learnerId) ??
          await learnerStateRepository.fetchState(
            learnerId: activeProfile.learnerId,
          );

      if (!_canUpdate) return;

      setState(() {
        _activeProfile = activeProfile;
        _learnerState = learnerState;
        _isLoadingProfile = false;
      });
      _syncControllersFromState();
    } catch (e) {
      debugPrint('Failed to load profile for settings: $e');
      if (!_canUpdate) return;
      setState(() {
        _isLoadingProfile = false;
        _profileLoadFailed = true;
      });
    }
  }

  Future<void> _loadAboutTap() async {
    if (_aboutData != null || _aboutLoading) return;
    setState(() {
      _aboutLoading = true;
      _aboutError = false;
    });
    try {
      final raw = await rootBundle.loadString(
        'assets/profile-screen/about_tap.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!_canUpdate) return;
      setState(() {
        _aboutData = decoded;
        _aboutLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load about_tap.json: $e');
      if (!_canUpdate) return;
      setState(() {
        _aboutLoading = false;
        _aboutError = true;
      });
    }
  }

  void _syncControllersFromState() {
    final fullName =
        (_learnerState?.profile?.studentName ??
                _activeProfile?.studentName ??
                '')
            .trim();
    final parts = fullName.isEmpty
        ? <String>[]
        : fullName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    _firstNameController.text = firstName;
    _lastNameController.text = lastName;
    _languageController.text = _learnerState?.profile?.language ?? '';
    _gradeController.text = _activeProfile?.grade ?? '';
    _subjectController.text = _verticalDisplay();
  }

  String _verticalDisplay() {
    final course = _learnerState?.enrollment?.course;
    if (course == null || course.isEmpty) return '';
    return course;
  }

  void _startEditing() {
    _syncControllersFromState();
    setState(() {
      _isEditing = true;
      _saveError = null;
    });
  }

  void _cancelEditing() {
    _syncControllersFromState();
    setState(() {
      _isEditing = false;
      _saveError = null;
    });
  }

  Future<void> _saveEdits() async {
    final activeProfile = _activeProfile;
    if (activeProfile == null) return;

    final phone = await _resolvePhone();
    if (!_canUpdate) return;

    if (phone.isEmpty) {
      setState(() {
        _saveError = 'Could not verify your phone number. Please log in again.';
      });
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final language = _languageController.text.trim();
    final grade = _gradeController.text.trim();

    final updates = <String, dynamic>{};
    if (fullName.isNotEmpty) updates['student_name'] = fullName;
    if (language.isNotEmpty) updates['language'] = language;
    if (grade.isNotEmpty) updates['grade'] = grade;

    if (updates.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
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
        );
        await repository.setActiveProfile(updatedProfile);
      }

      if (!_canUpdate) return;

      ref.invalidate(activeProfileProvider);
      ref.invalidate(learnerStateDataProvider(activeProfile.learnerId));

      setState(() {
        if (updatedProfile != null) _activeProfile = updatedProfile;
        _learnerState = updatedState;
        _isEditing = false;
        _isSaving = false;
      });
      _syncControllersFromState();
      _showSavedSnack();
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (!_canUpdate) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Could not save your changes. Please try again.';
      });
    }
  }

  void _showSavedSnack() {
    if (!_canUpdate) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  void _onTabChanged(_ProfileTab tab) {
    setState(() => _activeTab = tab);
    if (tab == _ProfileTab.about) {
      _loadAboutTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppNav(
      child: Scaffold(
        backgroundColor: AppTheme.appBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchProfileBar(onSwitchDialog: _showSwitchProfile),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight <= 0 ||
                        constraints.maxWidth <= 0) {
                      return const SizedBox.shrink();
                    }

                    final isWide = constraints.maxWidth >= 760;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 28 : 16,
                        34,
                        isWide ? 28 : 16,
                        96,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 132,
                                      child: _ProfileSideNav(
                                        activeTab: _activeTab,
                                        onChanged: _onTabChanged,
                                      ),
                                    ),
                                    const SizedBox(width: 34),
                                    Expanded(child: _activeContent()),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _ProfileSideNav(
                                      activeTab: _activeTab,
                                      onChanged: _onTabChanged,
                                      horizontal: true,
                                    ),
                                    const SizedBox(height: 22),
                                    _activeContent(),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeContent() {
    switch (_activeTab) {
      case _ProfileTab.profile:
        return _ProfileDetailsView(
          isLoading: _isLoadingProfile,
          loadFailed: _profileLoadFailed,
          isEditing: _isEditing,
          isSaving: _isSaving,
          saveError: _saveError,
          activeProfile: _activeProfile,
          learnerState: _learnerState,
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          languageController: _languageController,
          gradeController: _gradeController,
          subjectDisplay: _verticalDisplay(),
          hasSibling: _hasSibling,
          onStartEditing: _startEditing,
          onCancelEditing: _cancelEditing,
          onSave: _saveEdits,
        );
      case _ProfileTab.settings:
        return const _SettingsView();
      case _ProfileTab.about:
        return _AboutTapView(
          data: _aboutData,
          loading: _aboutLoading,
          failed: _aboutError,
          onRetry: _loadAboutTap,
        );
    }
  }

  Future<String> _resolvePhone() async {
    final tokenStore = ref.read(secureTokenStoreProvider);
    final storedPhone = await tokenStore.readPhone();
    if (storedPhone != null && storedPhone.isNotEmpty) return storedPhone;
    return _activeProfile?.phone ?? '';
  }

  Future<void> _showSwitchProfile() async {
    final phone = await _resolvePhone();
    if (!_canUpdate) return;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not verify your phone number. Please log in again.',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _SwitchProfileDialog(
        phone: phone,
        activeLearnerId: _activeProfile?.learnerId,
        onProfileSelected: _switchToProfile,
      ),
    );
  }

  Future<void> _switchToProfile(ProfileSummaryModel profile) async {
    final phone = await _resolvePhone();
    if (phone.isEmpty) return;

    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      final learnerState = await repository.selectProfile(
        phone: phone,
        learnerId: profile.learnerId,
      );

      await repository.setActiveProfile(
        ActiveProfileModel(
          phone: phone,
          learnerId: profile.learnerId,
          studentName: learnerState.profile?.studentName ?? profile.studentName,
          grade: profile.grade,
          division: profile.division,
          avatar: profile.avatar,
        ),
      );

      if (!_canUpdate) return;

      ref.invalidate(activeProfileProvider);
      ref.invalidate(learnerStateDataProvider(profile.learnerId));

      if (mounted) Navigator.of(context).pop();

      await _bootstrapProfile();
    } catch (e) {
      debugPrint('Failed to switch profile: $e');
      if (!_canUpdate) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not switch profile. Please try again.'),
        ),
      );
    }
  }
}

class _SwitchProfileBar extends StatelessWidget {
  final VoidCallback onSwitchDialog;

  const _SwitchProfileBar({required this.onSwitchDialog});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ColoredBox(
      color: AppTheme.profileBar,
      child: SizedBox(
        width: screenWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : screenWidth;
              final compact = availableWidth < 560;

              final text = Text(
                'Not you? Switch to your profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor,
                ),
              );

              final button = _SwitchProfileButton(
                label: 'Switch Profile',
                onPressed: onSwitchDialog,
              );

              if (compact) {
                return SizedBox(
                  width: availableWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [text, const SizedBox(height: 10), button],
                  ),
                );
              }

              return SizedBox(
                width: availableWidth,
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 10,
                    children: [text, button],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SwitchProfileButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  const _SwitchProfileButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.buttonColor,
                side: BorderSide(color: AppTheme.buttonColor),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(label),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(label),
            ),
    );
  }
}

class _ProfileSideNav extends StatelessWidget {
  final _ProfileTab activeTab;
  final ValueChanged<_ProfileTab> onChanged;
  final bool horizontal;

  const _ProfileSideNav({
    required this.activeTab,
    required this.onChanged,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(_ProfileTab, String)>[
      (_ProfileTab.profile, 'Profile'),
      (_ProfileTab.settings, 'Settings'),
      (_ProfileTab.about, 'About TAP'),
    ];

    if (horizontal) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            _NavPill(
              label: item.$2,
              selected: activeTab == item.$1,
              onTap: () => onChanged(item.$1),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) ...[
          _NavPill(
            label: item.$2,
            selected: activeTab == item.$1,
            onTap: () => onChanged(item.$1),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _NavPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 116,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.selectedSurface : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.buttonColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.buttonColor : AppTheme.subheadingColor,
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailsView extends StatelessWidget {
  final bool isLoading;
  final bool loadFailed;
  final bool isEditing;
  final bool isSaving;
  final String? saveError;
  final ActiveProfileModel? activeProfile;
  final LearnerStateModel? learnerState;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController languageController;
  final TextEditingController gradeController;
  final String subjectDisplay;
  final bool hasSibling;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final VoidCallback onSave;

  const _ProfileDetailsView({
    required this.isLoading,
    required this.loadFailed,
    required this.isEditing,
    required this.isSaving,
    required this.saveError,
    required this.activeProfile,
    required this.learnerState,
    required this.firstNameController,
    required this.lastNameController,
    required this.languageController,
    required this.gradeController,
    required this.subjectDisplay,
    required this.hasSibling,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ProfileSkeleton();
    }

    if (loadFailed) {
      return _WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Could not load your profile. Please try again later.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6E6E7A),
          ),
        ),
      );
    }

    final profile = activeProfile;
    if (profile == null) {
      return _WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No active profile found.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6E6E7A),
          ),
        ),
      );
    }

    final schoolName = learnerState?.profile?.schoolName ?? '—';
    final grade = activeProfile?.grade ?? '—';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudentSummaryCard(
          studentName: profile.studentName ?? 'Student',
          schoolName: schoolName,
          grade: grade,
          subjectDisplay: subjectDisplay,
        ),
        const SizedBox(height: 16),
        if (saveError != null) ...[
          _ErrorBanner(text: saveError!),
          const SizedBox(height: 12),
        ],
        _EditableSection(
          title: 'Personal Details',
          children: [
            _EditableField(
              label: 'First name',
              isEditing: isEditing,
              controller: firstNameController,
            ),
            _EditableField(
              label: 'Last name',
              isEditing: isEditing,
              controller: lastNameController,
            ),
            _EditableField(
              label: 'Language',
              isEditing: isEditing,
              controller: languageController,
            ),
            _ReadOnlyField(
              label: 'Is a brother or sister also using TAP?',
              value: hasSibling ? 'Yes' : 'No',
            ),
            const _ReadOnlyField(label: 'Phone number', value: 'Verified'),
          ],
        ),
        const SizedBox(height: 10),
        _EditableSection(
          title: 'School Details',
          children: [
            _ReadOnlyField(label: 'School Name', value: schoolName),
            _EditableField(
              label: 'Grade',
              isEditing: isEditing,
              controller: gradeController,
            ),
            _ReadOnlyField(
              label: 'Subject',
              value: subjectDisplay.isEmpty ? '—' : subjectDisplay,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _EditActionsBar(
          isEditing: isEditing,
          isSaving: isSaving,
          onStartEditing: onStartEditing,
          onCancelEditing: onCancelEditing,
          onSave: onSave,
        ),
      ],
    );
  }
}

class _EditActionsBar extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final VoidCallback onSave;

  const _EditActionsBar({
    required this.isEditing,
    required this.isSaving,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onStartEditing,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(
            'Edit Info',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.buttonColor,
            side: BorderSide(color: AppTheme.buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: isSaving ? null : onCancelEditing,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6E6E7A),
                side: const BorderSide(color: Color(0xFFE1E2EA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD34B40),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD34B40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSummaryCard extends StatelessWidget {
  final String studentName;
  final String schoolName;
  final String grade;
  final String subjectDisplay;

  const _StudentSummaryCard({
    required this.studentName,
    required this.schoolName,
    required this.grade,
    required this.subjectDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFE8E5FF),
            child: Text(
              _initials(studentName),
              style: const TextStyle(color: AppTheme.buttonColor),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textWidth = constraints.maxWidth;
                final compact = textWidth < 230;
                final subjectWidth = compact
                    ? textWidth
                    : (textWidth - 14) * 0.58;
                final gradeWidth = compact
                    ? textWidth
                    : (textWidth - 14) * 0.36;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1C1C21),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Color(0xFF24A866),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _MetaLine(
                      icon: Icons.location_city_rounded,
                      text: schoolName,
                      width: textWidth,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        _MetaLine(
                          icon: Icons.menu_book_rounded,
                          text: 'Grade $grade',
                          width: gradeWidth,
                        ),
                        if (subjectDisplay.isNotEmpty)
                          _MetaLine(
                            icon: Icons.hub_rounded,
                            text: subjectDisplay,
                            width: subjectWidth,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final double width;

  const _MetaLine({
    required this.icon,
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF24A866)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6E6E7A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditableSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E7A),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            height: 36,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1E2EA)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6E6E7A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Color(0xFF9B9CA6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final bool isEditing;
  final TextEditingController controller;

  const _EditableField({
    required this.label,
    required this.isEditing,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E7A),
            ),
          ),
          const SizedBox(height: 5),
          if (isEditing)
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.buttonColor),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C21),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 36,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE1E2EA)),
              ),
              child: Text(
                controller.text.isEmpty ? '—' : controller.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6E6E7A),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_ThemeCard(), SizedBox(height: 16), _AccountManagementCard()],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460;
          final selector = Container(
            decoration: BoxDecoration(
              color: AppTheme.gemBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: compact
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ThemeButton(
                        label: 'Default',
                        icon: Icons.desktop_windows,
                      ),
                      _ThemeButton(
                        label: 'Light',
                        icon: Icons.wb_sunny_outlined,
                        selected: true,
                      ),
                      _ThemeButton(
                        label: 'Dark',
                        icon: Icons.dark_mode_outlined,
                      ),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemeButton(
                        label: 'Default',
                        icon: Icons.desktop_windows,
                      ),
                      _ThemeButton(
                        label: 'Light',
                        icon: Icons.wb_sunny_outlined,
                        selected: true,
                      ),
                      _ThemeButton(
                        label: 'Dark',
                        icon: Icons.dark_mode_outlined,
                      ),
                    ],
                  ),
          );

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsTitle('Theme'),
                const SizedBox(height: 12),
                selector,
              ],
            );
          }

          return Row(
            children: [
              const Expanded(child: _SettingsTitle('Theme')),
              selector,
            ],
          );
        },
      ),
    );
  }
}

class _SettingsTitle extends StatelessWidget {
  final String text;

  const _SettingsTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppTheme.textColor,
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _ThemeButton({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: selected ? AppTheme.buttonColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : AppTheme.buttonColor,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.buttonColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountManagementCard extends StatelessWidget {
  const _AccountManagementCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Management',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Hi Champ, If you need to take a break or want to permanently delete your account, you can manage these options here.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 52,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Deactivate Account',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD34B40),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Delete Account',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD34B40),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTapView extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  const _AboutTapView({
    required this.data,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return _WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load this section.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6E6E7A),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final aboutData = data;
    if (loading || aboutData == null) {
      return const _ProfileSkeleton();
    }

    final mission = aboutData['mission'] as Map<String, dynamic>? ?? const {};
    final problem = aboutData['problem'] as Map<String, dynamic>? ?? const {};
    final solution = aboutData['solution'] as Map<String, dynamic>? ?? const {};

    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AboutPair(
            text: _AboutTextBlock(
              title: mission['title'] as String? ?? '',
              body: _asParagraphs(mission['body']),
            ),
            imagePath: mission['image'] as String? ?? '',
            imageFirst: false,
          ),
          const SizedBox(height: 34),
          _AboutPair(
            text: _AboutTextBlock(
              title: problem['title'] as String? ?? '',
              body: _asParagraphs(problem['body']),
              source: problem['source'] as String?,
            ),
            imagePath: problem['image'] as String? ?? '',
            imageFirst: true,
          ),
          const SizedBox(height: 34),
          _AboutPair(
            text: _AboutTextBlock(
              title: solution['title'] as String? ?? '',
              body: _asParagraphs(solution['body']),
            ),
            imagePath: solution['image'] as String? ?? '',
            imageFirst: false,
          ),
        ],
      ),
    );
  }

  static List<String> _asParagraphs(Object? value) {
    if (value is List) return value.whereType<String>().toList();
    if (value is String) return [value];
    return const [];
  }
}

class _AboutPair extends StatelessWidget {
  final _AboutTextBlock text;
  final String imagePath;
  final bool imageFirst;

  const _AboutPair({
    required this.text,
    required this.imagePath,
    required this.imageFirst,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final image = _AboutImage(path: imagePath);

        if (narrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: imageFirst
                ? [image, const SizedBox(height: 18), text]
                : [text, const SizedBox(height: 18), image],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: imageFirst
              ? [
                  Expanded(child: image),
                  const SizedBox(width: 24),
                  Expanded(child: text),
                ]
              : [
                  Expanded(child: text),
                  const SizedBox(width: 24),
                  Expanded(child: image),
                ],
        );
      },
    );
  }
}

class _AboutTextBlock extends StatelessWidget {
  final String title;
  final List<String> body;
  final String? source;

  const _AboutTextBlock({required this.title, required this.body, this.source});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1C1C21),
          ),
        ),
        const SizedBox(height: 14),
        for (final paragraph in body) ...[
          Text(
            paragraph,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E7A),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (source != null)
          Text(
            source!,
            style: GoogleFonts.inter(
              fontSize: 9,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E7A),
            ),
          ),
      ],
    );
  }
}

class _AboutImage extends StatelessWidget {
  final String path;

  const _AboutImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(width: 70, height: 18),
          SizedBox(height: 22),
          _SkeletonBar(width: double.infinity, height: 34),
          SizedBox(height: 14),
          _SkeletonBar(width: 220, height: 82),
          SizedBox(height: 14),
          _SkeletonBar(width: 160, height: 64),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8EC),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _SwitchProfileDialog extends ConsumerStatefulWidget {
  final String phone;
  final String? activeLearnerId;
  final Future<void> Function(ProfileSummaryModel) onProfileSelected;

  const _SwitchProfileDialog({
    required this.phone,
    required this.activeLearnerId,
    required this.onProfileSelected,
  });

  @override
  ConsumerState<_SwitchProfileDialog> createState() =>
      _SwitchProfileDialogState();
}

class _SwitchProfileDialogState extends ConsumerState<_SwitchProfileDialog> {
  String? _switchingLearnerId;

  Future<void> _handleTap(ProfileSummaryModel profile) async {
    setState(() => _switchingLearnerId = profile.learnerId);
    await widget.onProfileSelected(profile);
    if (mounted) setState(() => _switchingLearnerId = null);
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(
      profilesPageDataProvider(ProfilesPageRequest(phone: widget.phone)),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Switch Profile',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F1F4),
                    ),
                  ),
                ],
              ),
              Text(
                'Hi Champ, please select who I will talk to',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 18),
              profilesAsync.when(
                data: (profiles) {
                  if (profiles.isEmpty) {
                    return Text(
                      'No student profiles found for this account.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6E6E7A),
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < profiles.length; i++) ...[
                        _ProfileOption(
                          profile: profiles[i],
                          selected:
                              profiles[i].learnerId == widget.activeLearnerId,
                          loading: _switchingLearnerId == profiles[i].learnerId,
                          onTap: _switchingLearnerId == null
                              ? () => _handleTap(profiles[i])
                              : null,
                        ),
                        if (i != profiles.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Text(
                  'Could not load profiles. Please try again.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFD34B40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final ProfileSummaryModel profile;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _ProfileOption({
    required this.profile,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (profile.grade != null) 'Grade ${profile.grade}',
      if (profile.division != null) profile.division,
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8E5FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E2EA)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE8E5FF),
              child: Text(
                _initials(profile.studentName),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.buttonColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.studentName.isEmpty
                        ? 'Student'
                        : profile.studentName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF6E6E7A),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE1E2EA)),
                ),
                child: Text(
                  selected ? 'Selected ✓' : 'Select',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppTheme.buttonColor
                        : const Color(0xFF1C1C21),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhiteCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: child,
    );
  }
}
