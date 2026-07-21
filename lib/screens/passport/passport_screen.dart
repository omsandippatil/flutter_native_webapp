import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_models.dart';
import '../../providers/home_dashboard_provider.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/loading_view.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(learningDashboardProvider);

    return AppNav(
      child: Scaffold(
        backgroundColor: AppTheme.appBackground,
        body: dashboardAsync.when(
          loading: () => const LoadingView(),
          error: (err, stack) => Center(child: Text('Failed to load passport')),
          data: (dashboard) => _PassportDashboard(dashboard: dashboard),
        ),
      ),
    );
  }
}

class _PassportDashboard extends StatelessWidget {
  final LearningDashboard dashboard;

  const _PassportDashboard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final progress = dashboard.progress;
    final points = progress.points;
    final gems = progress.skillGems;
    final streak = progress.streakDay;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;

        return SafeArea(
          bottom: false,
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1060),
              color: AppTheme.cardBackground,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 20,
                  18,
                  isWide ? 24 : 20,
                  96,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PassportLogos(),
                    const SizedBox(height: 22),
                    isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ProgressColumn(
                                  studentName: progress.studentName,
                                  points: points,
                                  gems: gems,
                                  streak: streak,
                                ),
                              ),
                              const SizedBox(width: 28),
                              _StudentProfileCard(
                                studentName: progress.studentName,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _ProgressColumn(
                                studentName: progress.studentName,
                                points: points,
                                gems: gems,
                                streak: streak,
                              ),
                              const SizedBox(height: 22),
                              _StudentProfileCard(
                                studentName: progress.studentName,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PassportLogos extends StatelessWidget {
  const _PassportLogos();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LogoTile(path: 'assets/logos/gov-logo.png'),
        const SizedBox(width: 10),
        _LogoTile(path: 'assets/logos/tap-otherLogo.png'),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  final String path;

  const _LogoTile({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 42,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.fieldBackground,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Image.asset(path, fit: BoxFit.contain),
    );
  }
}

class _ProgressColumn extends StatelessWidget {
  final String studentName;
  final int points;
  final int gems;
  final int streak;

  const _ProgressColumn({
    required this.studentName,
    required this.points,
    required this.gems,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hey $studentName 👋',
          style: GoogleFonts.inter(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: AppTheme.headingText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Have a look at your progress',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedText,
          ),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final rankCards = [
              _RankProgressCard(
                title: 'Bronze Buddy',
                value: points,
                target: 500,
                unitLabel: 'points',
                icon: Icons.workspace_premium_rounded,
                iconBg: const Color(0xFFC17A43),
                iconColor: const Color(0xFF6B3B20),
              ),
              _RankProgressCard(
                title: 'Skill Gems',
                value: gems,
                target: 50,
                unitLabel: 'gems',
                icon: Icons.diamond_rounded,
                iconBg: AppTheme.gemBg,
                iconColor: AppTheme.buttonColor,
              ),
              _RankProgressCard(
                title: 'Streak',
                value: streak,
                target: 30,
                unitLabel: 'days',
                icon: Icons.water_drop_rounded,
                iconBg: AppTheme.streakBg,
                iconColor: AppTheme.streakColor,
              ),
            ];

            if (narrow) {
              return Column(
                children: [
                  for (final card in rankCards) ...[
                    card,
                    if (card != rankCards.last) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final card in rankCards) ...[
                  Expanded(child: card),
                  if (card != rankCards.last) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Text(
          'Your Achievements Champ!',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.headingText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final cards = [
              _AchievementCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppTheme.pointColor,
                iconBg: AppTheme.pointBg,
                value: '$points',
                label: 'Points',
                title: 'What are points',
                description: 'Earn points by doing TAP Activities every week!',
              ),
              _AchievementCard(
                icon: Icons.diamond_rounded,
                iconColor: AppTheme.buttonColor,
                iconBg: AppTheme.gemBg,
                value: '$gems',
                label: 'Skill Gems',
                title: 'What are skill gems',
                description:
                    'You earn 1 skill gem for every submission you make.',
              ),
              _AchievementCard(
                icon: Icons.water_drop_rounded,
                iconColor: AppTheme.streakColor,
                iconBg: AppTheme.streakBg,
                value: '$streak',
                label: 'Streak',
                title: 'What are streaks',
                description:
                    'If you forget to submit your streak resets to zero.',
              ),
            ];

            if (narrow) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final card in cards) ...[
                      SizedBox(width: 128, child: card),
                      if (card != cards.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              );
            }

            return Row(
              children: [
                for (final card in cards) ...[
                  Expanded(child: card),
                  if (card != cards.last) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RankProgressCard extends StatelessWidget {
  final String title;
  final int value;
  final int target;
  final String unitLabel;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _RankProgressCard({
    required this.title,
    required this.value,
    required this.target,
    required this.unitLabel,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, target);
    final remaining = target - clamped;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.headingText,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: target == 0 ? 0 : clamped / target,
                    minHeight: 5,
                    backgroundColor: AppTheme.chatBubble,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '$clamped/$target',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.headingText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$remaining $unitLabel remaining',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.headingText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String title;
  final String description;

  const _AchievementCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.title,
    required this.description,
  });

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _hovered = !_hovered),
        child: SizedBox(
          height: 152,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) {
                  final rotation = (1 - animation.value) * math.pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(rotation),
                    child: child,
                  );
                },
              );
            },
            child: _hovered
                ? _AchievementBack(
                    key: ValueKey('${widget.label}-back'),
                    icon: widget.icon,
                    iconColor: widget.iconColor,
                    iconBg: widget.iconBg,
                    title: widget.title,
                    description: widget.description,
                  )
                : _AchievementFront(
                    key: ValueKey('${widget.label}-front'),
                    icon: widget.icon,
                    iconColor: widget.iconColor,
                    iconBg: widget.iconBg,
                    value: widget.value,
                    label: widget.label,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AchievementFront extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _AchievementFront({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AchievementIcon(icon: icon, iconColor: iconColor, iconBg: iconBg),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppTheme.subheadingColor,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: AppTheme.subheadingColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementBack extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  const _AchievementBack({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        final textColumn = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: compact ? 11 : 14,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: AppTheme.subheadingColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: compact ? 10 : 13,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        );

        return Container(
          height: 152,
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AchievementIcon(
                      icon: icon,
                      iconColor: iconColor,
                      iconBg: iconBg,
                      small: true,
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: textColumn),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AchievementIcon(
                      icon: icon,
                      iconColor: iconColor,
                      iconBg: iconBg,
                      small: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: textColumn),
                  ],
                ),
        );
      },
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool small;

  const _AchievementIcon({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 42.0 : 66.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: small ? 22 : 32),
    );
  }
}

class _StudentProfileCard extends StatelessWidget {
  final String studentName;

  const _StudentProfileCard({required this.studentName});

  @override
  Widget build(BuildContext context) {
    final initials = studentName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 270,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFE8E5FF),
            child: Text(
              initials.isEmpty ? 'AK' : initials,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.buttonColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            studentName,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF25252C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Junior Buddy 🌱',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF777887),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 16,
                color: Color(0xFF24A866),
              ),
              const SizedBox(width: 5),
              Text(
                'Grade 4',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6F7080),
                ),
              ),
              const SizedBox(width: 10),
              const Text('•', style: TextStyle(color: Color(0xFF8E8E9F))),
              const SizedBox(width: 10),
              const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF24A866)),
              const SizedBox(width: 5),
              Text(
                'Science Lab',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6F7080),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Image.asset(
            'assets/class-screen/Skill Passport 1.png',
            height: 260,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
