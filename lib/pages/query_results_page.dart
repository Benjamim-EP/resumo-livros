import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class QueryResultsPage extends StatelessWidget {
  const QueryResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados da Busca')),
      body: StoreConnector<AppState, List<Map<String, dynamic>>>(
        converter: (store) => store.state.userState.searchResults,
        builder: (context, searchResults) {
          if (searchResults.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum resultado encontrado.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final topic = searchResults[index];

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagem de capa
                    if (topic['cover'].isNotEmpty)
                      Image.network(
                        topic['cover'],
                        height: 100,
                        width: 70,
                        fit: BoxFit.cover,
                      ),
                    const SizedBox(width: 10),
                    // Informações do tópico
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic['bookName'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Capítulo: ${topic['chapterName']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            topic['conteudo'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
