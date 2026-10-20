import 'package:flutter/material.dart';

import 'l10n/l10n.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.title,
    required this.source,
    required this.onSave,
  });

  final String title;
  final String source;
  final Future<void> Function(String source) onSave;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final _controller = TextEditingController(text: widget.source);
  late String _saved = widget.source;
  var _saving = false;

  bool get _dirty => _controller.text != _saved;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final source = _controller.text;
    try {
      await widget.onSave(source);
      setState(() => _saved = source);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.saveFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unsavedChangesTitle),
        content: Text(context.l10n.discardChangesQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.discard),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_dirty ? '${widget.title} •' : widget.title),
          actions: [
            IconButton(
              tooltip: context.l10n.save,
              onPressed: _dirty && !_saving ? _save : null,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: TextField(
          controller: _controller,
          expands: true,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ),
    ),
  );
}
