import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/flashcard.dart';
import '../data/flashcard_repository.dart';

enum FlashcardFront { english, korean }

class FlashcardScreen extends HookConsumerWidget {
  const FlashcardScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
  });

  final String lessonId;
  final String lessonTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitKey = _unitFromLessonId(lessonId);
    final cardsAsync = ref.watch(flashcardsForUnitProvider(unitKey));
    final bookmarksAsync = ref.watch(flashcardBookmarksProvider(unitKey));

    final front = useState(FlashcardFront.english);
    final bookmarkedOnly = useState(false);
    final isFlipped = useState(false);
    final currentIndex = useState(0);
    final pageController = useMemoized(
      () => PageController(initialPage: currentIndex.value, keepPage: true),
      [unitKey],
    );

    final player = useMemoized(() => AudioPlayer());
    useEffect(() {
      return () => player.dispose();
    }, [player]);

    // Local, optimistic bookmarks to avoid rebuild flicker on toggle.
    final localBookmarks = useState<Set<int>?>(null);

    Future<void> playClip(Flashcard card) async {
      try {
        await player.setAudioSource(
          AudioSource.asset('assets/clip/${card.audioPath}'),
        );
        await player.seek(Duration.zero);
        await player.play();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clip not found')),
          );
        }
      }
    }

    final cards = cardsAsync.value ?? <Flashcard>[];
    final bookmarks = localBookmarks.value ?? (bookmarksAsync.value ?? <int>{});

    // Initialize local bookmarks once data is available.
    useEffect(() {
      if (localBookmarks.value == null && bookmarksAsync.hasValue) {
        localBookmarks.value = Set<int>.from(bookmarksAsync.value ?? <int>{});
      }
      return null;
    }, [bookmarksAsync]);

    Future<bool> toggleBookmark(Flashcard card) async {
      final repo = ref.read(flashcardRepositoryProvider);
      final current = localBookmarks.value ?? bookmarks;
      final next = Set<int>.from(current);
      final added = !next.contains(card.id);
      if (added) {
        next.add(card.id);
      } else {
        next.remove(card.id);
      }
      localBookmarks.value = next;
      await repo.toggleBookmark(unitKey, card.id);
      return added;
    }

    final loading = cardsAsync.isLoading || bookmarksAsync.isLoading;

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Flashcards • ${lessonTitle}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (cardsAsync.hasError || bookmarksAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text('Flashcards • ${lessonTitle}')),
        body: Center(
          child: Text(
            'Unable to load flashcards: ${cardsAsync.error ?? bookmarksAsync.error}',
          ),
        ),
      );
    }
    final visibleCards = bookmarkedOnly.value
        ? cards.where((c) => bookmarks.contains(c.id)).toList()
        : cards;

    if (visibleCards.isEmpty) {
      final message = bookmarkedOnly.value
          ? 'No bookmarked cards yet.'
          : 'No flashcards found for this unit.';
      return Scaffold(
        appBar: AppBar(title: Text('Flashcards • ${lessonTitle}')),
        body: Center(child: Text(message)),
      );
    }

    final total = visibleCards.length;
    final clampedIndex = min(currentIndex.value, total - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards • ${lessonTitle}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('English front'),
                  selected: front.value == FlashcardFront.english,
                  onSelected: (selected) {
                    if (selected) {
                      front.value = FlashcardFront.english;
                      isFlipped.value = false;
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Korean front'),
                  selected: front.value == FlashcardFront.korean,
                  onSelected: (selected) {
                    if (selected) {
                      front.value = FlashcardFront.korean;
                      isFlipped.value = false;
                    }
                  },
                ),
                FilterChip(
                  label: const Text('Bookmarked only'),
                  selected: bookmarkedOnly.value,
                  onSelected: (selected) {
                    bookmarkedOnly.value = selected;
                    currentIndex.value = 0;
                    isFlipped.value = false;
                    if (pageController.hasClients) {
                      pageController.jumpToPage(0);
                    }
                  },
                ),
                Chip(
                  label: Text('Card ${clampedIndex + 1} / $total'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: total,
                onPageChanged: (index) {
                  currentIndex.value = index;
                  isFlipped.value = false;
                  player.stop();
                },
                itemBuilder: (context, index) {
                  final card = visibleCards[index];
                  final showKoreanSide = _showKoreanSide(front.value, isFlipped.value);
                  final primaryText =
                      showKoreanSide ? card.koreanPhrase : card.englishPhrase;
                  final secondaryText =
                      showKoreanSide ? card.englishPhrase : card.koreanPhrase;
                  final isBookmarked = bookmarks.contains(card.id);

                  return GestureDetector(
                    onTap: () => isFlipped.value = !isFlipped.value,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  showKoreanSide ? 'Korean' : 'English',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                IconButton(
                                  icon: Icon(
                                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                  ),
                                  onPressed: () async {
                                    final idx = currentIndex.value;
                                    final added = await toggleBookmark(card);
                                    if (bookmarkedOnly.value && !added) {
                                      final nextIndex = max(0, min(idx, total - 2));
                                      currentIndex.value = nextIndex;
                                      if (pageController.hasClients) {
                                        pageController.jumpToPage(nextIndex);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Spacer(),
                            Center(
                              child: Text(
                                primaryText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            if (showKoreanSide)
                              FilledButton.icon(
                                onPressed: () => playClip(card),
                                icon: const Icon(Icons.volume_up),
                                label: const Text('Play'),
                              ),
                            if (!showKoreanSide)
                              FilledButton.tonal(
                                onPressed: () => isFlipped.value = true,
                                child: const Text('Show answer'),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              isFlipped.value ? 'Back: $secondaryText' : 'Tap to flip',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _showKoreanSide(FlashcardFront front, bool flipped) {
  if (front == FlashcardFront.korean) {
    return !flipped;
  }
  return flipped;
}

String _unitFromLessonId(String lessonId) {
  final numValue = int.tryParse(lessonId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  return 'Unit_$numValue';
}

