import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/submission/submission.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

enum _MediaPickChoice { cameraImage, galleryImage, cameraVideo, galleryVideo }

class SubmissionBlock extends StatefulWidget {
  const SubmissionBlock({super.key, required this.item, required this.ctx});

  final SubmissionItem item;
  final ChatRenderContext ctx;

  @override
  State<SubmissionBlock> createState() => _SubmissionBlockState();
}

class _SubmissionBlockState extends State<SubmissionBlock> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  late SubmissionKind _kind;
  late Future<SubmissionContent> _contentFuture;

  String? _selectedEmoji;
  XFile? _pickedMedia;
  Uint8List? _pickedMediaBytes;
  bool _isVideoPick = false;
  bool _isPicking = false;
  bool _submitted = false;
  bool _pickError = false;

  @override
  void initState() {
    super.initState();
    _kind = SubmissionKindResolver.fromWire(widget.item.submissionKind);
    _contentFuture = _fetchContent();
  }

  @override
  void didUpdateWidget(covariant SubmissionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.stepId != widget.item.stepId) {
      _kind = SubmissionKindResolver.fromWire(widget.item.submissionKind);
      _contentFuture = _fetchContent();
    }
    if (oldWidget.item.stepId == widget.item.stepId &&
        !oldWidget.ctx.isAwaitingInput &&
        widget.ctx.isAwaitingInput &&
        _submitted) {
      setState(() => _submitted = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<SubmissionContent> _fetchContent() => SubmissionContentCache.fetch(
        stepId: widget.item.stepId,
        kind: _kind,
        fetcher: widget.ctx.submissionContentFetcher,
      );

  Future<void> _retryContentFetch() async {
    SubmissionContentCache.invalidate(widget.item.stepId, _kind);
    setState(() => _contentFuture = _fetchContent());
  }

  void _send(Map<String, Object?> payload) {
    setState(() => _submitted = true);
    widget.ctx.onSubmissionAnswer(widget.item.stepId, payload);
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
      final file = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Couldn't access that. Please try again.")));
  }

  Future<void> _showMediaSourceSheet({required bool allowVideo, bool forceVideo = false}) async {
    final choice = await showModalBottomSheet<_MediaPickChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!forceVideo) ...[
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(sheetContext, _MediaPickChoice.cameraImage),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose photo from gallery'),
                  onTap: () => Navigator.pop(sheetContext, _MediaPickChoice.galleryImage),
                ),
              ],
              if (allowVideo) ...[
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Record a video'),
                  onTap: () => Navigator.pop(sheetContext, _MediaPickChoice.cameraVideo),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Choose video from gallery'),
                  onTap: () => Navigator.pop(sheetContext, _MediaPickChoice.galleryVideo),
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
    return FutureBuilder<SubmissionContent>(
      future: _contentFuture,
      builder: (context, snapshot) {
        final content = snapshot.data ?? SubmissionContent.empty(_kind);
        final isLoadingContent = snapshot.connectionState == ConnectionState.waiting;
        final hadError = snapshot.hasError;
        return _buildCard(content, isLoadingContent, hadError);
      },
    );
  }

  Widget _buildCard(SubmissionContent content, bool isLoadingContent, bool hadError) {
    final item = widget.item;
    final guidedText = item.guidedText;
    final unguidedText = item.unguidedText;
    final validCriteria = item.validCriteria;
    final canInteract = widget.ctx.isAwaitingInput && !_submitted;
    final prompt = guidedText?.isNotEmpty == true ? guidedText! : unguidedText;
    final kindLabel = content.display.label.isNotEmpty ? content.display.label : _kind.wireValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SubmissionChip(label: kindLabel, foregroundColor: AppTheme.buttonColor),
              if (item.stepTotal > 0) _SubmissionChip(label: 'STEP ${item.stepNumber}/${item.stepTotal}'),
            ],
          ),
          const SizedBox(height: 16),
          _ExamplePreview(
            height: 190,
            hasMedia: _pickedMedia != null,
            isVideo: _isVideoPick,
            mediaBytes: _pickedMediaBytes,
            onTap: canInteract && SubmissionKindResolver.isMedia(_kind)
                ? () => _showMediaSourceSheet(
                      allowVideo: _kind != SubmissionKind.image,
                      forceVideo: _kind == SubmissionKind.video,
                    )
                : () => _showHelpDialog(content, kindLabel),
          ),
          const SizedBox(height: 16),
          Text(prompt, style: AppTheme.text(size: 16, weight: FontWeight.w800, height: 1.35)),
          if (unguidedText.isNotEmpty && guidedText?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              unguidedText,
              style: AppTheme.text(size: 12, height: 1.4, color: AppTheme.subheadingColor),
            ),
          ],
          if (validCriteria?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              validCriteria!,
              style: AppTheme.text(size: 11, height: 1.4, color: AppTheme.subheadingColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          if (hadError)
            _InlineNotice(message: 'Could not load examples.', onRetry: _retryContentFetch)
          else if (isLoadingContent)
            const _ContentLoadingRow()
          else if (content.friendExamples.isNotEmpty) ...[
            Text(content.display.friendLabel, style: AppTheme.text(size: 12, color: AppTheme.subheadingColor)),
            const SizedBox(height: 8),
            _FriendExamplesRow(
              examples: content.friendExamples,
              onTap: canInteract && SubmissionKindResolver.isMedia(_kind)
                  ? () => _showMediaSourceSheet(
                        allowVideo: _kind != SubmissionKind.image,
                        forceVideo: _kind == SubmissionKind.video,
                      )
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          if (_pickError) ...[
            const _InlineNotice(message: "We couldn't load that file. Please try picking it again."),
            const SizedBox(height: 12),
          ],
          _buildInputForKind(content, canInteract),
        ],
      ),
    );
  }

  void _showHelpDialog(SubmissionContent content, String kindLabel) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: _SubmissionChip(label: kindLabel)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.guidedText?.isNotEmpty == true
                      ? widget.item.guidedText!
                      : widget.item.unguidedText,
                  style: AppTheme.text(size: 14, height: 1.45),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
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

  Widget _buildInputForKind(SubmissionContent content, bool canInteract) {
    switch (_kind) {
      case SubmissionKind.emoji:
        return _emojiInput(content, canInteract);
      case SubmissionKind.textAudio:
      case SubmissionKind.audio:
        return _textSubmissionInput(
          canInteract: canInteract,
          hintText: 'Type or transcribe your answer here...',
          onSubmit: () {
            final value = _textController.text.trim();
            if (value.isEmpty) return;
            _send(SubmissionAnswer.audioTranscript(value).toPayload());
          },
        );
      case SubmissionKind.image:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: false,
          onSubmit: () {
            final media = _pickedMedia;
            if (media == null) return;
            _send(SubmissionAnswer.image(media.path).toPayload());
          },
        );
      case SubmissionKind.video:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          forceVideo: true,
          onSubmit: () {
            final media = _pickedMedia;
            if (media == null) return;
            _send(SubmissionAnswer.video(media.path).toPayload());
          },
        );
      case SubmissionKind.imageVideo:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          onSubmit: () {
            final media = _pickedMedia;
            if (media == null) return;
            _send(SubmissionAnswer.imageOrVideo(media.path, isVideo: _isVideoPick).toPayload());
          },
        );
      case SubmissionKind.text:
        return _textSubmissionInput(
          canInteract: canInteract,
          hintText: 'Type your answer here...',
          onSubmit: () {
            final value = _textController.text.trim();
            if (value.isEmpty) return;
            _send(SubmissionAnswer.text(value).toPayload());
          },
        );
    }
  }

  Widget _emojiInput(SubmissionContent content, bool canInteract) {
    final emojis = content.display.emojiChoices;
    if (emojis.isEmpty) {
      return _textSubmissionInput(
        canInteract: canInteract,
        hintText: 'Send an emoji...',
        onSubmit: () {
          final value = _textController.text.trim();
          if (value.isEmpty) return;
          _send(SubmissionAnswer.emoji(value).toPayload());
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: emojis.map((emoji) {
            final selected = _selectedEmoji == emoji;
            return InkWell(
              onTap: canInteract ? () => setState(() => _selectedEmoji = emoji) : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.mutedLavender : AppTheme.classroomMessageSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: selected ? AppTheme.buttonColor : Colors.transparent),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _submitRow(
          onPressed: (canInteract && _selectedEmoji != null)
              ? () => _send(SubmissionAnswer.emoji(_selectedEmoji!).toPayload())
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
        const SizedBox(height: 16),
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
    final hasMedia = _pickedMedia != null;
    void openPicker() => _showMediaSourceSheet(allowVideo: allowVideo, forceVideo: forceVideo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMedia) ...[
          InkWell(
            onTap: canInteract ? openPicker : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _isVideoPick ? Icons.videocam_outlined : Icons.image_outlined,
                    color: AppTheme.buttonColor,
                  ),
                  const SizedBox(width: 8),
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
          const SizedBox(height: 12),
        ],
        _submitRow(
          primaryLabel: hasMedia ? 'Share submission' : 'Submit',
          isLoading: _isPicking,
          onPressed: !canInteract || _isPicking ? null : (hasMedia ? onSubmit : openPicker),
        ),
      ],
    );
  }

  Widget _submitRow({required VoidCallback? onPressed, String primaryLabel = 'Submit', bool isLoading = false}) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onPressed,
              style: AppTheme.primaryButtonStyle(disabledColor: AppTheme.dividerColor),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_submitted ? 'Sent' : primaryLabel),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () => _contentFuture.then((content) {
              if (!mounted) return;
              _showHelpDialog(
                content,
                content.display.label.isNotEmpty ? content.display.label : _kind.wireValue,
              );
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.subheadingColor,
              side: const BorderSide(color: AppTheme.dividerColor),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Submission Help'),
          ),
        ),
      ],
    );
  }
}

class _SubmissionChip extends StatelessWidget {
  const _SubmissionChip({required this.label, this.foregroundColor = AppTheme.textColor});

  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Text(label, style: AppTheme.text(size: 11, weight: FontWeight.w800, color: foregroundColor)),
    );
  }
}

class _ContentLoadingRow extends StatelessWidget {
  const _ContentLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Loading examples...', style: AppTheme.text(size: 12, color: AppTheme.subheadingColor)),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.dangerText),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTheme.text(size: 13, color: AppTheme.dangerText))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
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
                      child: Icon(Icons.play_circle_fill_rounded, size: 54, color: AppTheme.buttonColor),
                    )
                  : mediaBytes != null
                      ? Image.memory(mediaBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.image_outlined, size: 34, color: AppTheme.imagePlaceholder),
        ),
      ),
    );
  }
}

class _FriendExamplesRow extends StatelessWidget {
  const _FriendExamplesRow({required this.examples, required this.onTap});

  final List<SubmissionFriendExample> examples;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: examples.map((example) {
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
            child: Text(example.preview, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }
} 



