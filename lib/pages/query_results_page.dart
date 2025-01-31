import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class QueryResultsPage extends StatelessWidget {
  const QueryResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados da Busca')),
      body: StoreConnector<AppState, List<Map<String, dynamic>>?>(
        converter: (store) => store.state.userState.searchResults,
        builder: (context, searchResults) {
          if (searchResults == null) {
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const ShimmerLoadingCard(),
            );
          }

          if (searchResults.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum resultado encontrado.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final topic = searchResults[index];

              // 🔥 Limita o conteúdo a 60 caracteres
              String truncatedContent = topic['conteudo'];
              if (truncatedContent.length > 60) {
                truncatedContent = '${truncatedContent.substring(0, 60)}...';
              }

              return Card(
                color: Colors.grey[900], // 🔥 Fundo mais escuro para contraste
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📌 Imagem de capa com bordas arredondadas
                      if (topic['cover'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            topic['cover'],
                            height: 100,
                            width: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),

                      // 📌 Informações do tópico
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic['bookName'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // 🔥 Texto visível
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Capítulo: ${topic['chapterName']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70, // 🔥 Melhor visibilidade
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 📌 Renderiza o conteúdo truncado com Markdown
                            Container(
                              constraints: const BoxConstraints(maxHeight: 100),
                              child: MarkdownBody(
                                data: truncatedContent,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70, // 🔥 Melhor contraste
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 🔥 Placeholder shimmer para carregar os dados
class ShimmerLoadingCard extends StatelessWidget {
  const ShimmerLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[700]!,
        highlightColor: Colors.grey[500]!,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 18, width: 150, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 100, color: Colors.white),
                    const SizedBox(height: 12),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
