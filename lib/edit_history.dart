import 'dart:collection';

class EditHistory {
  EditHistory({this.limit = 100});

  final int limit;
  final _undo = ListQueue<String>();
  final _redo = <String>[];

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  void record(String previous) {
    _undo.addLast(previous);
    if (_undo.length > limit) _undo.removeFirst();
    _redo.clear();
  }

  String? undo(String current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    return _undo.removeLast();
  }

  String? redo(String current) {
    if (_redo.isEmpty) return null;
    _undo.addLast(current);
    return _redo.removeLast();
  }
}
