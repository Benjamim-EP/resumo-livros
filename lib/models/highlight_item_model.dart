// lib/models/highlight_item_model.dart

enum HighlightItemType { verse, comment }

class HighlightItem {
  final String
      id; // Pode ser o verseId ou o ID do documento de destaque do comentário
  final HighlightItemType type;
  final String
      referenceText; // Ex: "Gênesis 1:1" ou "Comentário em Gênesis 1:1-5"
  final String
      contentPreview; // O texto do versículo ou o trecho destacado do comentário
  final List<String> tags;
  final String? colorHex; // Nulo para destaques de comentários
  final Map<String, dynamic>
      originalData; // Guarda o mapa original para ações como navegação

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
