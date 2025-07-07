// lib/services/pexels_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:septima_biblia/models/pexels_model.dart'; // <<< Importa nosso novo modelo

class PexelsService {
  final String _apiKey;
  final String _baseUrl = 'api.pexels.com';

  PexelsService() : _apiKey = dotenv.env['PEXELS_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception('Chave da API Pexels não encontrada no arquivo .env');
    }
  }

  Map<String, String> get _headers => {
        'Authorization': _apiKey,
      };

  /// Busca fotos com base em uma query.
  Future<List<PexelsPhoto>> searchPhotos(String query,
      {int perPage = 30}) async {
    final uri = Uri.https(_baseUrl, '/v1/search', {
      'query': query,
      'per_page': perPage.toString(),
      'locale': 'pt-BR',
    });

    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List photosJson = data['photos'] ?? [];
        return photosJson.map((json) => PexelsPhoto.fromJson(json)).toList();
      } else {
        print(
            "Erro na API Pexels (Search): ${response.statusCode} ${response.body}");
        return [];
      }
    } catch (e) {
      print("Erro de conexão ao buscar fotos no Pexels: $e");
      return [];
    }
  }

  /// Busca fotos "curadas" (populares/em destaque).
  Future<List<PexelsPhoto>> getCuratedPhotos({int perPage = 30}) async {
    final uri = Uri.https(_baseUrl, '/v1/curated', {
      'per_page': perPage.toString(),
    });

    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List photosJson = data['photos'] ?? [];
        return photosJson.map((json) => PexelsPhoto.fromJson(json)).toList();
      } else {
        print(
            "Erro na API Pexels (Curated): ${response.statusCode} ${response.body}");
        return [];
      }
    } catch (e) {
      print("Erro de conexão ao buscar fotos curadas no Pexels: $e");
      return [];
    }
  }
}
