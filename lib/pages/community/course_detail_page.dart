// lib/pages/community/course_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/pages/community/chapter_detail_page.dart';

class CourseDetailPage extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(courseTitle),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('cursos').doc(courseId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text("Detalhes do curso não encontrados."));
          }

          final courseData = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> parts =
              List<String>.from(courseData['partes'] ?? []);

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: parts.length,
            itemBuilder: (context, index) {
              final partName = parts[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  title: Text(partName, style: theme.textTheme.titleLarge),
                  children: [
                    _buildChapterList(context, partName),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChapterList(BuildContext context, String partId) {
    final theme = Theme.of(context); // Pega o tema para estilizar

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cursos')
          .doc(courseId)
          .collection(partId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // <<< AQUI ESTÁ A MUDANÇA >>>
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Em vez de um ListTile simples, mostramos uma mensagem mais elaborada.
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.update,
                    size: 32,
                    color: theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Capítulos em breve...",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // O resto da lógica para quando há capítulos permanece igual.
        final chapters = snapshot.data!.docs;
        return Column(
          children: chapters.map((doc) {
            return ListTile(
              title: Text(doc.id),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChapterDetailPage(
                      courseId: courseId,
                      partId: partId,
                      chapterId: doc.id,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
