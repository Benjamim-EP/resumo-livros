import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/stats/stat_item.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  void initState() {
    super.initState();
    final store = StoreProvider.of<AppState>(context, listen: false);
    store.dispatch(LoadUserStatsAction());
    store.dispatch(LoadUserCollectionsAction());
    store.dispatch(LoadBooksInProgressAction());
  }

  String _selectedTab = 'Lendo';

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'Lendo':
        return StoreConnector<AppState, Map<String, dynamic>>(
          converter: (store) => {
            'booksInProgress': store.state.userState.booksInProgress,
            'booksInProgressDetails':
                store.state.userState.booksInProgressDetails,
          },
          builder: (context, data) {
            final booksInProgress =
                data['booksInProgress'] as List<Map<String, dynamic>>;
            final booksInProgressDetails =
                data['booksInProgressDetails'] as List<Map<String, dynamic>>;

            if (booksInProgress.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum livro em leitura.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            // Despacha LoadBooksDetailsAction uma única vez
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (booksInProgressDetails.isEmpty) {
                StoreProvider.of<AppState>(context)
                    .dispatch(LoadBooksDetailsAction());
              }
            });

            // Exibe os detalhes, caso estejam disponíveis
            final booksToDisplay = booksInProgressDetails.isNotEmpty
                ? booksInProgressDetails
                : booksInProgress;

            return ListView.builder(
              itemCount: booksToDisplay.length,
              itemBuilder: (context, index) {
                final book = booksToDisplay[index];

                return GestureDetector(
                  onTap: () {
                    print('Abrir detalhes do livro ${book['id']}');
                    // Exemplo: Abrir uma página de detalhes
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookDetailsPage(bookId: book['id']),
                      ),
                    );
                  },
                  child: _buildBookCard(book),
                );
              },
            );
          },
        );
      case 'Salvos':
        return StoreConnector<AppState,
            Map<String, List<Map<String, dynamic>>>>(
          converter: (store) => store.state.userState.savedTopicsContent,
          onInit: (store) {
            if (store.state.userState.savedTopicsContent.isEmpty) {
              store.dispatch(LoadTopicsContentUserSavesAction());
            }
          },
          builder: (context, savedTopicsContent) {
            if (savedTopicsContent.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return ListView(
              children: savedTopicsContent.entries.map((entry) {
                final collectionName = entry.key;
                final topics = entry.value;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4.0,
                  color: const Color(0xFF313333),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          collectionName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Color.fromARGB(255, 172, 76, 71)),
                          onPressed: () {
                            // Remove toda a coleção ao clicar no ícone
                            StoreProvider.of<AppState>(context).dispatch(
                                DeleteTopicCollectionAction(collectionName));

                            // Recarregar o conteúdo após a exclusão
                            StoreProvider.of<AppState>(context).dispatch(
                              LoadTopicsContentUserSavesAction(),
                            );
                          },
                        ),
                      ],
                    ),
                    children: topics.map((topic) {
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                topic['titulo'] ?? 'Sem título',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Color.fromARGB(255, 172, 76, 71)),
                              onPressed: () {
                                // Remove um único item ao clicar no ícone
                                StoreProvider.of<AppState>(context).dispatch(
                                  DeleteSingleTopicFromCollectionAction(
                                    collectionName,
                                    topic['id'],
                                  ),
                                );
                                // Recarregar o conteúdo após a exclusão
                                StoreProvider.of<AppState>(context).dispatch(
                                  LoadTopicsContentUserSavesAction(),
                                );
                              },
                            ),
                          ],
                        ),
                        subtitle: Text(
                          topic['bookName'] ?? 'Sem nome do livro',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        leading: topic['cover'] != null
                            ? Image.network(
                                topic['cover'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.book, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicContentView(
                                topicId: topic['id'],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          },
        );

      default:
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.userRoutes,
          onInit: (store) {
            if (store.state.userState.userRoutes.isEmpty) {
              store.dispatch(LoadUserRoutesAction());
            }
          },
          builder: (context, userRoutes) {
            if (userRoutes.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return ListView.builder(
              itemCount: userRoutes.length,
              itemBuilder: (context, index) {
                final route = userRoutes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4.0,
                  color: const Color(0xFF313333),
                  child: ExpansionTile(
                    title: Text(
                      route['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    children: (route['topics'] as List<dynamic>).map((topic) {
                      return ListTile(
                        title: Text(
                          topic['titulo'] ?? 'Título Desconhecido',
                          style: const TextStyle(color: Colors.white),
                        ),
                        leading: topic['cover'] != null
                            ? Image.network(
                                topic['cover'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.route, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicContentView(
                                topicId: topic[
                                    'id'], // Certifique-se de que 'id' existe
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
    }
  }

  Widget _buildBookCard(Map<String, dynamic> bookDetails) {
    final progress = (bookDetails['progress'] ?? 0).toDouble() / 100;

    return Card(
      color: const Color(0xFF313333), // Cor do padrão da aplicação
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem de capa
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                bookDetails['cover'] ?? '',
                width: 80,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.book, size: 80, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Informações do livro
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookDetails['title'] ?? 'Sem título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookDetails['author'] != null
                        ? 'Autor: ${bookDetails['author']}'
                        : 'Autor desconhecido',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Text(
                  //   'Progresso: ${bookDetails['progress']?.toString() ?? '0'}%',
                  //   style: const TextStyle(
                  //     color: Colors.white54,
                  //     fontSize: 12,
                  //   ),
                  // ),
                  // const SizedBox(height: 8),
                  // Barra de progresso
                  SizedBox(
                    width:
                        200, // Defina a largura desejada para a barra de progresso
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(15),
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50), // Cor verde da barra de progresso
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>>(
      converter: (store) => {
        'userDetails': store.state.userState.userDetails ?? {},
        'booksInProgress': store.state.userState.booksInProgress.length,
      },
      builder: (context, data) {
        final userDetails = data['userDetails'] as Map<String, dynamic>;
        final livros = data['booksInProgress']?.toString() ?? '0';
        final topicos = userDetails['Tópicos']?.toString() ?? '0';
        // print("debug");
        // print(data);
        return Scaffold(
          backgroundColor: const Color(0xFF272828),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfilePicture(),
                    const SizedBox(height: 16),
                    UserInfo(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: StatsContainer(
                            livros: livros,
                            topicos: topicos,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LogoutButton(), // Botão ao lado do StatsContainer
                      ],
                    ),
                    const SizedBox(height: 16),
                    Tabs(
                      onTabSelected: _onTabSelected,
                      selectedTab: _selectedTab,
                    ),
                    const Divider(color: Color(0xFFCBC4C4)),
                  ],
                ),
              ),
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Botão de Logout
class LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 180, 115, 110), // Cor do botão
        borderRadius:
            BorderRadius.circular(12), // Tornar o botão mais arredondado
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.logout,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () {
          Navigator.of(context).pushReplacementNamed('/login');
        },
        tooltip: 'Sair',
      ),
    );
  }
}
