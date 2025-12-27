import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hapticsKey = 'settings_haptics_enabled';
const _resumeLastLessonKey = 'settings_resume_last_lesson';

class AppSettings {
  const AppSettings({
    required this.hapticsEnabled,
    required this.resumeLastLesson,
  });

  final bool hapticsEnabled;
  final bool resumeLastLesson;

  AppSettings copyWith({
    bool? hapticsEnabled,
    bool? resumeLastLesson,
  }) {
    return AppSettings(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      resumeLastLesson: resumeLastLesson ?? this.resumeLastLesson,
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  return repo.load();
});

class SettingsRepository {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final prefs = await _prefs;
    final haptics = prefs.getBool(_hapticsKey);
    final resume = prefs.getBool(_resumeLastLessonKey);
    return AppSettings(
      hapticsEnabled: haptics ?? true,
      resumeLastLesson: resume ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setBool(_hapticsKey, settings.hapticsEnabled);
    await prefs.setBool(_resumeLastLessonKey, settings.resumeLastLesson);
  }
}

