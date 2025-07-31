// lib/models/course_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para o conteúdo detalhado de um subtópico
class DetailedContent {
  final String type;
  final String text;
  final String? bibliographicReference;

  DetailedContent({
    required this.type,
    required this.text,
    this.bibliographicReference,
  });

  factory DetailedContent.fromJson(Map<String, dynamic> json) {
    return DetailedContent(
      type: json['tipo'] ?? 'Texto',
      text: json['texto'] ?? 'Conteúdo indisponível.',
      bibliographicReference: json['referencia_bibliografica'],
    );
  }
}

// Modelo para um subtópico
class SubTopic {
  final String id;
  final String title;
  final List<DetailedContent> detailedContent;

  SubTopic({
    required this.id,
    required this.title,
    required this.detailedContent,
  });

  factory SubTopic.fromJson(Map<String, dynamic> json) {
    var contentList = json['conteudo_detalhado'] as List? ?? [];
    return SubTopic(
      id: json['id'] ?? '',
      title: json['titulo_subtopico'] ?? 'Subtópico sem título',
      detailedContent:
          contentList.map((i) => DetailedContent.fromJson(i)).toList(),
    );
  }
}

// Modelo para um tópico principal
class MainTopic {
  final String id;
  final String title;
  final List<SubTopic> subtopics;

  MainTopic({
    required this.id,
    required this.title,
    required this.subtopics,
  });

  factory MainTopic.fromJson(Map<String, dynamic> json) {
    var subtopicList = json['subtopicos'] as List? ?? [];
    return MainTopic(
      id: json['id'] ?? '',
      title: json['titulo_topico'] ?? 'Tópico principal sem título',
      subtopics: subtopicList.map((i) => SubTopic.fromJson(i)).toList(),
    );
  }
}

// Modelo para o documento completo de um capítulo
class CourseChapter {
  final List<MainTopic> restructuredDocument;
  final List<String> completeBibliography;

  CourseChapter({
    required this.restructuredDocument,
    required this.completeBibliography,
  });

  factory CourseChapter.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var documentList = data['documento_reestruturado'] as List? ?? [];
    var biblioList = data['bibliografia_completa'] as List? ?? [];

    return CourseChapter(
      restructuredDocument:
          documentList.map((i) => MainTopic.fromJson(i)).toList(),
      completeBibliography: biblioList.map((i) => i.toString()).toList(),
    );
  }
}
