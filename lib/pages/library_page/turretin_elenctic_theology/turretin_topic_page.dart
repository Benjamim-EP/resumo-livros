// lib/pages/library_page/turretin_elenctic_theology/turretin_topic_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/turretin_theology_model.dart';

class TurretinTopicPage extends StatelessWidget {
  final ElencticTopic topic;

  const TurretinTopicPage({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.topicTitle, overflow: TextOverflow.ellipsis),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: topic.questions.length,
        itemBuilder: (context, index) {
          final question = topic.questions[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              key: PageStorageKey(question.questionTitle),
              title: Text(
                question.questionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              subtitle: question.questionStatement.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        question.questionStatement,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : null,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Divider(height: 16),
                ...question.content.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
