import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef LinkCompletions = List<String> Function(String query);

final _iterable = RegExp(r'^(\s*)(-+|~+|>+)(\s+)(\([^)]*\)\s+)?(.*)$');
final _openLink = RegExp(r'\{([^{}\n]*)$');

class ListContinuation extends TextInputFormatter {
  const ListContinuation();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.baseOffset;
    final text = newValue.text;
    final insertedNewline =
        newValue.selection.isCollapsed &&
        oldValue.selection.isCollapsed &&
        text.length == oldValue.text.length + 1 &&
        oldValue.selection.baseOffset == cursor - 1 &&
        text[cursor - 1] == '\n';
    if (!insertedNewline) return newValue;
    final lineStart = cursor < 2 ? 0 : text.lastIndexOf('\n', cursor - 2) + 1;
    final match = _iterable.firstMatch(text.substring(lineStart, cursor - 1));
    if (match == null) return newValue;
    if (match[5]!.trim().isEmpty) {
      return TextEditingValue(
        text: text.replaceRange(lineStart, cursor, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }
    final prefix =
        '${match[1]}${match[2]}${match[3]}${match[4] == null ? '' : '( ) '}';
    return TextEditingValue(
      text: text.replaceRange(cursor, cursor, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  }
}

class CompletionBar extends StatelessWidget {
  const CompletionBar({
    super.key,
    required this.controller,
    required this.completions,
  });

  final TextEditingController controller;
  final LinkCompletions completions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final value = controller.value;
      final cursor = value.selection.baseOffset;
      final match = cursor < 0 || !value.selection.isCollapsed
          ? null
          : _openLink.firstMatch(value.text.substring(0, cursor));
      final options = match == null
          ? const <String>[]
          : completions(match[1]!).take(12).toList();
      if (options.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(option),
                  onPressed: () => _insert(match!.start + 1, cursor, option),
                ),
              ),
          ],
        ),
      );
    },
  );

  void _insert(int start, int cursor, String target) {
    final text = controller.text;
    final closed = cursor < text.length && text[cursor] == '}';
    final replacement = closed ? target : '$target}';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, cursor, replacement),
      selection: TextSelection.collapsed(offset: start + target.length + 1),
    );
  }
}

class SourceEditor extends StatefulWidget {
  const SourceEditor({
    super.key,
    required this.source,
    required this.style,
    required this.highlight,
    required this.readOnly,
    required this.onDone,
    this.completions,
  });

  final String source;
  final TextStyle style;
  final TextSpan Function(String text) highlight;
  final bool readOnly;
  final ValueChanged<String> onDone;
  final LinkCompletions? completions;

  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  late final _controller = HighlightingController(
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.completions case final completions?)
          TextFieldTapRegion(
            child: CompletionBar(
              controller: _controller,
              completions: completions,
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          readOnly: widget.readOnly,
          maxLines: null,
          style: widget.style,
          inputFormatters: const [ListContinuation()],
          onTapOutside: (_) => _focus.unfocus(),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ],
    ),
  );
}

class HighlightingController extends TextEditingController {
  HighlightingController(this.highlight, {super.text});

  final TextSpan Function(String text) highlight;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => highlight(text);
}
