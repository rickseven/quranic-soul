import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/env_config.dart';
import '../models/surah_response.dart';

abstract class SurahRemoteDataSource {
  Future<List<SurahResponse>> fetchSurahs();
}

class SurahRemoteDataSourceImpl implements SurahRemoteDataSource {
  final http.Client client;

  SurahRemoteDataSourceImpl({required this.client});

  @override
  Future<List<SurahResponse>> fetchSurahs() async {
    final response = await client.get(Uri.parse(EnvConfig.quranDataUrl));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => SurahResponse.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load surahs: ${response.statusCode}');
    }
  }
}
