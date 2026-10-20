import 'package:flutter/material.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('¿Descartar los cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
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
              tooltip: 'Guardar',
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
