import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_nav.dart';

enum _ProfileTab { profile, settings, about }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _ProfileTab _activeTab = _ProfileTab.profile;
  late final Future<Map<String, dynamic>> _aboutFuture = _loadAboutTap();

  Future<Map<String, dynamic>> _loadAboutTap() async {
    final raw = await rootBundle.loadString(
      'assets/profile-screen/about_tap.json',
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return AppNav(
      child: Scaffold(
        backgroundColor: AppTheme.appBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _SwitchProfileBar(onPressed: _showSwitchProfile),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
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
                                        onChanged: (tab) =>
                                            setState(() => _activeTab = tab),
                                      ),
                                    ),
                                    const SizedBox(width: 34),
                                    Expanded(child: _activeContent()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _ProfileSideNav(
                                      activeTab: _activeTab,
                                      onChanged: (tab) =>
                                          setState(() => _activeTab = tab),
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
    return switch (_activeTab) {
      _ProfileTab.profile => const _ProfileDetailsView(),
      _ProfileTab.settings => const _SettingsView(),
      _ProfileTab.about => _AboutTapView(aboutFuture: _aboutFuture),
    };
  }

  void _showSwitchProfile() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => const _SwitchProfileDialog(),
    );
  }
}

class _SwitchProfileBar extends StatelessWidget {
  final VoidCallback onPressed;

  const _SwitchProfileBar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;

    return Container(
      height: compact ? 92 : 74,
      color: AppTheme.profileBar,
      child: Center(
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwitchProfileText(),
                  const SizedBox(height: 10),
                  _SwitchProfileButton(onPressed: onPressed),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SwitchProfileText(),
                  const SizedBox(width: 18),
                  _SwitchProfileButton(onPressed: onPressed),
                ],
              ),
      ),
    );
  }
}

class _SwitchProfileText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Not Arav? Switch to your profile',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textColor,
      ),
    );
  }
}

class _SwitchProfileButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SwitchProfileButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: const Text('Switch Profile'),
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
    final items = [
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
  const _ProfileDetailsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _StudentSummaryCard(),
        SizedBox(height: 16),
        _ReadOnlySection(
          title: 'Personal Details',
          children: [
            _ReadOnlyField(label: 'First name', value: 'Aarav'),
            _ReadOnlyField(label: 'Last name', value: 'Kumar'),
            _ReadOnlyField(label: 'Language', value: 'Hindi'),
            _ReadOnlyField(
              label: 'Is a brother or sister also using TAP?',
              value: 'No',
            ),
            _ReadOnlyField(label: 'Phone number', value: 'Verified'),
          ],
        ),
        SizedBox(height: 10),
        _ReadOnlySection(
          title: 'School Details',
          children: [
            _ReadOnlyField(
              label: 'School Name',
              value: 'Sarvodaya Co-ed Vidyalaya, Rohini',
            ),
            _ReadOnlyField(label: 'Grade', value: '5'),
            _ReadOnlyField(label: 'Subject', value: 'Science'),
          ],
        ),
      ],
    );
  }
}

class _StudentSummaryCard extends StatelessWidget {
  const _StudentSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE8E5FF),
            child: Text('AK', style: TextStyle(color: AppTheme.buttonColor)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Aarav Kumar',
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
                  text: 'Sarvodaya Co-ed Vidyalaya, Rohini',
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: const [
                    _MetaLine(icon: Icons.menu_book_rounded, text: 'Grade 5'),
                    _MetaLine(icon: Icons.hub_rounded, text: 'Science Lab'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF24A866)),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6E6E7A),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ReadOnlySection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
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
        ],
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ThemeCard(),
        SizedBox(height: 16),
        _AccountManagementCard(),
      ],
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
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
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
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsTitle('Theme'),
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
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
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
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'Delete Account',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD34B40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTapView extends StatelessWidget {
  final Future<Map<String, dynamic>> aboutFuture;

  const _AboutTapView({required this.aboutFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: aboutFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _ProfileSkeleton();
        final data = snapshot.data!;
        final mission = data['mission'] as Map<String, dynamic>;
        final problem = data['problem'] as Map<String, dynamic>;
        final solution = data['solution'] as Map<String, dynamic>;

        return _WhiteCard(
          padding: const EdgeInsets.all(18),
          child: Column(
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
      },
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(path, fit: BoxFit.contain),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
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

class _SwitchProfileDialog extends StatelessWidget {
  const _SwitchProfileDialog();

  @override
  Widget build(BuildContext context) {
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
              const _ProfileOption(
                initials: 'AK',
                name: 'Aarav Kumar',
                meta: 'Grade 4 • Science',
                selected: true,
              ),
              const SizedBox(height: 12),
              const _ProfileOption(
                initials: 'AK',
                name: 'Ajay Kumar',
                meta: 'Grade 8 • Financial Literacy',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final String initials;
  final String name;
  final String meta;
  final bool selected;

  const _ProfileOption({
    required this.initials,
    required this.name,
    required this.meta,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              initials,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
    );
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
