// lib/models/promise_model.dart

class PromiseBook {
  final String bookTitle;
  final String author;
  final List<PromisePart> parts;

  PromiseBook({
    required this.bookTitle,
    required this.author,
    required this.parts,
  });

  factory PromiseBook.fromJson(Map<String, dynamic> json) {
    return PromiseBook(
      bookTitle: json['book'] as String? ?? 'Promessas da Bíblia',
      author: json['author'] as String? ?? 'Desconhecido',
      parts: (json['parts'] as List<dynamic>? ?? [])
          .map((partJson) =>
              PromisePart.fromJson(partJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PromisePart {
  final int partNumber;
  final String title;
  final List<PromiseChapter> chapters;

  PromisePart({
    required this.partNumber,
    required this.title,
    required this.chapters,
  });

  factory PromisePart.fromJson(Map<String, dynamic> json) {
    return PromisePart(
      partNumber: json['part_number'] as int? ?? 0,
      title: json['title'] as String? ?? 'Parte Desconhecida',
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((chapterJson) =>
              PromiseChapter.fromJson(chapterJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PromiseChapter {
  final int chapterNumber;
  final String title;
  final List<PromiseSection> sections;

  PromiseChapter({
    required this.chapterNumber,
    required this.title,
    required this.sections,
  });

  factory PromiseChapter.fromJson(Map<String, dynamic> json) {
    return PromiseChapter(
      chapterNumber: json['chapter_number'] as int? ?? 0,
      title: json['title'] as String? ?? 'Capítulo Desconhecido',
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((sectionJson) =>
              PromiseSection.fromJson(sectionJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PromiseSection {
  final int sectionNumber;
  final String title;
  final List<PromiseVerse>?
      verses; // Pode não ter versos diretos se tiver subseções
  final List<PromiseSubsection>? subsections; // Pode não ter subseções

  PromiseSection({
    required this.sectionNumber,
    required this.title,
    this.verses,
    this.subsections,
  });

  factory PromiseSection.fromJson(Map<String, dynamic> json) {
    return PromiseSection(
      sectionNumber: json['section_number'] as int? ?? 0,
      title: json['title'] as String? ?? 'Seção Desconhecida',
      verses: (json['verses'] as List<dynamic>?)
          ?.map((verseJson) =>
              PromiseVerse.fromJson(verseJson as Map<String, dynamic>))
          .toList(),
      subsections: (json['subsections'] as List<dynamic>?)
          ?.map((subsectionJson) => PromiseSubsection.fromJson(
              subsectionJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PromiseSubsection {
  final String title;
  final List<PromiseVerse> verses;

  PromiseSubsection({
    required this.title,
    required this.verses,
  });

  factory PromiseSubsection.fromJson(Map<String, dynamic> json) {
    return PromiseSubsection(
      title: json['title'] as String? ?? 'Subseção Desconhecida',
      verses: (json['verses'] as List<dynamic>? ?? [])
          .map((verseJson) =>
              PromiseVerse.fromJson(verseJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PromiseVerse {
  final String text;
  final String reference;

  PromiseVerse({
    required this.text,
    required this.reference,
  });

  factory PromiseVerse.fromJson(Map<String, dynamic> json) {
    return PromiseVerse(
      text: json['text'] as String? ?? 'Texto indisponível',
      reference: json['reference'] as String? ?? 'Referência indisponível',
    );
  }
}
