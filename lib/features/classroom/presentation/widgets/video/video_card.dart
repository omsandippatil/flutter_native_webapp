import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/presentation/widgets/video/youtube_embed_stub.dart'
    if (dart.library.html) 'package:tapapp/features/classroom/presentation/widgets/video/youtube_embed_web.dart';

class ClassVideoCard extends StatefulWidget {
  const ClassVideoCard({
    required this.message,
    required this.controller,
    super.key,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<ClassVideoCard> createState() => _ClassVideoCardState();
}

class _ClassVideoCardState extends State<ClassVideoCard> {
  YoutubePlayerController? _ytController;
  String? _initializedForYoutubeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final youtubeId = widget.message.data['youtubeId'] as String? ?? '';
    if (youtubeId.isNotEmpty) {
      _ensureController(youtubeId);
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  void _ensureController(String youtubeId) {
    if (_initializedForYoutubeId == youtubeId && _ytController != null) return;
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        forceHD: false,
      ),
    )..cue(youtubeId);
    _initializedForYoutubeId = youtubeId;
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final watched = widget.message.data['watched'] == true;
    final title = widget.message.data['title'] as String? ?? '';
    final points = widget.message.data['points'] as int? ?? 0;
    final youtubeId = widget.message.data['youtubeId'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: scale.md, vertical: scale.sm),
          decoration: BoxDecoration(
            color: AppTheme.classroomMessageSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Watch the video 👇',
                style: AppTheme.text(size: 14, weight: FontWeight.w500),
              ),
              SizedBox(width: scale.md),
              const Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: AppTheme.buttonColor,
              ),
            ],
          ),
        ),
        SizedBox(height: scale.sm),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(scale.sm),
          decoration: BoxDecoration(
            color: AppTheme.classroomMessageSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: youtubeId.isEmpty
                    ? const _EmptyVideoPlaceholder()
                    : kIsWeb
                    ? _WebYoutubePlayer(youtubeId: youtubeId)
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _ytController == null
                            ? Container(color: AppTheme.classroomMessageSurface)
                            : YoutubePlayer(
                                key: ValueKey('yt_$youtubeId'),
                                controller: _ytController!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: AppTheme.buttonColor,
                              ),
                      ),
              ),
              SizedBox(height: scale.sm),
              Text(
                'Watch: $title',
                style: AppTheme.text(size: 14, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(height: scale.sm),
        SizedBox(
          width: double.infinity,
          height: scale.buttonHeight + 4,
          child: ElevatedButton(
            onPressed: watched ? null : widget.controller.markVideoWatched,
            style: AppTheme.primaryButtonStyle(
              disabledColor: AppTheme.dividerColor,
            ),
            child: Text(
              watched ? 'Watched' : 'I watched it • +$points points',
              style: AppTheme.text(
                size: 16,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyVideoPlaceholder extends StatelessWidget {
  const _EmptyVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: AppTheme.classroomMessageSurface,
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            size: 72,
            color: AppTheme.buttonColor,
          ),
        ),
      ),
    );
  }
}

class _WebYoutubePlayer extends StatelessWidget {
  const _WebYoutubePlayer({required this.youtubeId});

  final String youtubeId;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: AppTheme.classroomMessageSurface,
        child: buildYoutubeEmbed(youtubeId),
      ),
    );
  }
}