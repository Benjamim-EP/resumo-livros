// lib/services/library_content_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Modelo para uma unidade de conteúdo padronizada
class ContentUnit {
  final String contentId;
  final String title;
  final List<String> path;
  final String content;
  final String preview;
  final String sourceTitle; // Título da obra (ex: "Institutas de Turretin")

  ContentUnit({
    required this.contentId,
    required this.title,
    required this.path,
    required this.content,
    required this.preview,
    required this.sourceTitle,
  });
}

// Serviço Singleton para gerenciar o conteúdo da biblioteca
class LibraryContentService {
  // Padrão Singleton
  LibraryContentService._privateConstructor();
  static final LibraryContentService instance =
      LibraryContentService._privateConstructor();

  Map<String, ContentUnit> _contentMap = {};
  bool _isLoaded = false;

  /// Carrega e processa o arquivo JSON da biblioteca. Deve ser chamado na inicialização do app.
  Future<void> loadContent() async {
    if (_isLoaded) return;
    try {
      print(
          "LibraryContentService: Carregando standardized_library_content.json...");
      final String jsonString = await rootBundle
          .loadString('assets/data/standardized_library_content.json');
      final List<dynamic> sources = json.decode(jsonString);

      final Map<String, ContentUnit> tempMap = {};
      for (var source in sources) {
        final sourceTitle = source['sourceTitle'] ?? 'Fonte Desconhecida';
        final List<dynamic> units = source['contentUnits'] ?? [];
        for (var unit in units) {
          final contentId = unit['contentId'] as String?;
          if (contentId != null) {
            tempMap[contentId] = ContentUnit(
              contentId: contentId,
              title: unit['title'] ?? 'Sem Título',
              path: List<String>.from(unit['path'] ?? []),
              content: unit['content'] ?? 'Conteúdo indisponível.',
              preview: unit['preview'] ?? '',
              sourceTitle: sourceTitle,
            );
          }
        }
      }
      _contentMap = tempMap;
      _isLoaded = true;
      print(
          "LibraryContentService: Carregamento concluído. ${_contentMap.length} unidades de conteúdo disponíveis.");
    } catch (e) {
      print("ERRO CRÍTICO ao carregar LibraryContentService: $e");
    }
  }

  /// Retorna os detalhes de uma unidade de conteúdo específica pelo seu ID.
  ContentUnit? getContentUnit(String contentId) {
    return _contentMap[contentId];
  }
}
