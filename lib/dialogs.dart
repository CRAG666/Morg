import 'package:flutter/material.dart';

import 'l10n/l10n.dart';

class PromptDialog extends StatefulWidget {
  const PromptDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirm,
    this.initial = '',
  });

  final String title;
  final String hint;
  final String confirm;
  final String initial;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.confirm),
      ),
    ],
  );
}

Future<bool?> confirm(
  BuildContext context, {
  String? title,
  required String content,
  required String accept,
  String? cancel,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: title == null ? null : Text(title),
    content: Text(content),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(cancel ?? context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(accept),
      ),
    ],
  ),
);

extension Notify on BuildContext {
  void notify(String Function(AppLocalizations l10n) message) =>
      ScaffoldMessenger.of(this)
          .showSnackBar(SnackBar(content: Text(message(l10n))));
}
