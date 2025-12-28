import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flashcard.dart';

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepository();
});

final flashcardsForUnitProvider =
    FutureProvider.family<List<Flashcard>, String>((ref, unitId) async {
  final repo = ref.read(flashcardRepositoryProvider);
  return repo.getByUnit(unitId);
});

final flashcardBookmarksProvider =
    FutureProvider.family<Set<int>, String>((ref, unitId) async {
  final repo = ref.read(flashcardRepositoryProvider);
  return repo.getBookmarks(unitId);
});

class FlashcardRepository {
  FlashcardRepository();

  static const _assetPath = 'assets/flashcard.json';
  static const _bookmarkPrefix = 'flashcard_bookmarks_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Flashcard>>? _cache;

  Future<List<Flashcard>> _loadAll() async {
    _cache ??= _loadFromAsset();
    return _cache!;
  }

  Future<List<Flashcard>> _loadFromAsset() async {
    final jsonStr = await rootBundle.loadString(_assetPath);
    final data = jsonDecode(jsonStr) as List<dynamic>;
    return data
        .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Flashcard>> getByUnit(String unitId) async {
    final all = await _loadAll();
    return all.where((c) => c.unit == unitId).toList();
  }

  Future<Set<int>> getBookmarks(String unitId) async {
    final prefs = await _prefs;
    final key = '$_bookmarkPrefix$unitId';
    final stored = prefs.getStringList(key);
    if (stored == null) return <int>{};
    return stored.map((e) => int.tryParse(e) ?? -1).where((e) => e >= 0).toSet();
  }

  Future<bool> toggleBookmark(String unitId, int cardId) async {
    final prefs = await _prefs;
    final key = '$_bookmarkPrefix$unitId';
    final current = await getBookmarks(unitId);
    final added = !current.contains(cardId);
    if (added) {
      current.add(cardId);
    } else {
      current.remove(cardId);
    }
    await prefs.setStringList(
      key,
      current.map((e) => e.toString()).toList(),
    );
    return added;
  }
}

