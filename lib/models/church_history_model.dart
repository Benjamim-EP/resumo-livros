// lib/models/church_history_model.dart

class ChurchHistoryVolume {
  final String title;
  final List<ChurchHistoryChapter> chapters;

  ChurchHistoryVolume({required this.title, required this.chapters});

  factory ChurchHistoryVolume.fromJson(Map<String, dynamic> json) {
    var chapterList = json['chapters'] as List? ?? [];
    List<ChurchHistoryChapter> chapters =
        chapterList.map((i) => ChurchHistoryChapter.fromJson(i)).toList();

    return ChurchHistoryVolume(
      title: json['volume_title'] ?? 'Volume Desconhecido',
      chapters: chapters,
    );
  }
}

class ChurchHistoryChapter {
  final String title;
  final List<String> content;

  ChurchHistoryChapter({required this.title, required this.content});

  factory ChurchHistoryChapter.fromJson(Map<String, dynamic> json) {
    var contentList = json['content'] as List? ?? [];
    List<String> content = contentList.map((i) => i.toString()).toList();

    return ChurchHistoryChapter(
      title: json['chapter_title'] ?? 'Capítulo Desconhecido',
      content: content,
    );
  }
}
