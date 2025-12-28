class Flashcard {
  const Flashcard({
    required this.id,
    required this.unit,
    required this.englishPhrase,
    required this.koreanPhrase,
    required this.audioPath,
  });

  final int id;
  final String unit;
  final String englishPhrase;
  final String koreanPhrase;
  final String audioPath;

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: (json['id'] as num).toInt(),
      unit: json['unit'] as String,
      englishPhrase: json['english_phrase'] as String? ?? '',
      koreanPhrase: json['korean_phrase'] as String? ?? '',
      audioPath: json['audio_path'] as String? ?? '',
    );
  }
}

