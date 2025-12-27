import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../library/data/lesson_repository.dart';
import '../../../core/data/models/lesson_progress.dart';
import '../../../core/utils/time_format.dart';
import '../data/audio_handler_provider.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/data/streak_repository.dart';

class PlayerScreen extends HookConsumerWidget {
  const PlayerScreen({
    super.key,
    required this.lessonId,
  });

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(lessonRepositoryProvider);
    final settingsAsync = ref.watch(settingsProvider);

    final lessonFuture = useMemoized(
      () async {
        await repository.initializeLessons();
        return repository.getOrCreateLesson(lessonId);
      },
      [repository, lessonId],
    );
    final lessonSnapshot = useFuture(lessonFuture);

    final handlerAsync = ref.watch(audioHandlerProvider);

    final lessonError = lessonSnapshot.hasError ? lessonSnapshot.error : null;
    final handlerError = handlerAsync.hasError ? handlerAsync.error : null;

    final lesson = lessonSnapshot.data;
    final handler = handlerAsync.value;
    final player = handler?.player;
    final currentLesson = useState<LessonProgress?>(lesson);
    final sessionStartPosition = useState<int?>(null);

    Future<void> persistNow() async {
      if (lesson != null && player != null) {
        await _persistProgress(
          repository,
          currentLesson.value ?? lesson,
          player,
          ref.read(streakRepositoryProvider),
          sessionStartPosition.value,
        );
      }
    }

    useEffect(() {
      if (lesson != null && player != null) {
        Future.microtask(() async {
          try {
            await player.setAudioSource(AudioSource.asset(lesson.filePath));
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lesson file not found')),
              );
            }
            return;
          }
          if (lesson.lastPositionSeconds > 0) {
            await player.seek(Duration(seconds: lesson.lastPositionSeconds));
          }
          await repository.setLastOpenedLessonId(lesson.id);
          sessionStartPosition.value ??= lesson.lastPositionSeconds;
        });
      }

