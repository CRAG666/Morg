import 'package:flutter/material.dart';

class SourceEditor extends StatefulWidget {
  const SourceEditor({
    super.key,
    required this.source,
    required this.style,
    required this.highlight,
    required this.readOnly,
    required this.onDone,
  });

  final String source;
  final TextStyle style;
  final TextSpan Function(String text) highlight;
  final bool readOnly;
  final ValueChanged<String> onDone;

  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  late final _controller = _HighlightingController(
    widget.highlight,
    text: widget.source,
  );
  final _focus = FocusNode();
  var _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone(_controller.text);
  }

  @override
  void dispose() {
    _finish();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
    ),
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      readOnly: widget.readOnly,
      maxLines: null,
      style: widget.style,
      onTapOutside: (_) => _focus.unfocus(),
      decoration: const InputDecoration.collapsed(hintText: ''),
    ),
  );
}

class _HighlightingController extends TextEditingController {
  _HighlightingController(this.highlight, {super.text});

  final TextSpan Function(String text) highlight;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => highlight(text);
}
