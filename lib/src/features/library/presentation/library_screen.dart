import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../library/data/lesson_repository.dart';
import '../../../core/data/models/lesson_progress.dart';
import '../../../core/utils/time_format.dart';
import '../../player/presentation/player_screen.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/data/streak_repository.dart';

final lessonsProvider = FutureProvider<List<LessonProgress>>((ref) async {
  final repo = ref.read(lessonRepositoryProvider);
  await repo.initializeLessons();
  final lessons = await repo.getAllLessons();
  return lessons;
});

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final streakAsync = ref.watch(streakProvider);

    useEffect(() {
      Future.microtask(() async {
        final settingsValue = await settingsAsync.maybeWhen(
          data: (s) => Future.value(s),
          orElse: () => null,
        );
        if (settingsValue != null && settingsValue.resumeLastLesson) {
          final repo = ref.read(lessonRepositoryProvider);
          final lastId = await repo.getLastOpenedLessonId();
          if (lastId != null && context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerScreen(lessonId: lastId),
              ),
            );
            if (context.mounted) {
              ref.invalidate(lessonsProvider);
            }
          }
        }
      });
      return null;
    }, [settingsAsync, ref]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => const _SettingsSheet(),
              );
            },
          ),
        ],
      ),
      body: lessonsAsync.when(
        data: (lessons) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _HeaderStats(streakAsync: streakAsync);
            }
            final lesson = lessons[index - 1];
            return _LessonCard(lesson: lesson);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading lessons: $e')),
      ),
    );
  }
}

class _HeaderStats extends ConsumerWidget {
  const _HeaderStats({required this.streakAsync});

  final AsyncValue streakAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: streakAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Streak unavailable: $e'),
          data: (stats) {
            final s = stats as dynamic;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today: ${_formatMinutes((s.todaySeconds as int))}  •  Streak: ${s.current} day${s.current == 1 ? '' : 's'}  •  Best: ${s.best}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatMinutes(int seconds) {
  final mins = (seconds / 60).round();
  return '$mins min';
}

class _LessonCard extends ConsumerWidget {
  const _LessonCard({required this.lesson});

  final LessonProgress lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = lesson.durationSeconds == 0
        ? 0.0
        : lesson.lastPositionSeconds / lesson.durationSeconds;
    final statusIcon = lesson.isCompleted
        ? const Icon(Icons.check_circle, color: Colors.green)
        : progress > 0
            ? const Icon(Icons.play_circle, color: Colors.orange)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerScreen(lessonId: lesson.id),
            ),
          );
          // Refresh lesson list after returning from the player so progress is shown immediately.
          // ignore: use_build_context_synchronously
          if (context.mounted) {
            final container = ProviderScope.containerOf(context, listen: false);
            container.invalidate(lessonsProvider);
            container.invalidate(streakProvider);
          }
        },
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Reset progress?'),
              content: const Text('This will clear progress and bookmarks.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          final repo = ref.read(lessonRepositoryProvider);
          await repo.resetLesson(lesson.id);
          if (context.mounted) {
            ref.invalidate(lessonsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Progress reset')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  lesson.id.split('_').last.padLeft(2, '0'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _progressLabel(lesson),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              statusIcon,
            ],
          ),
        ),
      ),
    );
  }

  String _progressLabel(LessonProgress lesson) {
    if (lesson.isCompleted) return 'Completed';
    if (lesson.lastPositionSeconds == 0) return 'Not started';

    final pos = formatDurationMmSs(Duration(seconds: lesson.lastPositionSeconds));
    final dur = lesson.durationSeconds > 0
        ? formatDurationMmSs(Duration(seconds: lesson.durationSeconds))
        : '--:--';
    return '$pos / $dur';
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    return settingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error loading settings: $e'),
      ),
      data: (settings) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Haptics on controls'),
              value: settings.hapticsEnabled,
              onChanged: (v) async {
                final repo = ref.read(settingsRepositoryProvider);
                final updated = settings.copyWith(hapticsEnabled: v);
                await repo.save(updated);
                ref.invalidate(settingsProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Resume last lesson on launch'),
              subtitle: const Text('When on, opens the last played lesson'),
              value: settings.resumeLastLesson,
              onChanged: (v) async {
                final repo = ref.read(settingsRepositoryProvider);
                final updated = settings.copyWith(resumeLastLesson: v);
                await repo.save(updated);
                ref.invalidate(settingsProvider);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Settings apply immediately.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

