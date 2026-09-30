import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // No network call at startup: the app must open instantly and offline.
  runApp(const ProviderScope(child: OriginBibleApp()));
}
