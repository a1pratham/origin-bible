import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/annotation_models.dart';
import '../application/annotations_provider.dart';
import 'verse_labels.dart';

Future<void> showNoteEditor(BuildContext context, VerseRef verse) {
  return showDialog<void>(
    context: context,
    builder: (_) => NoteEditorDialog(verse: verse),
  );
}

class NoteEditorDialog extends ConsumerStatefulWidget {
  const NoteEditorDialog({required this.verse, super.key});

  final VerseRef verse;

  @override
  ConsumerState<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends ConsumerState<NoteEditorDialog> {
  late final TextEditingController _controller;
  late final bool _hasExisting;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(annotationsProvider).notes[widget.verse];
    _hasExisting = existing != null;
    _controller = TextEditingController(text: existing?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(annotationsProvider.notifier).setNote(
          widget.verse,
          _controller.text,
        );
    Navigator.of(context).pop();
  }

  void _delete() {
    ref.read(annotationsProvider.notifier).setNote(widget.verse, null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Note: ${verseTitle(widget.verse)}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(kMaxNoteLength)],
        decoration: const InputDecoration(hintText: 'Write your note'),
      ),
      actions: [
        if (_hasExisting)
          TextButton(onPressed: _delete, child: const Text('Delete')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
