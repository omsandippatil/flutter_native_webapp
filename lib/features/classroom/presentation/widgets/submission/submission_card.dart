import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/models/submission_answer.dart';
import 'package:tapapp/features/classroom/presentation/widgets/states/card_shell.dart';

class ClassSubmissionCard extends StatefulWidget {
  const ClassSubmissionCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<ClassSubmissionCard> createState() => _ClassSubmissionCardState();
}

class _ClassSubmissionCardState extends State<ClassSubmissionCard> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedEmoji;
  XFile? _pickedMedia;
  Uint8List? _pickedMediaBytes;
  bool _isVideoPick = false;
  bool _isPicking = false;
  bool _submitted = false;
  bool _pickError = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _markSubmitted() {
    setState(() => _submitted = true);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPicking = true;
      _pickError = false;
    });
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _pickedMedia = file;
          _pickedMediaBytes = bytes;
          _isVideoPick = false;
        });
      }
    } catch (_) {
      _handlePickFailure();
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    setState(() {
      _isPicking = true;
      _pickError = false;
    });
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file != null) {
        if (!mounted) return;
        setState(() {
          _pickedMedia = file;
          _pickedMediaBytes = null;
          _isVideoPick = true;
        });
      }
    } catch (_) {
      _handlePickFailure();
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _handlePickFailure() {
    if (!mounted) return;
    setState(() => _pickError = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't access that. Please try again.")),
    );
  }

  Future<void> _showMediaSourceSheet({
    required bool allowVideo,
    bool forceVideo = false,
  }) async {
    final choice = await showModalBottomSheet<_MediaPickChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.of(context).xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!forceVideo) ...[
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () =>
                      Navigator.pop(context, _MediaPickChoice.cameraImage),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose photo from gallery'),
                  onTap: () =>
                      Navigator.pop(context, _MediaPickChoice.galleryImage),
                ),
              ],
              if (allowVideo) ...[
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Record a video'),
                  onTap: () =>
                      Navigator.pop(context, _MediaPickChoice.cameraVideo),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Choose video from gallery'),
                  onTap: () =>
                      Navigator.pop(context, _MediaPickChoice.galleryVideo),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    switch (choice) {
      case _MediaPickChoice.cameraImage:
        await _pickImage(ImageSource.camera);
      case _MediaPickChoice.galleryImage:
        await _pickImage(ImageSource.gallery);
      case _MediaPickChoice.cameraVideo:
        await _pickVideo(ImageSource.camera);
      case _MediaPickChoice.galleryVideo:
        await _pickVideo(ImageSource.gallery);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final guidedText = widget.message.data['guidedText'] as String?;
    final unguidedText = widget.message.data['unguidedText'] as String? ?? '';
    final validCriteria = widget.message.data['validCriteria'] as String?;
    final subTypes = widget.message.data['subTypes'] as String? ?? '';
    final kind = SubmissionKindResolver.fromSubTypes(subTypes);
    final stepNumber = widget.message.data['stepNumber'] as int?;
    final stepTotal = widget.message.data['stepTotal'] as int?;
    final canInteract = widget.controller.isAwaitingInput && !_submitted;
    final prompt = guidedText?.isNotEmpty == true ? guidedText! : unguidedText;

    return ClassCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: scale.xs,
            runSpacing: scale.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _SubmissionChip(
                label: "TODAY'S ACTIVITY 🏎️🏎️",
                foregroundColor: AppTheme.buttonColor,
              ),
              _SubmissionChip(label: _kindLabel(kind)),
              if (stepNumber != null && stepTotal != null)
                _SubmissionChip(label: 'STEP $stepNumber/$stepTotal'),
            ],
          ),
          SizedBox(height: scale.md),
          _ExamplePreview(
            height: scale.previewHeight,
            hasMedia: _pickedMedia != null,
            isVideo: _isVideoPick,
            mediaBytes: _pickedMediaBytes,
            onTap: canInteract && _isMediaKind(kind)
                ? () => _showMediaSourceSheet(
                    allowVideo: kind != SubmissionKind.image,
                    forceVideo: kind == SubmissionKind.video,
                  )
                : _showSubmissionHelpDialog,
          ),
          SizedBox(height: scale.md),
          Text(
            prompt,
            style: AppTheme.text(size: 16, weight: FontWeight.w800, height: 1.35),
          ),
          if (unguidedText.isNotEmpty && guidedText?.isNotEmpty == true) ...[
            SizedBox(height: scale.xxs),
            Text(
              unguidedText,
              style: AppTheme.text(
                size: 12,
                height: 1.4,
                color: AppTheme.subheadingColor,
              ),
            ),
          ],
          if (validCriteria?.isNotEmpty == true) ...[
            SizedBox(height: scale.xs),
            Text(
              'I will check for: $validCriteria',
              style: AppTheme.text(
                size: 11,
                height: 1.4,
                color: AppTheme.subheadingColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: scale.md),
          if (_showFriendExamples(kind)) ...[
            Text(
              _friendLabel(kind),
              style: AppTheme.text(size: 12, color: AppTheme.subheadingColor),
            ),
            SizedBox(height: scale.xs),
          ],
          if (_pickError) ...[
            _ErrorNotice(
              message: "We couldn't load that file. Please try picking it again.",
            ),
            SizedBox(height: scale.sm),
          ],
          _buildInputForKind(kind, canInteract),
        ],
      ),
    );
  }

  Widget _buildInputForKind(SubmissionKind kind, bool canInteract) {
    switch (kind) {
      case SubmissionKind.emoji:
        return _emojiInput(canInteract);
      case SubmissionKind.text:
        return _textSubmissionInput(
          canInteract: canInteract,
          hintText: 'Type your answer here...',
          onSubmit: () {
            final value = _textController.text.trim();
            if (value.isEmpty) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.text(value),
            );
            _markSubmitted();
          },
        );
      case SubmissionKind.textAudio:
      case SubmissionKind.audio:
        return _textSubmissionInput(
          canInteract: canInteract,
          hintText: 'Type or transcribe your answer here...',
          onSubmit: () {
            final value = _textController.text.trim();
            if (value.isEmpty) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.audioTranscript(value),
            );
            _markSubmitted();
          },
        );
      case SubmissionKind.image:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: false,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.image(_pickedMedia!.path),
            );
            _markSubmitted();
          },
        );
      case SubmissionKind.video:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          forceVideo: true,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.video(_pickedMedia!.path),
            );
            _markSubmitted();
          },
        );
      case SubmissionKind.imageVideo:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.imageOrVideo(
                _pickedMedia!.path,
                isVideo: _isVideoPick,
              ),
            );
            _markSubmitted();
          },
        );
    }
  }

  Widget _emojiInput(bool canInteract) {
    final scale = AppSpacing.of(context);
    const emojis = ['👍', '👎', '😊', '😕', '💪', '🤔'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: scale.xs + 2,
          runSpacing: scale.xs + 2,
          children: emojis.map((emoji) {
            final selected = _selectedEmoji == emoji;
            return InkWell(
              onTap: canInteract
                  ? () => setState(() => _selectedEmoji = emoji)
                  : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: EdgeInsets.all(scale.xs + 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.mutedLavender
                      : AppTheme.classroomMessageSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: selected ? AppTheme.buttonColor : Colors.transparent,
                  ),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: scale.md),
        _submitRow(
          onPressed: (canInteract && _selectedEmoji != null)
              ? () {
                  widget.controller.submitAssignmentAnswer(
                    SubmissionAnswer.emoji(_selectedEmoji!),
                  );
                  _markSubmitted();
                }
              : null,
        ),
      ],
    );
  }

  Widget _textSubmissionInput({
    required bool canInteract,
    required String hintText,
    required VoidCallback onSubmit,
  }) {
    final scale = AppSpacing.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          enabled: canInteract,
          maxLines: 4,
          style: AppTheme.text(size: 14, height: 1.45),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: AppTheme.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: scale.md),
        _submitRow(onPressed: canInteract ? onSubmit : null),
      ],
    );
  }

  Widget _buildMediaPicker({
    required bool canInteract,
    required bool allowVideo,
    required VoidCallback onSubmit,
    bool forceVideo = false,
  }) {
    final scale = AppSpacing.of(context);
    final hasMedia = _pickedMedia != null;
    void openPicker() =>
        _showMediaSourceSheet(allowVideo: allowVideo, forceVideo: forceVideo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: scale.xs + 2,
          runSpacing: scale.xs + 2,
          children: _mediaFriendExamples(forceVideo: forceVideo)
              .map(
                (emoji) => _FriendExampleTile(
                  label: emoji,
                  onTap: canInteract ? openPicker : null,
                ),
              )
              .toList(),
        ),
        if (hasMedia) ...[
          SizedBox(height: scale.sm),
          InkWell(
            onTap: canInteract ? openPicker : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(scale.xs + 2),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _isVideoPick
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                    color: AppTheme.buttonColor,
                  ),
                  SizedBox(width: scale.xs),
                  Expanded(
                    child: Text(
                      _pickedMedia!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.text(size: 13, weight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.refresh_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: scale.md),
        _submitRow(
          primaryLabel: hasMedia ? 'Share submission' : 'Submit',
          isLoading: _isPicking,
          onPressed: !canInteract || _isPicking
              ? null
              : (hasMedia ? onSubmit : openPicker),
        ),
      ],
    );
  }

  Widget _submitRow({
    required VoidCallback? onPressed,
    String primaryLabel = 'Submit',
    bool isLoading = false,
  }) {
    final scale = AppSpacing.of(context);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: scale.buttonHeight - 6,
            child: ElevatedButton(
              onPressed: onPressed,
              style: AppTheme.primaryButtonStyle(
                disabledColor: AppTheme.dividerColor,
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
                  : Text(_submitted ? 'Sent' : primaryLabel),
            ),
          ),
        ),
        SizedBox(width: scale.xs + 2),
        SizedBox(
          height: scale.buttonHeight - 6,
          child: OutlinedButton(
            onPressed: _showSubmissionHelpDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.subheadingColor,
              side: const BorderSide(color: AppTheme.dividerColor),
              padding: EdgeInsets.symmetric(horizontal: scale.md),
            ),
            child: const Text('Submission Help'),
          ),
        ),
      ],
    );
  }

  bool _isMediaKind(SubmissionKind kind) =>
      kind == SubmissionKind.image ||
      kind == SubmissionKind.video ||
      kind == SubmissionKind.imageVideo;

  bool _showFriendExamples(SubmissionKind kind) =>
      kind == SubmissionKind.emoji || _isMediaKind(kind);

  String _friendLabel(SubmissionKind kind) => switch (kind) {
    SubmissionKind.emoji => 'Friends sent 👀',
    SubmissionKind.text ||
    SubmissionKind.textAudio ||
    SubmissionKind.audio => 'Friends said 👀',
    _ => 'See what friends made 👀',
  };

  List<String> _mediaFriendExamples({required bool forceVideo}) =>
      forceVideo ? const ['🎥', '🎬', '🚀'] : const ['🐱', '🚀', '🌈'];

  String _kindLabel(SubmissionKind kind) => switch (kind) {
    SubmissionKind.emoji => '👉 EMOJI',
    SubmissionKind.text => '💬 TEXT',
    SubmissionKind.audio => '🎤 AUDIO',
    SubmissionKind.textAudio => '💬 TEXT / 🎤 AUDIO',
    SubmissionKind.image => '🖼️ SCREENSHOT',
    SubmissionKind.video => '🎥 VIDEO',
    SubmissionKind.imageVideo => '🖼️ SCREENSHOT / 🎥 VIDEO',
  };

  Future<void> _showSubmissionHelpDialog() async {
    final scale = AppSpacing.of(context);
    final guidedText = widget.message.data['guidedText'] as String?;
    final unguidedText = widget.message.data['unguidedText'] as String? ?? '';
    final validCriteria = widget.message.data['validCriteria'] as String?;
    final subTypes = widget.message.data['subTypes'] as String? ?? '';
    final kind = SubmissionKindResolver.fromSubTypes(subTypes);

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: scale.md,
          vertical: scale.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: EdgeInsets.all(scale.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SubmissionChip(
                      label: "TODAY'S ACTIVITY 🏎️🏎️",
                      foregroundColor: AppTheme.buttonColor,
                    ),
                    SizedBox(width: scale.xs),
                    _SubmissionChip(label: _kindLabel(kind)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: scale.sm),
                Center(
                  child: Text(
                    'How to submit',
                    style: AppTheme.text(size: 16, weight: FontWeight.w800),
                  ),
                ),
                SizedBox(height: scale.sm),
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 34,
                    color: AppTheme.imagePlaceholder,
                  ),
                ),
                SizedBox(height: scale.md),
                Text(
                  guidedText?.isNotEmpty == true ? guidedText! : unguidedText,
                  style: AppTheme.text(size: 14, height: 1.45),
                ),
                if (validCriteria?.isNotEmpty == true) ...[
                  SizedBox(height: scale.xs),
                  Text(
                    'Check: $validCriteria',
                    style: AppTheme.text(
                      size: 12,
                      height: 1.4,
                      color: AppTheme.subheadingColor,
                    ),
                  ),
                ],
                SizedBox(height: scale.lg),
                SizedBox(
                  width: double.infinity,
                  height: scale.buttonHeight - 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AppTheme.primaryButtonStyle(),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MediaPickChoice { cameraImage, galleryImage, cameraVideo, galleryVideo }

class _SubmissionChip extends StatelessWidget {
  const _SubmissionChip({
    required this.label,
    this.foregroundColor = AppTheme.textColor,
  });

  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: scale.sm - 2, vertical: scale.xs - 2),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Text(
        label,
        style: AppTheme.text(
          size: 11,
          weight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _ExamplePreview extends StatelessWidget {
  const _ExamplePreview({
    required this.height,
    required this.hasMedia,
    required this.isVideo,
    required this.mediaBytes,
    required this.onTap,
  });

  final double height;
  final bool hasMedia;
  final bool isVideo;
  final Uint8List? mediaBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
          child: hasMedia
              ? (isVideo
                    ? const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 54,
                          color: AppTheme.buttonColor,
                        ),
                      )
                    : mediaBytes != null
                    ? Image.memory(
                        mediaBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
              : const Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: AppTheme.imagePlaceholder,
                ),
        ),
      ),
    );
  }
}

