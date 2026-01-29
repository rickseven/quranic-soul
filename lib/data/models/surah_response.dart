import '../../domain/entities/surah.dart';

class SurahResponse {
  final String surah;
  final String reciter;
  final double duration;
  final bool isRecommend;
  final String file;

  SurahResponse({
    required this.surah,
    required this.reciter,
    required this.duration,
    required this.isRecommend,
    required this.file,
  });

  factory SurahResponse.fromJson(Map<String, dynamic> json) {
    return SurahResponse(
      surah: json['surah'] as String,
      reciter: json['reciter'] as String,
      duration: (json['duration'] as num).toDouble(),
      isRecommend: json['is_recommend'] as bool? ?? false,
      file: json['file'] as String,
    );
  }

  Surah toEntity(int id) {
    return Surah(
      id: id,
      name: surah,
      reciter: reciter,
      durationSeconds: duration,
      isRecommend: isRecommend,
      filePath: file,
    );
  }
}
