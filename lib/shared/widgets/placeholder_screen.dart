import 'package:flutter/material.dart';

/// Temporary body for tabs that are built in later phases.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.note,
    super.key,
  });

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(note, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
