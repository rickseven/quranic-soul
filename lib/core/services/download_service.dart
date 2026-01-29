import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/surah.dart';
import '../config/env_config.dart';

/// Download state for tracking active downloads
class DownloadState {
  final int surahId;
  final String surahName;
  final double progress;
  final bool isCompleted;
  final bool isFailed;

  const DownloadState({
    required this.surahId,
    required this.surahName,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isFailed = false,
  });

  DownloadState copyWith({
    double? progress,
    bool? isCompleted,
    bool? isFailed,
  }) {
    return DownloadState(
      surahId: surahId,
      surahName: surahName,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}

/// Download Service for offline audio playback (PRO feature)
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Set<int> _downloadedSurahIds = {};
  final Map<int, double> _downloadProgress = {};
  bool _isInitialized = false;

  final _downloadStateController = StreamController<DownloadState?>.broadcast();
  Stream<DownloadState?> get downloadStateStream =>
      _downloadStateController.stream;

  DownloadState? _currentDownload;
  DownloadState? get currentDownload => _currentDownload;

  bool isDownloaded(int surahId) => _downloadedSurahIds.contains(surahId);
  double getDownloadProgress(int surahId) => _downloadProgress[surahId] ?? 0.0;
  List<int> get downloadedSurahIds => _downloadedSurahIds.toList();
  bool get isDownloading =>
      _currentDownload != null &&
      !_currentDownload!.isCompleted &&
      !_currentDownload!.isFailed;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final downloaded = prefs.getStringList('downloaded_surahs') ?? [];
      _downloadedSurahIds.addAll(downloaded.map((e) => int.parse(e)));
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  Future<String> getLocalFilePath(int surahId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/surahs/surah_$surahId.mp3';
  }

  Future<bool> fileExists(int surahId) async {
    final filePath = await getLocalFilePath(surahId);
    return File(filePath).exists();
  }

  Future<bool> downloadSurah(Surah surah) async {
    try {
      _currentDownload = DownloadState(
        surahId: surah.id,
        surahName: surah.name,
        progress: 0.0,
      );
      _downloadStateController.add(_currentDownload);

      final audioUrl = EnvConfig.getAudioUrl(surah.filePath);

      final directory = await getApplicationDocumentsDirectory();
      final surahsDir = Directory('${directory.path}/surahs');
      if (!await surahsDir.exists()) {
        await surahsDir.create(recursive: true);
      }

      final filePath = await getLocalFilePath(surah.id);
      final file = File(filePath);

      final request = await http.Client().send(
        http.Request('GET', Uri.parse(audioUrl)),
      );
      final contentLength = request.contentLength ?? 0;

      if (contentLength == 0) {
        _currentDownload = _currentDownload!.copyWith(isFailed: true);
        _downloadStateController.add(_currentDownload);
        _clearDownloadStateAfterDelay();
        return false;
      }

      final bytes = <int>[];
      int receivedBytes = 0;

      await for (final chunk in request.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;

        final progress = receivedBytes / contentLength;
        _downloadProgress[surah.id] = progress;

        _currentDownload = _currentDownload!.copyWith(progress: progress);
        _downloadStateController.add(_currentDownload);
      }

      await file.writeAsBytes(bytes);

      _downloadedSurahIds.add(surah.id);
      await _saveDownloadedList();

      _downloadProgress.remove(surah.id);

      _currentDownload = _currentDownload!.copyWith(
        isCompleted: true,
        progress: 1.0,
      );
      _downloadStateController.add(_currentDownload);

      _clearDownloadStateAfterDelay();

      return true;
    } catch (_) {
      _downloadProgress.remove(surah.id);

      if (_currentDownload != null) {
        _currentDownload = _currentDownload!.copyWith(isFailed: true);
        _downloadStateController.add(_currentDownload);
        _clearDownloadStateAfterDelay();
      }

      return false;
    }
  }

  void _clearDownloadStateAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      _currentDownload = null;
      _downloadStateController.add(null);
    });
  }

  Future<bool> deleteSurah(int surahId) async {
    try {
      final filePath = await getLocalFilePath(surahId);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      _downloadedSurahIds.remove(surahId);
      await _saveDownloadedList();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> getAudioSource(Surah surah) async {
    if (isDownloaded(surah.id)) {
      final exists = await fileExists(surah.id);

      if (exists) {
        final localPath = await getLocalFilePath(surah.id);
        return localPath;
      } else {
        _downloadedSurahIds.remove(surah.id);
        await _saveDownloadedList();
      }
    }

    final streamUrl = EnvConfig.getAudioUrl(surah.filePath);
    return streamUrl;
  }

  Future<void> _saveDownloadedList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'downloaded_surahs',
        _downloadedSurahIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<int> getTotalDownloadedSize() async {
    int totalSize = 0;
    for (final surahId in _downloadedSurahIds) {
      final filePath = await getLocalFilePath(surahId);
      final file = File(filePath);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> clearAllDownloads() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final surahsDir = Directory('${directory.path}/surahs');

      if (await surahsDir.exists()) {
        await surahsDir.delete(recursive: true);
      }

      _downloadedSurahIds.clear();
      await _saveDownloadedList();
    } catch (_) {}
  }

  void dispose() {
    _downloadStateController.close();
  }
}
