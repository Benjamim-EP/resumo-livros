// lib/models/bible_saga_model.dart

class BibleSaga {
  final String id; // O ID do documento (ex: 'historia_de_samsao')
  final String title;
  final String description;
  final String type; // 'personagem' ou 'evento'
  final List<String> sections;
  final Map<String, dynamic> startReference;

  BibleSaga({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.sections,
    required this.startReference,
  });

  factory BibleSaga.fromFirestore(String docId, Map<String, dynamic> data) {
    return BibleSaga(
      id: docId,
      title: data['title'] ?? 'Saga Desconhecida',
      description: data['description'] ?? '',
      type: data['type'] ?? 'evento',
      sections: List<String>.from(data['sections'] ?? []),
      startReference: Map<String, dynamic>.from(data['startReference'] ?? {}),
    );
  }
}
