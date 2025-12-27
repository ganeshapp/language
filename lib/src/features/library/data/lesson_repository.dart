import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/models/lesson_progress.dart';

const _lastOpenedLessonKey = 'last_opened_lesson_id';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository();
});

class LessonRepository {
  LessonRepository();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> initializeLessons() async {
    final prefs = await _prefs;
    final updates = <String, String>{};
    for (var i = 1; i <= 60; i++) {
      final id = 'unit_$i';
      if (!prefs.containsKey(id)) {
        final lesson = LessonProgress.fromUnitIndex(i);
        updates[id] = jsonEncode(lesson.toJson());
      }
    }
    if (updates.isNotEmpty) {
      for (final entry in updates.entries) {
        await prefs.setString(entry.key, entry.value);
      }
    }
  }

  Future<List<LessonProgress>> getAllLessons() async {
    final prefs = await _prefs;
    final lessons = <LessonProgress>[];
    for (var i = 1; i <= 60; i++) {
      final id = 'unit_$i';
      final jsonStr = prefs.getString(id);
      if (jsonStr != null) {
        lessons.add(LessonProgress.fromJson(id, jsonDecode(jsonStr)));
      } else {
        final created = LessonProgress.fromUnitIndex(i);
        lessons.add(created);
        await prefs.setString(id, jsonEncode(created.toJson()));
      }
    }
    lessons.sort((a, b) => _unitNumber(a.id).compareTo(_unitNumber(b.id)));
    return lessons;
  }

  Future<LessonProgress> getOrCreateLesson(String id) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(id);
    if (jsonStr != null) {
      return LessonProgress.fromJson(id, jsonDecode(jsonStr));
    }
    final unitNumber = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (unitNumber <= 0 || unitNumber > 60) {
      throw StateError('Invalid lesson id: $id');
    }
    final created = LessonProgress.fromUnitIndex(unitNumber);
    await prefs.setString(id, jsonEncode(created.toJson()));
    return created;
  }

  Future<void> saveLesson(LessonProgress lesson) async {
    final prefs = await _prefs;
    await prefs.setString(lesson.id, jsonEncode(lesson.toJson()));
  }

  Future<void> setLastOpenedLessonId(String id) async {
    final prefs = await _prefs;
    await prefs.setString(_lastOpenedLessonKey, id);
  }

  Future<String?> getLastOpenedLessonId() async {
    final prefs = await _prefs;
    return prefs.getString(_lastOpenedLessonKey);
  }

  Future<void> resetLesson(String id) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(id);
    LessonProgress lesson;
    if (jsonStr != null) {
      lesson = LessonProgress.fromJson(id, jsonDecode(jsonStr));
    } else {
      lesson = LessonProgress.fromUnitIndex(_unitNumber(id));
    }
    final cleared = lesson.copyWith(
      lastPositionSeconds: 0,
      durationSeconds: lesson.durationSeconds,
      isCompleted: false,
      bookmarks: <int>[],
    );
    await saveLesson(cleared);
  }

  int _unitNumber(String id) {
    final numValue = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), ''));
    return numValue ?? 0;
  }
}

