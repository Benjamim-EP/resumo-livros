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
      // 1. Carrega o arquivo "manifesto" que nos diz quais itens mostrar.
      final manifestString =
          await rootBundle.loadString('assets/guias/featured_manifest.json');
      final manifestJson = json.decode(manifestString);

      // Pega a lista de itens do manifesto. Se não existir, retorna uma lista vazia.
      final manifestItems = manifestJson['featuredItems'] as List<dynamic>?;
      if (manifestItems == null) {
        return [];
      }

      final List<FeaturedContent> featuredItems = [];

      // 2. Itera sobre cada item no manifesto.
      for (final item in manifestItems) {
        if (item is Map<String, dynamic> && item['assetPath'] != null) {
          final assetPath = item['assetPath'] as String;

          // 3. Carrega o conteúdo do arquivo JSON específico de cada item.
          final contentString = await rootBundle.loadString(assetPath);
          final contentJson = json.decode(contentString);

          // 4. Converte o JSON em um objeto Dart usando nosso modelo do Passo 2.
          featuredItems.add(FeaturedContent.fromJson(contentJson));
        }
      }

      return featuredItems;
    } catch (e) {
      // 5. Em caso de erro (arquivo não encontrado, JSON mal formatado),
      // imprime o erro no console e retorna uma lista vazia para não quebrar a UI.
      print('Erro ao carregar conteúdo em destaque: $e');
      return [];
    }
  }
}
