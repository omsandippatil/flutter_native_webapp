import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/core/flow/flow.dart';
import 'package:tapapp/core/theme/theme.dart';

import 'package:flutter/services.dart' show rootBundle;

class ChatAudioPlaybackController extends ChangeNotifier {
  ChatAudioPlaybackController() : _player = AudioPlayer() {
    _completeSub = _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _hasFinished = true;
      notifyListeners();
    });
  }

  final AudioPlayer _player;
  StreamSubscription<void>? _completeSub;

  String? get currentlyPlayingId => _currentlyPlayingId;
  String? _currentlyPlayingId;

  bool get isPlaying => _isPlaying;
  bool _isPlaying = false;

  bool get hasFinished => _hasFinished;
  bool _hasFinished = false;

  Future<void> play(ChatAudioRef audio) async {
    final path = audio.path;
    if (path == null) return;
    if (_currentlyPlayingId != null && _currentlyPlayingId != audio.audioId) {
      await _player.stop();
    }
    _currentlyPlayingId = audio.audioId;
    _hasFinished = false;
    _isPlaying = true;
    notifyListeners();
    await _player.play(AssetSource(_toAssetSourcePath(path)));
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> replay(ChatAudioRef audio) async {
    await _player.stop();
    await play(audio);
  }

  String _toAssetSourcePath(String path) =>
      path.startsWith('assets/') ? path.substring('assets/'.length) : path;

  @override
  void dispose() {
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}

class ChatAudioSourceResolver {
  ChatAudioSourceResolver(this._flowManifestRepository);

  final FlowManifestRepository _flowManifestRepository;

  static const String _basePath = 'assets/audio';

  Future<String?> resolve(String? audioId, {required String languageCode}) async {
    if (audioId == null || audioId.isEmpty) return null;
    await _flowManifestRepository.load(languageCode);
    final candidate = '$_basePath/$languageCode/$audioId.mp3';
    if (await _assetExists(candidate)) return candidate;
    const fallbackLanguage = 'en';
    if (languageCode != fallbackLanguage) {
      final fallback = '$_basePath/$fallbackLanguage/$audioId.mp3';
      if (await _assetExists(fallback)) return fallback;
    }
    return null;
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ChatAudioPlayerButton extends StatelessWidget {
  const ChatAudioPlayerButton({
    super.key,
    required this.audio,
    required this.controller,
  });

  final ChatAudioRef audio;
  final ChatAudioPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    if (audio.path == null) return const SizedBox.shrink();
    final scale = AppSpacing.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isThisPlaying =
            controller.isPlaying && controller.currentlyPlayingId == audio.audioId;
        final hasFinishedThis =
            controller.hasFinished && controller.currentlyPlayingId == audio.audioId;

        return InkWell(
          onTap: () {
            if (isThisPlaying) {
              controller.pause();
            } else if (hasFinishedThis) {
              controller.replay(audio);
            } else {
              controller.play(audio);
            }
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: scale.md),
            decoration: BoxDecoration(
              color: AppTheme.chipLavender,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isThisPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                  size: 15,
                  color: AppTheme.buttonColor,
                ),
                SizedBox(width: scale.xs - 1),
                Text(
                  isThisPlaying ? 'Playing' : 'Hear again',
                  style: AppTheme.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.buttonColor,
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
