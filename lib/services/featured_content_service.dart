// lib/services/featured_content_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/featured_content.dart';

/// Serviço responsável por carregar o conteúdo em destaque (guias e sequências)
/// a partir dos arquivos de assets JSON.
class FeaturedContentService {
  // Padrão Singleton: garante que teremos apenas uma instância deste serviço no app.
  FeaturedContentService._privateConstructor();
  static final FeaturedContentService instance =
      FeaturedContentService._privateConstructor();

  /// Carrega o manifesto de destaques, lê cada arquivo referenciado e
  /// retorna uma lista de objetos [FeaturedContent].
  Future<List<FeaturedContent>> getFeaturedItems() async {
    try {
      final manifestString =
          await rootBundle.loadString('assets/guias/featured_manifest.json');
      final manifestJson = json.decode(manifestString);

      final manifestItems = manifestJson['featuredItems'] as List<dynamic>?;
      if (manifestItems == null) {
        return [];
      }

      final List<FeaturedContent> featuredItems = [];

      for (final item in manifestItems) {
        if (item is Map<String, dynamic> && item['assetPath'] != null) {
          final assetPath = item['assetPath'] as String;
          final contentString = await rootBundle.loadString(assetPath);
          final contentJson = json.decode(contentString);

          // <<< ÚNICA MUDANÇA É AQUI >>>
          // Agora passamos o `assetPath` como segundo argumento.
          featuredItems.add(FeaturedContent.fromJson(contentJson, assetPath));
        }
      }

      return featuredItems;
    } catch (e) {
      print('Erro ao carregar conteúdo em destaque: $e');
      return [];
    }
  }
}
