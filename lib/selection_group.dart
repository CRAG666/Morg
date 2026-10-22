import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

class _MappedSelectionDelegate extends StaticSelectionContainerDelegate {
  _MappedSelectionDelegate(this.copied);

  String Function(String text) copied;

  @override
  SelectedContent? getSelectedContent() => switch (super.getSelectedContent()) {
    final content? => SelectedContent(plainText: copied(content.plainText)),
    null => null,
  };
}

class SelectionGroup extends StatefulWidget {
  const SelectionGroup({
    super.key,
    required this.copied,
    required this.child,
    this.enabled = true,
  });

  final String Function(String text) copied;
  final Widget child;
  final bool enabled;

  @override
  State<SelectionGroup> createState() => _SelectionGroupState();
}

class _SelectionGroupState extends State<SelectionGroup> {
  late final _delegate = _MappedSelectionDelegate(widget.copied);

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _delegate.copied = widget.copied;
    return widget.enabled
        ? SelectionContainer(
            registrar: SelectionContainer.maybeOf(context),
            delegate: _delegate,
            child: widget.child,
          )
        : SelectionContainer.disabled(child: widget.child);
  }
}
