import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/library/presentation/library_screen.dart';

class LanguageApp extends ConsumerWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Korean',
      theme: appTheme,
      home: const LibraryScreen(),
    );
  }
}