class _FriendExampleTile extends StatelessWidget {
  const _FriendExampleTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: 68,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.dividerColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Text(label, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.sm),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppTheme.dangerText,
          ),
          SizedBox(width: scale.xs),
          Expanded(
            child: Text(
              message,
              style: AppTheme.text(size: 13, color: AppTheme.dangerText),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassSubmissionReviewCard extends StatelessWidget {
  const ClassSubmissionReviewCard({required this.message, super.key});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final feedback = message.data['feedback'] as String?;
    final score = message.data['score'] as int?;
    final passed = message.data['passed'] as bool?;
    final text = message.text ?? '';
    final failed = passed == false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(scale.lg, scale.md, scale.lg, scale.lg),
      decoration: BoxDecoration(
        color: failed ? AppTheme.dangerSurface : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: failed ? AppTheme.dangerBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppTheme.dangerText,
                ),
                SizedBox(width: scale.xs),
              ],
              Expanded(
                child: Text(
                  text,
                  style: AppTheme.text(
                    size: 17,
                    weight: FontWeight.w700,
                    height: 1.3,
                    color: failed ? AppTheme.dangerText : AppTheme.textColor,
                  ),
                ),
              ),
              if (score != null) ...[
                SizedBox(width: scale.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: scale.sm,
                    vertical: scale.xs,
                  ),
                  decoration: BoxDecoration(
                    color: failed ? AppTheme.dangerChip : AppTheme.successSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Score: $score',
                    style: AppTheme.text(
                      size: 13,
                      weight: FontWeight.w800,
                      color: failed ? AppTheme.dangerText : AppTheme.successText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            SizedBox(height: scale.sm),
            Text(
              feedback,
              style: AppTheme.text(
                size: 15,
                height: 1.5,
                color: failed ? AppTheme.dangerText : AppTheme.subheadingColor,
              ),
            ),
          ],
          if (failed) ...[
            SizedBox(height: scale.xs),
            Text(
              'No submission points were added for this attempt.',
              style: AppTheme.text(
                size: 12,
                weight: FontWeight.w600,
                color: AppTheme.dangerText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ClassSubmissionRewardCard extends StatelessWidget {
  const ClassSubmissionRewardCard({
    required this.message,
    required this.controller,
    super.key,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final studentName = message.data['studentName'] as String? ?? 'Champ';
    final points = (message.data['points'] as num?)?.toInt() ?? 0;

    return Container(
      width: 320,
      padding: EdgeInsets.fromLTRB(scale.md, scale.md, scale.md, scale.lg),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.volume_up_rounded,
              size: 18,
              color: AppTheme.buttonColor,
            ),
          ),
          Image.asset(
            'assets/images/classroom/Skill_Passport_1.png',
            height: 235,
            fit: BoxFit.contain,
          ),
          SizedBox(height: scale.xs),
          Text(
            'Congratulations $studentName!!!🥳',
            textAlign: TextAlign.center,
            style: AppTheme.text(
              size: 20,
              weight: FontWeight.w900,
              color: AppTheme.textColor,
            ),
          ),
          SizedBox(height: scale.sm),
          Container(
            padding: EdgeInsets.symmetric(horizontal: scale.md, vertical: scale.xs + 2),
            decoration: BoxDecoration(
              color: AppTheme.rewardGold,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              '⊙ +$points pts',
              style: AppTheme.text(
                size: 14,
                weight: FontWeight.w800,
                color: AppTheme.textColor,
              ),
            ),
          ),
          SizedBox(height: scale.md),
          Text(
            'You have won $points points🪙😍\nYou did a great job champion!',
            textAlign: TextAlign.center,
            style: AppTheme.text(size: 15, height: 1.4, color: AppTheme.textColor),
          ),
          SizedBox(height: scale.lg),
          SizedBox(
            width: double.infinity,
            height: scale.buttonHeight - 2,
            child: ElevatedButton(
              onPressed: controller.continueAfterSubmissionReward,
              style: AppTheme.primaryButtonStyle(),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}