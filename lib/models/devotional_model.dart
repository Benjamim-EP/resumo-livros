// lib/models/devotional_model.dart

class DevotionalMonth {
  final String title;
  final List<DevotionalReading> readings;

  DevotionalMonth({required this.title, required this.readings});

  factory DevotionalMonth.fromJson(Map<String, dynamic> json) {
    var readingsList = json['readings'] as List? ?? [];
    List<DevotionalReading> readings =
        readingsList.map((item) => DevotionalReading.fromJson(item)).toList();

    return DevotionalMonth(
      title: json['section_title'] ?? 'Mês Desconhecido',
      readings: readings,
    );
  }
}

class DevotionalReading {
  final String title;
  final String scriptureVerse;
  final String scripturePassage;
  final List<String> content;

  DevotionalReading({
    required this.title,
    required this.scriptureVerse,
    required this.scripturePassage,
    required this.content,
  });

  factory DevotionalReading.fromJson(Map<String, dynamic> json) {
    var contentList = json['content'] as List? ?? [];
    List<String> content = contentList.map((item) => item.toString()).toList();

    return DevotionalReading(
      title: json['reading_title'] ?? 'Leitura Desconhecida',
      scriptureVerse: json['scripture_verse'] ?? '',
      scripturePassage: json['scripture_passage'] ?? '',
      content: content,
    );
  }
}
