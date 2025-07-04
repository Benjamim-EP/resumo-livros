// lib/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/gods_word_to_women_model.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_lesson_page.dart';

class GodsWordToWomenIndexPage extends StatefulWidget {
  const GodsWordToWomenIndexPage({super.key});

  @override
  State<GodsWordToWomenIndexPage> createState() =>
      _GodsWordToWomenIndexPageState();
}

class _GodsWordToWomenIndexPageState extends State<GodsWordToWomenIndexPage> {
  Future<List<GodsWordToWomenLesson>>? _lessonsFuture;

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadData();
  }

  Future<List<GodsWordToWomenLesson>> _loadData() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/library_books/gods_word_to_women.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => GodsWordToWomenLesson.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao carregar 'A Palavra de Deus às Mulheres': $e");
      throw Exception('Falha ao carregar dados do livro');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("A Palavra de Deus às Mulheres"),
      ),
      body: FutureBuilder<List<GodsWordToWomenLesson>>(
        future: _lessonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhuma lição encontrada."));
          }

          final lessons = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 15.0),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary),
                    ),
                  ),
                  title: Text(
                    lesson.lessonTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(lesson.lessonNumber,
                      style: theme.textTheme.bodySmall),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GodsWordToWomenLessonPage(lesson: lesson),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
