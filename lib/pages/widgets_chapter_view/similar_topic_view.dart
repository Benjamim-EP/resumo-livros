import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

class SimilarTopicsView extends StatelessWidget {
  final String topicId;

  const SimilarTopicsView({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, // Começa ocupando 80% da tela
      minChildSize: 0.3, // Altura mínima de 30%
      maxChildSize: 0.8, // Altura máxima de 80%
      expand: false,
      builder: (context, scrollController) {
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          onInit: (store) {
            if (!store.state.topicState.similarTopics.containsKey(topicId)) {
              store.dispatch(LoadSimilarTopicsAction(topicId));
            }
          },
          converter: (store) =>
              store.state.topicState.similarTopics[topicId] ?? [],
          builder: (context, similarTopics) {
            if (similarTopics.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFCDE7BE),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tópicos Similares',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE9E8E8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      controller: scrollController,
                      itemCount: similarTopics.length,
                      itemBuilder: (context, index) {
                        final similarTopic = similarTopics[index];
                        final similarTopicId = similarTopic['similar_topic_id'];
                        final similarity = similarTopic['similarity'];
                        final bookTitle =
                            similarTopic['bookTitle'] ?? 'Sem título';
                        final chapterTitle =
                            similarTopic['titulo'] ?? 'Sem título';
                        final cover = similarTopic['cover'];
                        final bookId = similarTopic['bookId'];

                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12.0),
                          child: Card(
                            color: const Color(0xFF626666),
                            elevation: 4.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Capa do livro (adicionado clique para BookDetailsPage)
                                  if (cover != null)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BookDetailsPage(
                                              bookId: bookId,
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          cover,
                                          width: double.infinity,
                                          height: 250,
                                          fit: BoxFit.fill,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                            Icons.broken_image,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BookDetailsPage(
                                              bookId: bookId,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Icon(
                                        Icons.book,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Título do livro
                                  Text(
                                    'Livro: $bookTitle',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFE9E8E8),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Título do capítulo
                                  Text(
                                    'Tópico: $chapterTitle',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFE9E8E8),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Similaridade
                                  Text(
                                    'Similaridade: $similarity',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Botão de ver mais
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TopicContentView(
                                            topicId: similarTopicId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Ir para o Tópico',
                                      style: TextStyle(
                                        color: Color(0xFFCDE7BE),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
