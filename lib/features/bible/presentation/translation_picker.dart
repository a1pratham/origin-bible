import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/bible_providers.dart';
import '../data/translations.dart';

Future<void> showTranslationPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final selected = ref.read(selectedTranslationProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in kTranslations)
              ListTile(
                title: Text(t.name),
                subtitle: Text('${t.abbreviation} · ${t.license}'),
                trailing: t.id == selected ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(selectedTranslationProvider.notifier).state = t.id;
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}
