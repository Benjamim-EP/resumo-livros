import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

class TopicCard extends StatefulWidget {
  final String topicId;
  final String bookId;
  final String chapterId; // Novo parâmetro
  final Set<String> readTopics;
  final Function(String) onShowSimilar;
  final Function(String) onSaveTopic;

  const TopicCard({
    super.key,
    required this.topicId,
    required this.bookId,
    required this.chapterId, // Novo parâmetro
    required this.readTopics,
    required this.onShowSimilar,
    required this.onSaveTopic,
  });

  @override
  _TopicCardState createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>>(
      onInit: (store) {
        store.dispatch(LoadTopicContentAction(widget.topicId));
        store.dispatch(CheckBookProgressAction(widget.bookId));
      },
      converter: (store) => {
        'content': store.state.topicState.topicsContent[widget.topicId],
        'titulo': store.state.topicState.topicsTitles[widget.topicId],
        'bookProgress':
            store.state.booksState.booksProgress[widget.bookId] ?? [],
      },
      builder: (context, topicData) {
        final content = topicData['content'];
        final title = topicData['titulo'] ?? 'Sem Título';
        final bookProgress =
            topicData['bookProgress'] as Map<String, dynamic>? ?? {};
        final readTopics = List<String>.from(bookProgress['readTopics'] ?? []);

        if (content == null) {
          return const Center(child: CircularProgressIndicator());
        }
        print("debug topicId");
        print(widget.topicId);
        final isRead = readTopics.contains(widget.topicId);

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          color: const Color(0xFF313333),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
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
                    Flexible(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => widget.onShowSimilar(widget.topicId),
                          child: const Text(
                            'Similares',
                            style: TextStyle(
                              color: Color.fromARGB(
                                  255, 129, 194, 91), // Verde da aplicação
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: isRead ? null : () => _markTopicAsRead(),
                          icon: const Icon(Icons.check),
                          label: Text(isRead ? 'Lido' : 'Marcar como lido'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => widget.onSaveTopic(widget.topicId),
                  icon: const Icon(
                    Icons.save,
                    color: Colors.white,
                  ),
                  tooltip: 'Salvar',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _markTopicAsRead() {
    if (widget.readTopics.contains(widget.topicId)) return;

    StoreProvider.of<AppState>(context).dispatch(
      MarkTopicAsReadAction(widget.bookId, widget.topicId, widget.chapterId),
    );

    setState(() {}); // Apenas força a reconstrução do widget
  }
}
