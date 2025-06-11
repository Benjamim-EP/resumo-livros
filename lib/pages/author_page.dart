import 'package:flutter/material.dart';
import 'package:septima_biblia/components/buttons/button_selection.dart';
import 'package:septima_biblia/components/author/author_cover_informations.dart';
import 'package:septima_biblia/components/author/author_description_data.dart';
import 'package:septima_biblia/components/loadingauthorspage.dart';
import 'package:septima_biblia/pages/book_details_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

class AuthorPage extends StatefulWidget {
  final String authorId;
  const AuthorPage({super.key, required this.authorId});

  @override
  _AuthorPageState createState() => _AuthorPageState();
}

class _AuthorPageState extends State<AuthorPage> {
  int _selectedIndex = 0;
  // @override
  // void dispose() {
  //   super.dispose();
  //   StoreProvider.of<AppState>(context).dispatch(ClearAuthorDetailsAction());
  // }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: // "Livros"
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.authorState.authorBooks,
          builder: (context, books) {
            if (books.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum livro encontrado para este autor.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookDetailsPage(bookId: book['bookId']),
                      ),
                    );
                  },
                  child: _buildBookCard(book),
                );
              },
            );
          },
        );
      case 1: // "Rotas"
        return const Center(
          child: Text(
            'Aba de Rotas',
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 18),
          ),
        );
      case 2: // "Reviews"
        return const Center(
          child: Text(
            'Aba de Reviews',
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 18),
          ),
        );
      case 3: // "Similares"
        return const Center(
          child: Text(
            'Aba de Similares',
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 18),
          ),
        );
      default:
        return Container();
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBookCard(Map<String, dynamic> bookDetails) {
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
                    bookDetails['titulo'] ?? 'Sem título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 8),
                  Text(
                    'Avaliação: ${bookDetails['rating_score']?.toString() ?? '0.0'}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
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
    return Scaffold(
      body: StoreConnector<AppState, Map<String, dynamic>?>(
        onInit: (store) {
          // Limpa os dados do autor e carrega os detalhes do autor atual
          final currentAuthorId = store.state.authorState.authorDetails?['id'];
          if (currentAuthorId != widget.authorId) {
            store.dispatch(ClearAuthorDetailsAction());
            store.dispatch(LoadAuthorDetailsAction(widget.authorId));
          }
        },
        converter: (store) => store.state.authorState.authorDetails,
        builder: (context, authorDetails) {
          // Verifica se os detalhes do autor estão carregados
          if (authorDetails == null || authorDetails.isEmpty) {
            return const AuthorPageLoadingPlaceholder();
          }

          // Renderiza a página do autor se os detalhes estiverem disponíveis
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthorCoverInformations(authorId: widget.authorId),
              const AuthorDescriptionData(),
              ButtonSelectionWidget(
                selectedIndex: _selectedIndex,
                onTabSelected: (index) => setState(() {
                  _selectedIndex = index;
                }),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildContent(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
