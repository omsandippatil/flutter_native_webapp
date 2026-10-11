import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class FormBlock extends StatefulWidget {
  const FormBlock({super.key, required this.item, required this.ctx});

  final FormItem item;
  final ChatRenderContext ctx;

  @override
  State<FormBlock> createState() => _FormBlockState();
}

class _FormBlockState extends State<FormBlock> {
  final Map<String, TextEditingController> _controllers = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.item.fields) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_submitted || !widget.ctx.isAwaitingInput) return;
    final values = <String, Object?>{
      for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
    };
    setState(() => _submitted = true);
    widget.ctx.onSubmissionAnswer(widget.item.stepId, values);
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = widget.ctx.isAwaitingInput && !_submitted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in widget.item.fields) ...[
            Text(field.label, style: AppTheme.text(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            TextField(
              controller: _controllers[field.key],
              enabled: canInteract,
              style: AppTheme.text(size: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canInteract ? _submit : null,
              style: AppTheme.primaryButtonStyle(),
              child: Text(_submitted ? 'Sent' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
} 