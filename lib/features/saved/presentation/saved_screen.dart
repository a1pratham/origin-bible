import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Saved',
      note: 'Bookmarks, highlights and notes arrive in Phase 4.',
    );
  }
}
