import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lastListenDayKey = 'streak_last_listen_day';
const _currentStreakKey = 'streak_current';
const _bestStreakKey = 'streak_best';
const _todaySecondsKey = 'streak_today_seconds';

class StreakStats {
  const StreakStats({
    required this.current,
    required this.best,
    required this.todaySeconds,
  });

  final int current;
  final int best;
  final int todaySeconds;
}

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepository();
});

final streakProvider = FutureProvider<StreakStats>((ref) async {
  final repo = ref.read(streakRepositoryProvider);
  return repo.load();
});

class StreakRepository {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  int _todayEpochDay() {
    final now = DateTime.now().toUtc();
    return now.toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;
  }

  Future<StreakStats> load() async {
    final prefs = await _prefs;
    return StreakStats(
      current: prefs.getInt(_currentStreakKey) ?? 0,
      best: prefs.getInt(_bestStreakKey) ?? 0,
      todaySeconds: prefs.getInt(_todaySecondsKey) ?? 0,
    );
  }

  Future<void> addListeningSeconds(int seconds) async {
    if (seconds <= 0) return;
    final prefs = await _prefs;
    final today = _todayEpochDay();
    final lastDay = prefs.getInt(_lastListenDayKey);
    var current = prefs.getInt(_currentStreakKey) ?? 0;
    var best = prefs.getInt(_bestStreakKey) ?? 0;
    var todaySeconds = prefs.getInt(_todaySecondsKey) ?? 0;

    if (lastDay == null) {
      current = 1;
    } else if (today == lastDay) {
      // same day
    } else if (today == lastDay + 1) {
      current += 1;
      todaySeconds = 0;
    } else if (today > lastDay + 1) {
      current = 1;
      todaySeconds = 0;
    }

    best = best < current ? current : best;
    todaySeconds += seconds;

    await prefs.setInt(_lastListenDayKey, today);
    await prefs.setInt(_currentStreakKey, current);
    await prefs.setInt(_bestStreakKey, best);
    await prefs.setInt(_todaySecondsKey, todaySeconds);
  }
}

