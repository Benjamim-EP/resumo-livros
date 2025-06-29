// lib/models/turretin_theology_model.dart

class ElencticTopic {
  final String topicTitle;
  final List<ElencticQuestion> questions;

  ElencticTopic({required this.topicTitle, required this.questions});

  factory ElencticTopic.fromJson(Map<String, dynamic> json) {
    var questionsList = json['questions'] as List? ?? [];
    List<ElencticQuestion> parsedQuestions =
        questionsList.map((q) => ElencticQuestion.fromJson(q)).toList();

    return ElencticTopic(
      topicTitle: json['topic_title'] ?? 'Tópico Desconhecido',
      questions: parsedQuestions,
    );
  }
}

class ElencticQuestion {
  final String questionTitle;
  final String questionStatement;
  final List<String> content;

  ElencticQuestion({
    required this.questionTitle,
    required this.questionStatement,
    required this.content,
  });

  factory ElencticQuestion.fromJson(Map<String, dynamic> json) {
    var contentList = json['content'] as List? ?? [];
    List<String> parsedContent = contentList.map((c) => c.toString()).toList();

    return ElencticQuestion(
      questionTitle: json['question_title'] ?? 'Questão Desconhecida',
      questionStatement: json['question_statement'] ?? '',
      content: parsedContent,
    );
  }
}
