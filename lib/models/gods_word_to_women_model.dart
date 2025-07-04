// lib/models/gods_word_to_women_model.dart

class GodsWordToWomenLesson {
  final String lessonNumber;
  final String lessonTitle;
  final List<String> content;

  GodsWordToWomenLesson({
    required this.lessonNumber,
    required this.lessonTitle,
    required this.content,
  });

  factory GodsWordToWomenLesson.fromJson(Map<String, dynamic> json) {
    return GodsWordToWomenLesson(
      lessonNumber: json['lesson_number'] as String? ?? '',
      lessonTitle: json['lesson_title'] as String? ?? 'Título Desconhecido',
      content: List<String>.from(json['content'] as List? ?? []),
    );
  }
}