      return () async {
        await persistNow();
        await player?.pause();
      };
    }, [lesson, player, repository, handler]);

    final appLifecycle = useAppLifecycleState();
    useEffect(() {
      if (appLifecycle == AppLifecycleState.paused ||
          appLifecycle == AppLifecycleState.inactive) {
        if (lesson != null && player != null) {
          _persistProgress(
            repository,
            currentLesson.value ?? lesson,
            player,
            ref.read(streakRepositoryProvider),
            sessionStartPosition.value,
          );
        }
      }
      return null;
    }, [appLifecycle, lesson, player, repository, currentLesson]);

    final loading = lessonSnapshot.connectionState != ConnectionState.done ||
        handlerAsync.isLoading;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (lessonError != null || handlerError != null) {
      return Scaffold(
        body: Center(
          child: Text('Error loading lesson'),
        ),
      );
    }

    if (lesson == null || player == null || handler == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final duration = useStream(player.durationStream).data ?? Duration.zero;
    final position = useStream(player.positionStream, initialData: Duration.zero).data!;
    final playerState = useStream(player.playerStateStream).data ?? player.playerState;
    final processing = playerState.processingState;
    final playing = playerState.playing;

    final sliderMax = max<double>(duration.inMilliseconds.toDouble(), 1);
    final sliderValue = min<double>(position.inMilliseconds.toDouble(), sliderMax);
    final hapticsEnabled =
        settingsAsync.maybeWhen(data: (s) => s.hapticsEnabled, orElse: () => true);

    return WillPopScope(
          onWillPop: () async {
        await persistNow();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(lesson.title),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Slider(
              value: sliderValue,
              max: sliderMax,
              onChanged: (v) {
                player.seek(Duration(milliseconds: v.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDurationMmSs(position)),
                Text(formatDurationMmSs(duration)),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 48,
                  onPressed: () {
                    if (hapticsEnabled) HapticFeedback.lightImpact();
                    _seekRelative(player, -10);
                  },
                  icon: const Icon(Icons.replay_10),
                ),
                IconButton(
                  iconSize: 64,
                  onPressed: processing == ProcessingState.loading ||
                          processing == ProcessingState.buffering
                      ? null
                      : () async {
                          if (hapticsEnabled) HapticFeedback.lightImpact();
                          if (playing) {
                            await handler.pause();
                          await _persistProgress(
                            repository,
                            currentLesson.value ?? lesson,
                            player,
                            ref.read(streakRepositoryProvider),
                            sessionStartPosition.value,
                          );
                          } else {
                            await handler.play();
                          }
                        },
                  icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                ),
                IconButton(
                  iconSize: 48,
                  onPressed: () {
                    if (hapticsEnabled) HapticFeedback.lightImpact();
                    _seekRelative(player, 10);
                  },
                  icon: const Icon(Icons.forward_10),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    if (hapticsEnabled) HapticFeedback.lightImpact();
                    final seconds = player.position.inSeconds;
                    final updated = (currentLesson.value ?? lesson).copyWith(
                      bookmarks: [
                        ...(currentLesson.value?.bookmarks ?? lesson.bookmarks),
                        seconds,
                      ],
                    );
                    currentLesson.value = updated;
                    await repository.saveLesson(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Bookmark saved at ${formatDurationMmSs(Duration(seconds: seconds))}',
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => _BookmarksSheet(
                        lesson: currentLesson.value ?? lesson,
                        onJump: (seconds) {
                          player.seek(Duration(seconds: seconds));
                        },
                        onDelete: (seconds) async {
                          final existing = currentLesson.value ?? lesson;
                          final updated = existing.copyWith(
                            bookmarks: List<int>.from(existing.bookmarks)
                              ..remove(seconds),
                          );
                          currentLesson.value = updated;
                          await repository.saveLesson(updated);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Bookmark'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => _BookmarksSheet(
                        lesson: currentLesson.value ?? lesson,
                        onJump: (seconds) {
                          player.seek(Duration(seconds: seconds));
                        },
                        onDelete: (seconds) async {
                          final existing = currentLesson.value ?? lesson;
                          final updated = existing.copyWith(
                            bookmarks: List<int>.from(existing.bookmarks)
                              ..remove(seconds),
                          );
                          currentLesson.value = updated;
                          await repository.saveLesson(updated);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Bookmarks'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InlineBookmarks(
              lesson: currentLesson.value ?? lesson,
              onJump: (seconds) => player.seek(Duration(seconds: seconds)),
              onDelete: (seconds) async {
                final existing = currentLesson.value ?? lesson;
                final updated = existing.copyWith(
                  bookmarks: List<int>.from(existing.bookmarks)..remove(seconds),
                );
                currentLesson.value = updated;
                await repository.saveLesson(updated);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

Future<void> _persistProgress(
  LessonRepository repository,
  LessonProgress lesson,
  AudioPlayer player,
  StreakRepository streakRepository,
  int? sessionStartSeconds,
) async {
  final positionSeconds = player.position.inSeconds;
  final durationSeconds =
      player.duration?.inSeconds ?? lesson.durationSeconds;
  final reachedCompletion = durationSeconds > 0 &&
      positionSeconds >= (durationSeconds * 0.95).floor();
  final isCompleted = lesson.isCompleted || reachedCompletion;

  if (sessionStartSeconds != null && positionSeconds > sessionStartSeconds) {
    final delta = positionSeconds - sessionStartSeconds;
    await streakRepository.addListeningSeconds(delta);
  }

  await repository.saveLesson(
    lesson.copyWith(
      lastPositionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      isCompleted: isCompleted,
    ),
  );

  // Update session start to avoid double-counting on subsequent saves.
  sessionStartSeconds = positionSeconds;
}

void _seekRelative(AudioPlayer player, int offsetSeconds) {
  final current = player.position;
  final targetSeconds = max(0, current.inSeconds + offsetSeconds);
  player.seek(Duration(seconds: targetSeconds));
}

class _BookmarksSheet extends StatelessWidget {
  const _BookmarksSheet({
    required this.lesson,
    required this.onJump,
    required this.onDelete,
  });

  final LessonProgress lesson;
  final ValueChanged<int> onJump;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final bookmarks = lesson.bookmarks.toList()..sort();
    if (bookmarks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No bookmarks yet.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final seconds = bookmarks[index];
        final label = formatDurationMmSs(Duration(seconds: seconds));
        return ListTile(
          title: Text(label),
          onTap: () => onJump(seconds),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => onDelete(seconds),
          ),
        );
      },
    );
  }
}

class _InlineBookmarks extends StatelessWidget {
  const _InlineBookmarks({
    required this.lesson,
    required this.onJump,
    required this.onDelete,
  });

  final LessonProgress lesson;
  final ValueChanged<int> onJump;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final bookmarks = lesson.bookmarks.toList()..sort();
    if (bookmarks.isEmpty) {
      return const Text('No bookmarks yet');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Bookmarks',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...bookmarks.map(
          (seconds) => Dismissible(
            key: ValueKey('bm-$seconds'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onDelete(seconds),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.red.withOpacity(0.1),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            child: ListTile(
              dense: true,
              title: Text(formatDurationMmSs(Duration(seconds: seconds))),
              onTap: () => onJump(seconds),
            ),
          ),
        ),
      ],
    );
  }
}

