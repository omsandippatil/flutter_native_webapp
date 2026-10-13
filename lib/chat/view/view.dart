import 'package:flutter/material.dart';

import 'package:tapapp/chat/audio/audio.dart';
import 'package:tapapp/chat/blocks/typing_indicator_block.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';
import 'package:tapapp/core/theme/theme.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.sender, this.size});

  final ChatSender sender;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? AppSpacing.of(context).avatarSize;

    if (sender == ChatSender.user) {
      return Container(
        width: resolvedSize,
        height: resolvedSize,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          Icons.person_rounded,
          size: resolvedSize * 0.53,
          color: AppTheme.buttonColor,
        ),
      );
    }

    return CircleAvatar(
      radius: resolvedSize / 2,
      backgroundColor: AppTheme.classroomMessageSurface,
      child: ClipOval(
        child: Image.asset(
          'assets/images/branding/tap_buddy_pp.png',
          fit: BoxFit.cover,
          width: resolvedSize,
          height: resolvedSize,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.smart_toy_rounded,
            size: resolvedSize * 0.53,
            color: AppTheme.cardBackground,
          ),
        ),
      ),
    );
  }
}

class ChatItemRow extends StatelessWidget {
  const ChatItemRow({super.key, required this.item, required this.ctx});

  final ChatItem item;
  final ChatRenderContext ctx;

  static const Set<ChatItemKind> _fullWidthKinds = {
    ChatItemKind.checkpoint,
    ChatItemKind.submissionReward,
    ChatItemKind.nextActivity,
  };

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final content = buildChatItem(item, ctx);
    final audio = item.audio;
    final audioButton = audio == null
        ? null
        : Padding(
            padding: EdgeInsets.only(top: scale.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ChatAudioPlayerButton(
                audio: audio,
                controller: ctx.audioController,
              ),
            ),
          );

    if (_fullWidthKinds.contains(item.kind)) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [content, ?audioButton],
        ),
      );
    }

    if (item.sender == ChatSender.user) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.72).clamp(
                    0.0,
                    scale.userBubbleMaxWidth,
                  ),
                ),
                child: content,
              ),
            ),
            SizedBox(width: scale.xs),
            ChatAvatar(sender: ChatSender.user, size: scale.avatarSize),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatAvatar(sender: ChatSender.bot, size: scale.avatarSize),
          SizedBox(width: scale.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, ?audioButton],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.items,
    required this.renderContext,
    this.scrollController,
    this.footer,
    this.padding,
  });

  final List<ChatItem> items;
  final ChatRenderContext renderContext;
  final ScrollController? scrollController;
  final Widget? footer;
  final EdgeInsets? padding;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  ScrollController? _ownedController;
  List<ChatItem>? _lastItems;
  bool _hadFooter = false;

  ScrollController get _controller =>
      widget.scrollController ?? (_ownedController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _lastItems = widget.items;
    _hadFooter = widget.footer != null;
  }

  @override
  void didUpdateWidget(covariant ChatListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasFooter = widget.footer != null;
    if (!identical(widget.items, _lastItems) || hasFooter != _hadFooter) {
      _lastItems = widget.items;
      _hadFooter = hasFooter;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    final controller = _controller;
    if (!mounted || !controller.hasClients) return;
    controller.animateTo(
      controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final footer = widget.footer;
    final itemCount = widget.items.length + (footer != null ? 1 : 0);

    return ListView.builder(
      controller: _controller,
      padding:
          widget.padding ??
          EdgeInsets.fromLTRB(scale.md, scale.lg, scale.md, scale.xxl),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= widget.items.length) return footer!;
        final item = widget.items[index];
        if (item.kind == ChatItemKind.loading) {
          return Padding(
            key: ValueKey(item.id),
            padding: EdgeInsets.symmetric(vertical: scale.md),
            child: const Center(child: TypingIndicator()),
          );
        }
        return ChatItemRow(
          key: ValueKey(item.id),
          item: item,
          ctx: widget.renderContext,
        );
      },
    );
  }
}

enum ChatInputMode { none, text }

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.mode,
    this.onSubmitText,
    this.hintText = 'Type a message...',
    this.enabled = true,
  });

  final ChatInputMode mode;
  final ValueChanged<String>? onSubmitText;
  final String hintText;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || !widget.enabled) return;
    widget.onSubmitText?.call(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == ChatInputMode.none) return const SizedBox.shrink();
    final scale = AppSpacing.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scale.pageGutter,
        vertical: scale.sm,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: scale.chatMaxWidth),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    style: AppTheme.text(size: 14, height: 1.45),
                    decoration: InputDecoration(hintText: widget.hintText),
                  ),
                ),
                SizedBox(width: scale.xs),
                SizedBox(
                  width: 44 * scale.factor,
                  height: 44 * scale.factor,
                  child: ElevatedButton(
                    onPressed: widget.enabled ? _submit : null,
                    style: AppTheme.primaryButtonStyle(
                      radius: AppTheme.radiusPill,
                    ).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size.zero),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
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

enum ChatLayoutMode { column, columnWithRail, centeredSingle }

class ChatLayout {
  ChatLayout._();

  static Widget resolve({
    required BuildContext context,
    required ChatLayoutMode mode,
    required Widget chatList,
    Widget? sideRail,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = AppSpacingScale.fromWidth(constraints.maxWidth);

        if (mode == ChatLayoutMode.centeredSingle) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: scale.contentMaxWidth),
              child: chatList,
            ),
          );
        }

        if (!scale.showsSideRail || mode == ChatLayoutMode.column) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: scale.chatMaxWidth),
              child: Container(
                color: AppTheme.classroomBackground,
                child: chatList,
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: scale.contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: scale.pageGutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: scale.sm),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: scale.chatMaxWidth,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.classroomBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXl,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: chatList,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (sideRail != null)
                    SizedBox(
                      width: scale.railWidth + scale.xl,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: scale.xl,
                          top: scale.lg,
                          bottom: scale.lg,
                        ),
                        child: sideRail,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}