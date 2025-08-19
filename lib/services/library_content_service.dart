// lib/services/library_content_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para uma unidade de conteúdo SEM o texto completo
class ContentUnitPreview {
  final String contentId;
  final String title;
  final List<String> path;
  final String preview;
  final String sourceTitle;

  ContentUnitPreview({
    required this.contentId,
    required this.title,
    required this.path,
    required this.preview,
    required this.sourceTitle,
  });
}

class LibraryContentService {
  LibraryContentService._privateConstructor();
  static final LibraryContentService instance =
      LibraryContentService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, ContentUnitPreview> _previewCache = {};
  final Map<String, String> _fullContentCache = {};

  /// Busca os dados de PREVIEW de uma unidade de conteúdo.
  /// Primeiro, verifica o cache. Se não encontrar, busca no Firestore.
  Future<ContentUnitPreview?> getContentUnitPreview(String contentId) async {
    if (_previewCache.containsKey(contentId)) {
      return _previewCache[contentId];
    }

    try {
      print(
          "LibraryContentService: Buscando PREVIEW de '${contentId}' no Firestore...");
      // Seleciona todos os campos EXCETO 'content' para economizar dados
      final docSnapshot =
          await _db.collection('libraryContent').doc(contentId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final preview = ContentUnitPreview(
          contentId: contentId,
          title: data['title'] ?? 'Sem Título',
          path: List<String>.from(data['path'] ?? []),
          preview: data['preview'] ?? '',
          sourceTitle: data['sourceTitle'] ?? 'Fonte Desconhecida',
        );
        _previewCache[contentId] = preview;
        return preview;
      } else {
        print(
            "LibraryContentService: Documento (preview) '${contentId}' não encontrado.");
        return null;
      }
    } catch (e) {
      print(
          "ERRO no LibraryContentService ao buscar preview de '${contentId}': $e");
      return null;
    }
  }

  /// Busca o CONTEÚDO COMPLETO de uma unidade.
  /// Primeiro, verifica o cache. Se não encontrar, busca no Firestore.
  Future<String?> getFullContent(String contentId) async {
    if (_fullContentCache.containsKey(contentId)) {
      return _fullContentCache[contentId];
    }
    try {
      print(
          "LibraryContentService: Buscando CONTEÚDO COMPLETO de '${contentId}' no Firestore...");
      final docSnapshot =
          await _db.collection('libraryContent').doc(contentId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final contentList = data['content'] as List<dynamic>? ?? [];
        final fullContent = contentList.cast<String>().join('\n\n');

        _fullContentCache[contentId] = fullContent;
        return fullContent;
      } else {
        print(
            "LibraryContentService: Documento (conteúdo completo) '${contentId}' não encontrado.");
        return null;
      }
    } catch (e) {
      print(
          "ERRO no LibraryContentService ao buscar conteúdo completo de '${contentId}': $e");
      return null;
    }
  }
}
