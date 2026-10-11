import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/action/action.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';
import 'package:tapapp/chat/blocks/youtube_embed.dart';

class VideoBlock extends StatefulWidget {
  const VideoBlock({super.key, required this.item, required this.ctx});

  final VideoItem item;
  final ChatRenderContext ctx;

  @override
  State<VideoBlock> createState() => _VideoBlockState();
}

class _VideoBlockState extends State<VideoBlock> {
  YoutubePlayerController? _ytController;
  String? _initializedForYoutubeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final youtubeId = widget.item.youtubeId;
    if (youtubeId.isNotEmpty) _ensureController(youtubeId);
  }

  @override
  void didUpdateWidget(covariant VideoBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) return;
    final youtubeId = widget.item.youtubeId;
    if (youtubeId.isNotEmpty && youtubeId != _initializedForYoutubeId) {
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
    final item = widget.item;
    final youtubeId = item.youtubeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.classroomMessageSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Watch the video', style: AppTheme.text(size: 14, weight: FontWeight.w500)),
              const SizedBox(width: 16),
              const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.buttonColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ColoredBox(
                              color: AppTheme.classroomMessageSurface,
                              child: buildYoutubeEmbed(youtubeId),
                            ),
                          )
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
              const SizedBox(height: 12),
              Text('Watch: ${item.title}', style: AppTheme.text(size: 14, weight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: item.watched
                ? null
                : () => widget.ctx.onAction(
                      ChatAction.watchVideo,
                      data: {'stepId': item.stepId, 'videoId': item.videoId},
                    ),
            style: AppTheme.primaryButtonStyle(disabledColor: AppTheme.dividerColor),
            child: Text(
              item.watched ? 'Watched' : 'I watched it • +${item.points} points',
              style: AppTheme.text(size: 16, weight: FontWeight.w800, color: Colors.white),
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
          child: Icon(Icons.play_arrow_rounded, size: 72, color: AppTheme.buttonColor),
        ),
      ),
    );
  }
} 