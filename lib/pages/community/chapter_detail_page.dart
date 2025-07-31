// lib/pages/community/chapter_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/models/course_model.dart';

class ChapterDetailPage extends StatelessWidget {
  final String courseId;
  final String partId;
  final String chapterId;

  const ChapterDetailPage({
    super.key,
    required this.courseId,
    required this.partId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chapterId, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('cursos')
            .doc(courseId)
            .collection(partId)
            .doc(chapterId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text("Conteúdo do capítulo não encontrado."));
          }

          final chapter = CourseChapter.fromFirestore(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ..._buildRestructuredDocument(
                  context, chapter.restructuredDocument),
              if (chapter.completeBibliography.isNotEmpty)
                _buildBibliography(context, chapter.completeBibliography),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildRestructuredDocument(
      BuildContext context, List<MainTopic> topics) {
    final theme = Theme.of(context);
    return topics.map((mainTopic) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ExpansionTile(
          title: Text(mainTopic.title, style: theme.textTheme.titleLarge),
          children: mainTopic.subtopics.map((subTopic) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subTopic.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...subTopic.detailedContent.map((content) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Chip(
                            label: Text(content.type),
                            backgroundColor: theme
                                .colorScheme.secondaryContainer
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(content.text,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(height: 1.5)),
                          if (content.bibliographicReference != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                content.bibliographicReference!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildBibliography(BuildContext context, List<String> bibliography) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text("Bibliografia Completa", style: theme.textTheme.titleLarge),
        children: bibliography.map((entry) {
          return ListTile(
            leading: const Icon(Icons.book_outlined),
            title: Text(entry, style: theme.textTheme.bodyMedium),
          );
        }).toList(),
      ),
    );
  }
}
