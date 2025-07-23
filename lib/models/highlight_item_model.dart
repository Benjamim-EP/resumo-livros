// lib/models/highlight_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Import para Timestamp

// ===================================
// <<< ENUM ATUALIZADO >>>
// Adiciona o novo tipo para frases curtidas.
// ===================================
enum HighlightItemType { verse, literature, likedQuote }

/// Representa um item unificado para ser exibido na lista de "Destaques" do usuário.
/// Pode ser um versículo bíblico destacado, um trecho de literatura marcado,
/// ou uma frase curtida do BibTok.
class HighlightItem {
  /// ID único do item (seja o verseId, o ID do highlight do comentário, ou o ID da frase).
  final String id;

  /// O tipo do item, para que a UI saiba como renderizá-lo.
  final HighlightItemType type;

  /// O texto de referência principal (ex: "Gênesis 1:1" ou "C.S. Lewis, em 'Cristianismo Puro e Simples'").
  final String referenceText;

  /// Uma prévia do conteúdo (o texto do versículo, o snippet destacado ou o texto da frase).
  final String contentPreview;

  /// Uma lista de tags associadas (relevante apenas para `verse` e `literature`).
  final List<String> tags;

  /// O código hexadecimal da cor do destaque (relevante apenas para `verse` e `literature`).
  final String? colorHex;

  /// O mapa original de dados vindo do Firestore, para acesso a informações adicionais.
  final Map<String, dynamic> originalData;

  HighlightItem({
    required this.id,
    required this.type,
    required this.referenceText,
    required this.contentPreview,
    required this.tags,
    this.colorHex,
    required this.originalData,
  });
}
