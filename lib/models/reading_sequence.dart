// lib/models/reading_sequence.dart

class ReadingSequence {
  final String id;
  final String title;
  final String description;
  final String featuredImage;
  final String duration;
  final List<SequenceStep> steps;

  ReadingSequence({
    required this.id,
    required this.title,
    required this.description,
    required this.featuredImage,
    required this.duration,
    required this.steps,
  });

  factory ReadingSequence.fromJson(Map<String, dynamic> json) {
    var stepsFromJson = json['steps'] as List<dynamic>? ?? [];
    List<SequenceStep> stepsList =
        stepsFromJson.map((i) => SequenceStep.fromJson(i)).toList();

    return ReadingSequence(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Sequência de Leitura',
      description: json['description'] ?? '',
      featuredImage: json['featuredImage'] ?? '',
      duration: json['duration'] ?? '',
      steps: stepsList,
    );
  }
}

class SequenceStep {
  // <<< INÍCIO DA CORREÇÃO >>>
  final int stepNumber; // Armazena o número (seja da semana ou do mês)
  final String stepType; // Armazena o texto ("Semana" ou "Mês")
  // <<< FIM DA CORREÇÃO >>>

  final String title;
  final String focus;
  final List<SequenceResource> resources;

  SequenceStep({
    required this.stepNumber,
    required this.stepType,
    required this.title,
    required this.focus,
    required this.resources,
  });

  factory SequenceStep.fromJson(Map<String, dynamic> json) {
    var resourcesFromJson = json['resources'] as List<dynamic>? ?? [];
    List<SequenceResource> resourcesList =
        resourcesFromJson.map((i) => SequenceResource.fromJson(i)).toList();

    // <<< INÍCIO DA CORREÇÃO PRINCIPAL >>>
    // Lógica para detectar se o JSON usa 'week' ou 'month'
    int number = 0;
    String type = 'Etapa'; // Um fallback caso nenhum dos dois seja encontrado

    if (json.containsKey('week')) {
      number = json['week'] ?? 0;
      type = 'Semana';
    } else if (json.containsKey('month')) {
      number = json['month'] ?? 0;
      type = 'Mês';
    }
    // <<< FIM DA CORREÇÃO PRINCIPAL >>>

    return SequenceStep(
      stepNumber: number,
      stepType: type,
      title: json['title'] ?? 'Etapa',
      focus: json['focus'] ?? '',
      resources: resourcesList,
    );
  }
}

class SequenceResource {
  final String title;
  final String resourceId;

  SequenceResource({required this.title, required this.resourceId});

  factory SequenceResource.fromJson(Map<String, dynamic> json) {
    return SequenceResource(
      title: json['title'] ?? 'Livro',
      resourceId: json['resourceId'] ?? '',
    );
  }
}
