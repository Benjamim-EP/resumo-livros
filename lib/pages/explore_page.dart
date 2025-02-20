import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/loadingbooks.dart';
import 'package:resumo_dos_deuses_flutter/components/search_bar.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/explore_page/SermonsSection.dart';
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
      print("aba selecionada");
      print(_selectedTab);
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
            // 🔹 Carrega as recomendações semanais se ainda não foram carregadas
            if (store.state.booksState.weeklyRecommendations.isEmpty) {
              store.dispatch(LoadWeeklyRecommendationsAction());
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
                children: [
                  // 🔹 Seção de Indicação Semanal
                  StoreConnector<AppState, List<Map<String, dynamic>>>(
                    converter: (store) =>
                        store.state.booksState.weeklyRecommendations,
                    builder: (context, weeklyBooks) {
                      if (weeklyBooks.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              "📖 Indicação Semanal",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 250,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: weeklyBooks.length,
                              itemBuilder: (context, index) {
                                final book = weeklyBooks[
                                    index]; // 🔹 Obtendo book corretamente
                                final bookId = book[
                                    'id']; // 🔹 Obtendo bookId corretamente

                                return GestureDetector(
                                  onTap: () {
                                    // 🔹 Vai diretamente para a página do livro (CORRETO)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BookDetailsPage(bookId: bookId),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    color: const Color(0xFF1E1F1F),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: SizedBox(
                                      width: 150,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                            child: book['cover'] != null
                                                ? Image.network(
                                                    book['cover'],
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
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              book['bookName'] ??
                                                  'Título desconhecido',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            child: Text(
                                              book['autor'] ??
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
                          ),
                        ],
                      );
                    },
                  ),

// 🔹 Seção de Livros por Categoria
                  ...topicsByFeature.entries.map((entry) {
                    final feature = entry.key;

                    // Agrupa os tópicos por bookId
                    final groupedBooks = <String, List<Map<String, dynamic>>>{};
                    for (final topic in entry.value) {
                      final bookId = topic['bookId'];
                      if (bookId != null) {
                        groupedBooks.putIfAbsent(bookId, () => []).add(topic);
                      }
                    }

                    return ExpansionTile(
                      title: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      collapsedBackgroundColor: const Color(0xFF1A1B1D),
                      backgroundColor: const Color(0xFF232538),
                      children: [
                        SizedBox(
                          height: 250,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: groupedBooks.length,
                            itemBuilder: (context, index) {
                              final bookId = groupedBooks.keys.elementAt(
                                  index); // 🔹 Obtendo bookId corretamente
                              final topics = groupedBooks[
                                  bookId]!; // 🔹 Obtendo tópicos corretamente
                              final firstTopic = topics.first;

                              return GestureDetector(
                                onTapDown: (details) {
                                  final tapPosition = details.globalPosition;

                                  // 🔹 Verifica se o livro faz parte das recomendações semanais
                                  final isWeeklyRecommended = store
                                      .state.booksState.weeklyRecommendations
                                      .any((book) => book['id'] == bookId);

                                  if (isWeeklyRecommended) {
                                    // Abre a página do livro
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BookDetailsPage(bookId: bookId),
                                      ),
                                    );
                                  } else {
                                    // Exibe o menu suspenso com os tópicos do livro
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
                                      items: topics.map((topic) {
                                        final topicId =
                                            topic['id']?.toString() ??
                                                'unknown';
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
                                      color: const Color(0xFF232538),
                                      elevation: 8,
                                    ).then((value) {
                                      if (value != null && value != 'unknown') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TopicContentView(
                                                    topicId: value),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                },
                                child: Card(
                                  color: const Color(0xFF1E1F1F),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: SizedBox(
                                    width: 150,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
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
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
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
      case "Pregações":
        return const SermonsSection();

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

            // 🔹 Barra de pesquisa
            const SearchBar2(hintText: "Autor, Livro"),

            const SizedBox(height: 10),

            // 🔹 Exibição dos Selos do Usuário
            StoreConnector<AppState, int>(
              converter: (store) =>
                  store.state.userState.userDetails?['selos'] ?? 0,
              builder: (context, selos) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 24), // Ícone de moeda
                      const SizedBox(width: 6),
                      Text(
                        selos.toString(), // Número de selos
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 🔹 Itens da aba de Exploração (Livros, Autores, Pregações)
            ExploreItens(
              itens: const ["Livros", "Autores", "Pregações"],
              buttonType: 2,
              onTabSelected: _onTabSelected,
              selectedTab: _selectedTab, // Aba atualmente ativa
            ),

            const SizedBox(height: 10),

            // 🔹 Torna somente o conteúdo da aba rolável
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
