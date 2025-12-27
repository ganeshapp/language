import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'audio_handler.dart';

final audioHandlerProvider =
    FutureProvider<LessonAudioHandler>((ref) async => initAudioHandler());

