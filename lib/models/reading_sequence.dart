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
  final int month;
  final String title;
  final String focus;
  final List<SequenceResource> resources;

  SequenceStep({
    required this.month,
    required this.title,
    required this.focus,
    required this.resources,
  });

  factory SequenceStep.fromJson(Map<String, dynamic> json) {
    var resourcesFromJson = json['resources'] as List<dynamic>? ?? [];
    List<SequenceResource> resourcesList =
        resourcesFromJson.map((i) => SequenceResource.fromJson(i)).toList();

    return SequenceStep(
      month: json['month'] ?? 0,
      title: json['title'] ?? 'Mês',
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
