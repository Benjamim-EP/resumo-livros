// lib/models/highlight_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Import para Timestamp

// >>> MUDANÇA AQUI <<<
enum HighlightItemType { verse, literature }

class HighlightItem {
  final String id;
  final HighlightItemType type;
  final String referenceText;
  final String contentPreview;
  final List<String> tags;
  final String? colorHex;
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
