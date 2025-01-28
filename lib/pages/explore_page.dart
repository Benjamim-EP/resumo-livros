import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/loadingbooks.dart';
import 'package:resumo_dos_deuses_flutter/components/search_bar.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/rota_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import '../components/explore_itens.dart';
import '../components/authors_section.dart'; // Novo componente para autores
import 'package:flutter_redux/flutter_redux.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  String _selectedTab = "Livros"; // Aba selecionada inicialmente

  // Atualiza a aba selecionada
  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;

      if (tab == "Autores") {
        final store = StoreProvider.of<AppState>(context, listen: false);
        if ((store.state.authorState.authorDetails?.isEmpty ?? true)) {
          store.dispatch(LoadAuthorsAction());
        }
      }
    });
  }

  // Renderiza o conteúdo com base na aba selecionada
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case "Livros":
        return StoreConnector<AppState,
            Map<String, List<Map<String, dynamic>>>>(
          converter: (store) => store.state.userState.tribeTopicsByFeature,
          onInit: (store) {
            if (store.state.userState.tribeTopicsByFeature.isEmpty) {
              print('topicsByFeature vazio. Carregando do Firestore...');
              store.dispatch(LoadTopicsByFeatureAction());
            }
          },
          builder: (context, topicsByFeature) {
            if (topicsByFeature.isEmpty &&
                store.state.userState.tribeTopicsByFeature.length < 4) {
              return const LoadingBooksPlaceholder();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: topicsByFeature.entries.map((entry) {
                  final feature = entry.key;

                  // Agrupa os tópicos por bookId
                  final groupedBooks = <String, List<Map<String, dynamic>>>{};
                  for (final topic in entry.value) {
                    final bookId = topic['bookId'];
                    if (bookId != null) {
                      groupedBooks.putIfAbsent(bookId, () => []).add(topic);
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Feature Title
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Horizontal List of Cards
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: groupedBooks.length,
                          itemBuilder: (context, index) {
                            final bookId = groupedBooks.keys.elementAt(index);
                            final topics = groupedBooks[bookId]!;
                            final firstTopic = topics.first;

                            return GestureDetector(
                              onTapDown: (details) {
                                // Obtém a posição do clique
                                final tapPosition = details.globalPosition;

                                // Mostra o menu suspenso ao clicar no cartão
                                showMenu(
                                  context: context,
                                  position: RelativeRect.fromLTRB(
                                    tapPosition.dx,
                                    tapPosition.dy,
                                    MediaQuery.of(context).size.width -
                                        tapPosition.dx,
                                    MediaQuery.of(context).size.height -
                                        tapPosition.dy,
                                  ),
                                  items: [
                                    // Opção: Ir para página do livro
                                    PopupMenuItem<String>(
                                      value: 'book',
                                      child: const Text(
                                        'Ir para Livro',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    // Opção: Ir para tópicos
                                    ...topics.map((topic) {
                                      final topicId =
                                          topic['id']?.toString() ?? 'unknown';
                                      return PopupMenuItem<String>(
                                        value: topicId,
                                        child: Text(
                                          topic['titulo'] ??
                                              'Título desconhecido',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  color: const Color(
                                      0xFF232538), // Fundo do menu suspenso
                                  elevation:
                                      8, // Efeito de sombra para destacar
                                ).then((value) {
                                  // Lógica ao selecionar uma opção
                                  if (value == 'book') {
                                    // Ir para a página do livro
                                    if (bookId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BookDetailsPage(bookId: bookId),
                                        ),
                                      );
                                    }
                                  } else if (value != null &&
                                      value != 'unknown') {
                                    // Ir para um tópico específico
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TopicContentView(topicId: value),
                                      ),
                                    );
                                  }
                                });
                              },
                              child: Card(
                                color: const Color(0xFF1E1F1F),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 150,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Book Cover
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),
                                        child: firstTopic['cover'] != null
                                            ? Image.network(
                                                firstTopic['cover'],
                                                width: double.infinity,
                                                height: 150,
                                                fit: BoxFit.fitHeight,
                                              )
                                            : Container(
                                                height: 150,
                                                color: Colors.grey,
                                                child: const Icon(
                                                  Icons.image,
                                                  size: 48,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                      // Book Name
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          firstTopic['bookName'] ??
                                              'Título desconhecido',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      // Author Name
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Text(
                                          firstTopic['autor'] ??
                                              'Autor desconhecido',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
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
                      )
                    ],
                  );
                }).toList(),
              ),
            );
          },
        );

      case "Autores":
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) {
            return store.state.authorState.authorsList;
          },
          onInit: (store) {
            if (store.state.authorState.authorsList.isEmpty) {
              store.dispatch(LoadAuthorsAction());
            }
          },
          builder: (context, authors) {
            if (authors.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum autor encontrado.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }
            return AuthorsSection(authors: authors);
          },
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const SearchBar2(hintText: "Autor, Livro"),
            const SizedBox(height: 40),
            ExploreItens(
              itens: const ["Livros", "Autores", "Rota"],
              buttonType: 2,
              onTabSelected: _onTabSelected,
              selectedTab: _selectedTab, // Aba atualmente ativa
            ),
            const SizedBox(height: 10),
            // Torna somente o conteúdo da aba rolável
            Expanded(
              child: SingleChildScrollView(
                child: _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
