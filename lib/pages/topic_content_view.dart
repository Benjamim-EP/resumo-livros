import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/chapter_view_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/save_topic_dialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/similar_topic_view.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class TopicContentView extends StatelessWidget {
  final String topicId;

  const TopicContentView({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conteúdo do Tópico'),
      ),
      body: StoreConnector<AppState, Map<String, String?>>(
        onInit: (store) {
          if (!store.state.topicState.topicsContent.containsKey(topicId)) {
            store.dispatch(LoadTopicContentAction(topicId));
          }
        },
        converter: (store) => {
          'content': store.state.topicState.topicsContent[topicId],
          'titulo': store.state.topicState.topicsTitles[topicId],
        },
        builder: (context, topicData) {
          final content = topicData['content'];
          final title = topicData['titulo'] ?? 'Sem Título';

          if (content == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: '## **$title**',
                      styleSheet: MarkdownStyleSheet(
                        h2: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActionButtons(context, topicId),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => _showSaveDialog(context, topicId),
                  icon: const Icon(
                    Icons.save,
                    color: Colors.white,
                  ),
                  tooltip: 'Salvar',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String topicId) {
    return StoreConnector<AppState, Map<String, dynamic>?>(
      converter: (store) => store.state.topicState.topicsMetadata[topicId],
      builder: (context, metadata) {
        if (metadata == null) return const SizedBox.shrink();

        final bookId = metadata['bookId'];
        final chapterId = metadata['capituloId'];
        final chapterIndex = metadata['chapterIndex'];

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () => _showSimilarTopics(context, topicId),
              icon: const Icon(Icons.compare,
                  color: Color(0xFF81C25B)), // Verde da aplicação
              tooltip: 'Ver Tópicos Similares',
            ),
            if (bookId != null)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailsPage(bookId: bookId),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book, color: Colors.white),
                tooltip: 'Ir para Livro',
              ),
          ],
        );
      },
    );
  }

  void _showSimilarTopics(BuildContext context, String topicId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF313333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SimilarTopicsView(topicId: topicId),
    );
  }

  void _showSaveDialog(BuildContext context, String topicId) {
    showDialog(
      context: context,
      builder: (_) => SaveTopicDialog(topicId: topicId),
    );
  }
}
