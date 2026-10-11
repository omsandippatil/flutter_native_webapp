import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class ChoiceBlock extends StatefulWidget {
  const ChoiceBlock({super.key, required this.item, required this.ctx});

  final ChoiceItem item;
  final ChatRenderContext ctx;

  @override
  State<ChoiceBlock> createState() => _ChoiceBlockState();
}

class _ChoiceBlockState extends State<ChoiceBlock> {
  String? _selectedKey;
  bool _confirmed = false;

  String? get _confirmLabel => widget.item.meta['confirmLabel'] as String?;

  void _select(String key) {
    if (!widget.ctx.isAwaitingInput || _confirmed) return;
    final confirmLabel = _confirmLabel;
    if (confirmLabel != null) {
      setState(() => _selectedKey = key);
      return;
    }
    if (_selectedKey != null) return;
    setState(() => _selectedKey = key);
    widget.ctx.onOptionSelected(widget.item.stepId, key);
  }

  void _confirm() {
    final key = _selectedKey;
    if (key == null || !widget.ctx.isAwaitingInput || _confirmed) return;
    setState(() => _confirmed = true);
    widget.ctx.onOptionSelected(widget.item.stepId, key);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final confirmLabel = _confirmLabel;
    final enabled = widget.ctx.isAwaitingInput &&
        !_confirmed &&
        (confirmLabel != null || _selectedKey == null);

    if (item.layout == 'buttons' || item.layout == 'radio') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in item.options) ...[
            _OptionButton(
              label: option.label,
              selected: _selectedKey == option.key,
              enabled: enabled,
              onTap: () => _select(option.key),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in item.options)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width * 0.4).clamp(120, 220),
                child: _OptionCard(
                  label: option.label,
                  imagePath: option.imagePath,
                  selected: _selectedKey == option.key,
                  enabled: enabled,
                  onTap: () => _select(option.key),
                ),
              ),
          ],
        ),
        if (confirmLabel != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed:
                  (_selectedKey != null && widget.ctx.isAwaitingInput && !_confirmed)
                      ? _confirm
                      : null,
              style: AppTheme.primaryButtonStyle(),
              child: Text(confirmLabel),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: selected ? AppTheme.primaryButtonStyle() : AppTheme.secondaryButtonStyle(),
        child: Text(label),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.imagePath,
  });

  final String label;
  final String? imagePath;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.mutedLavender : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: selected ? AppTheme.buttonColor : AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Image.asset(
                  imagePath!,
                  height: 72,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 72,
                    color: AppTheme.classroomMessageSurface,
                    child: const Icon(Icons.image_rounded, color: AppTheme.imagePlaceholder),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(label, textAlign: TextAlign.center, style: AppTheme.text(size: 14, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
} 