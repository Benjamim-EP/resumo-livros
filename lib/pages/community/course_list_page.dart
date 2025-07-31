// lib/pages/community/course_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/pages/community/course_detail_page.dart';
import 'package:septima_biblia/pages/community/course_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CourseListPage extends StatelessWidget {
  const CourseListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cursos')
            .orderBy('titulo')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar os cursos."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("Nenhum curso disponível no momento."));
          }

          final courses = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              // <<< ATUALIZADO: Proporção ajustada para o novo design mais alto >>>
              childAspectRatio: 0.45,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final courseDoc = courses[index];
              final data = courseDoc.data() as Map<String, dynamic>;

              // <<< ATUALIZADO: Extrai os novos campos do Firestore >>>
              final title = data['titulo'] ?? 'Curso Sem Título';
              final coverUrl = data['capa'] as String? ?? '';
              final intro = data['intro'] as String? ?? 'Sem descrição.';
              final qntReferencias = data['qntReferencias'] as String? ?? 'N/A';

              // <<< ATUALIZADO: Passa os novos dados para o CourseCard >>>
              return CourseCard(
                title: title,
                coverUrl: coverUrl,
                intro: intro,
                qntReferencias: qntReferencias,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailPage(
                        courseId: courseDoc.id,
                        courseTitle: title,
                      ),
                    ),
                  );
                },
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                  .scaleXY(begin: 0.9);
            },
          );
        },
      ),
    );
  }
}
