import 'package:flutter/material.dart';

import 'document_style.dart';
import 'l10n/l10n.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'raw_highlight.dart';
import 'settings.dart';

typedef SourceEdit = String Function(String source);

enum _DueAction { set, clear }

const _todoMenu = [
  [TodoStatus.undone, TodoStatus.done, TodoStatus.needsInput],
  [TodoStatus.urgent, TodoStatus.recurring],
  [TodoStatus.pending, TodoStatus.onHold, TodoStatus.cancelled],
];

String todoLabel(AppLocalizations l10n, TodoStatus status) => switch (status) {
  TodoStatus.undone => l10n.todoUndone,
  TodoStatus.done => l10n.todoDone,
  TodoStatus.needsInput => l10n.todoNeedsInput,
  TodoStatus.urgent => l10n.todoUrgent,
  TodoStatus.recurring => l10n.todoRecurring,
  TodoStatus.pending => l10n.todoPending,
  TodoStatus.onHold => l10n.todoOnHold,
  TodoStatus.cancelled => l10n.todoCancelled,
};

TextStyle todoStyle(BuildContext context, TodoStatus? status) =>
    DocumentStyle.of(context)
        .group('@neorg.todo_items.${todoGroups[status ?? TodoStatus.undone]}');

String todoIcon(BuildContext context, TodoStatus status) =>
    '(${MorgSettingsScope.of(context).concealer.todoIcons[status]})';

Future<SourceEdit?> pickTaskEdit(
  BuildContext context, {
  required Offset position,
  required List<Block> blocks,
  required int line,
  required TodoStatus status,
  required DateTime? due,
}) async {
  final l10n = context.l10n;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final iconWidth = textWidth('MMMMM', todoStyle(context, status));
  PopupMenuItem<Object> item(TodoStatus option) => PopupMenuItem(
    value: option,
    child: Row(
      children: [
        SizedBox(
          width: iconWidth,
          child: Text(
            todoIcon(context, option),
            style: todoStyle(context, option),
          ),
        ),
        Text(todoLabel(l10n, option)),
      ],
    ),
  );
  final chosen = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      position & Size.zero,
      Offset.zero & overlay.size,
    ),
    initialValue: status,
    items: [
      for (final group in _todoMenu) ...[
        if (group != _todoMenu.first) const PopupMenuDivider(),
        for (final option in group) item(option),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: _DueAction.set,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l10n.dueDate),
          subtitle: due == null
              ? null
              : Text(MaterialLocalizations.of(context).formatMediumDate(due)),
        ),
      ),
      if (due != null)
        PopupMenuItem(
          value: _DueAction.clear,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: Text(l10n.removeDueDate),
          ),
        ),
    ],
  );
  if (!context.mounted) return null;
  switch (chosen) {
    case final TodoStatus option when option != status:
      return (source) => setTodo(source, blocks, line, option);
    case _DueAction.set:
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: due ?? now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (date == null) return null;
      return (source) => setTaskDate(source, line, '<', date);
    case _DueAction.clear:
      return (source) => setTaskDate(source, line, '<', null);
  }
  return null;
}
