import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/structure.dart';
import 'todo_menu.dart';

sealed class ElementChoice {
  const ElementChoice();
}

class ToggleFocus extends ElementChoice {
  const ToggleFocus();
}

class EditElement extends ElementChoice {
  const EditElement(this.edit, {this.notice});

  final SourceEdit edit;
  final String? notice;
}

Future<ElementChoice?> pickElementChoice(
  BuildContext context, {
  required String source,
  required List<Block> blocks,
  required int line,
  required bool focused,
  required bool editable,
}) {
  final l10n = context.l10n;
  final heading = headingAt(blocks, line);
  final item = heading == null ? listItemAt(blocks, line) : null;
  final edits = !editable
      ? const <(IconData, String, SourceEdit)>[]
      : <(IconData, String, SourceEdit)>[
          (
            Icons.format_indent_decrease,
            l10n.promote,
            (text) => changeLevel(text, blocks, line, -1) ?? text,
          ),
          (
            Icons.format_indent_increase,
            l10n.demote,
            (text) => changeLevel(text, blocks, line, 1) ?? text,
          ),
          (
            Icons.arrow_upward,
            l10n.moveUp,
            (text) => move(text, blocks, line, -1) ?? text,
          ),
          (
            Icons.arrow_downward,
            l10n.moveDown,
            (text) => move(text, blocks, line, 1) ?? text,
          ),
          if (item != null)
            (
              Icons.swap_vert,
              item.kind == NestableKind.ordered
                  ? l10n.toUnordered
                  : l10n.toOrdered,
              (text) => toggleListKind(text, blocks, line) ?? text,
            ),
          if ((heading?.status ?? item?.status) == null)
            (
              Icons.check_box_outline_blank,
              l10n.makeTask,
              (text) => setTodo(text, blocks, line, TodoStatus.undone),
            ),
        ];
  return showModalBottomSheet<ElementChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (heading != null)
              ListTile(
                leading: Icon(
                  focused ? Icons.center_focus_weak : Icons.center_focus_strong,
                ),
                title: Text(focused ? l10n.unfocus : l10n.focus),
                onTap: () => Navigator.pop(context, const ToggleFocus()),
              ),
            for (final (icon, label, edit) in edits)
              if (edit(source) != source)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  onTap: () => Navigator.pop(context, EditElement(edit)),
                ),
            if (editable)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.delete),
                onTap: () => Navigator.pop(
                  context,
                  EditElement(
                    (text) => deleteElement(text, blocks, line) ?? text,
                    notice: l10n.deleted,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
