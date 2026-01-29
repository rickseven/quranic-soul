class Surah {
  final int id;
  final String name;
  final String reciter;
  final double durationSeconds;
  final bool isRecommend;
  final String filePath;
  final bool isFavorite;
  final bool isDownloaded;

  const Surah({
    required this.id,
    required this.name,
    required this.reciter,
    required this.durationSeconds,
    this.isRecommend = false,
    required this.filePath,
    this.isFavorite = false,
    this.isDownloaded = false,
  });

  String get duration {
    final totalSeconds = durationSeconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Surah copyWith({
    int? id,
    String? name,
    String? reciter,
    double? durationSeconds,
    bool? isRecommend,
    String? filePath,
    bool? isFavorite,
    bool? isDownloaded,
  }) {
    return Surah(
      id: id ?? this.id,
      name: name ?? this.name,
      reciter: reciter ?? this.reciter,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isRecommend: isRecommend ?? this.isRecommend,
      filePath: filePath ?? this.filePath,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
