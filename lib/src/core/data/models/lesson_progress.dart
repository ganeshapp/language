class LessonProgress {
  const LessonProgress({
    required this.id,
    required this.title,
    required this.filePath,
    this.durationSeconds = 0,
    this.lastPositionSeconds = 0,
    this.isCompleted = false,
    List<int>? bookmarks,
  }) : bookmarks = bookmarks ?? const [];

  final String id;
  final String title;
  final String filePath;
  final int durationSeconds;
  final int lastPositionSeconds;
  final bool isCompleted;
  final List<int> bookmarks;

  LessonProgress copyWith({
    String? id,
    String? title,
    String? filePath,
    int? durationSeconds,
    int? lastPositionSeconds,
    bool? isCompleted,
    List<int>? bookmarks,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      bookmarks: bookmarks ?? List<int>.from(this.bookmarks),
    );
  }

  Map<String, dynamic> toJson() => {
        't': title,
        'f': filePath,
        'd': durationSeconds,
        'p': lastPositionSeconds,
        'c': isCompleted,
        'b': bookmarks,
      };

  factory LessonProgress.fromJson(String id, Map<String, dynamic> json) {
    return LessonProgress(
      id: id,
      title: json['t'] as String? ?? 'Unit ${_idToNumber(id)}',
      filePath: json['f'] as String? ?? 'assets/audio/Unit_${_idToNumber(id)}.mp3',
      durationSeconds: (json['d'] as num?)?.toInt() ?? 0,
      lastPositionSeconds: (json['p'] as num?)?.toInt() ?? 0,
      isCompleted: json['c'] as bool? ?? false,
      bookmarks: (json['b'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    );
  }

  static int _idToNumber(String id) {
    return int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static LessonProgress fromUnitIndex(int index) {
    return LessonProgress(
      id: 'unit_$index',
      title: 'Unit $index',
      filePath: 'assets/audio/Unit_$index.mp3',
    );
  }
}

