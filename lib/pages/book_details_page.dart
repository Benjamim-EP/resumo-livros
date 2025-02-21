import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resumo_dos_deuses_flutter/pages/chapter_view_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';

class BookDetailsPage extends StatelessWidget {
  final String bookId;

  const BookDetailsPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    if (bookId == null) {
      // Verifica se bookId é nulo
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Livro'),
        backgroundColor: const Color(0xFF313333), // Cor correspondente ao fundo
      ),
      body: StoreConnector<AppState, Map<String, dynamic>>(
        onInit: (store) {
          store.dispatch(LoadBookDetailsAction(bookId));
          if (store.state.userState.booksInProgressDetails.isEmpty) {
            store.dispatch(LoadBooksInProgressAction());
          }
        },
        converter: (store) => {
          'bookDetails': store.state.booksState.bookDetails,
          'booksProgress': store.state.userState.booksInProgressDetails,
        },
        builder: (context, data) {
          final bookDetails = data['bookDetails'] as Map<String, dynamic>?;
          final booksProgress =
              data['booksProgress'] as List<Map<String, dynamic>>?;
          Map<String, dynamic> bookProgress = {};
          try {
            bookProgress = booksProgress!.firstWhere(
              (progress) => progress['id'].toString() == bookId,
              orElse: () => {},
            );
          } catch (e) {
            print("⚠ Erro ao carregar progresso do livro: $e");
          }

          if (bookDetails == null ||
              !bookDetails.containsKey(bookId) ||
              bookDetails[bookId] == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFCDE7BE)), // Cor verde
              ),
            );
          }

          final book = bookDetails[bookId]!;
          final chapters = book['chapters'] as List<dynamic>? ?? [];

          final chaptersIniciados =
              (bookProgress?['chaptersIniciados'] as List<dynamic>?) ?? [];
          print(
              "📖 Capitulos iniciados carregados: $chaptersIniciados"); // Debug
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem de Capa
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: book['cover'] != null
                        ? Image.network(
                            book['cover'],
                            height: 250,
                            width: 150,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 250,
                            width: 150,
                            color: Colors.grey,
                            child: const Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Título do Livro
                Center(
                  child: Text(
                    book['titulo'] ?? 'Nome do Livro',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                // Autor do Livro
                Center(
                  child: GestureDetector(
                    onTap: () {
                      final authorId = book['authorId'];
                      if (authorId != null && authorId is String) {
                        // Navegar para a página do autor com o ID como argumento
                        Navigator.pushNamed(
                          context,
                          '/authorPage',
                          arguments: authorId,
                        );
                      } else {
                        // Exibir uma mensagem caso o autor não tenha um ID válido
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Autor não encontrado.')),
                        );
                      }
                    },
                    child: Text(
                      book['authorId'] ?? 'Autor desconhecido',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFCDE7BE), // Indica que é clicável
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Número de Capítulos
                Center(
                  child: Text(
                    '${chapters.length} Capítulos',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Lista de Capítulos
                ListView.builder(
                  key: ValueKey(chapters.length), // Evita reconstrução completa
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final chapterId = chapter['capituloId'];
                    print("chapterId:$chapterId");
                    final isChapterRead =
                        chaptersIniciados.contains(chapterId.toString());

                    return ListTile(
                      key: ValueKey(
                          chapterId), // Evita recriação desnecessária do widget
                      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                      leading: Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        chapter['titulo'] ?? 'Capítulo desconhecido',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      trailing: Icon(
                        isChapterRead
                            ? Icons.menu_book
                            : Icons.book, // Ícone de livro aberto ou fechado
                        color: Colors.white,
                        size: 24,
                      ),
                      onTap: () {
                        final store =
                            StoreProvider.of<AppState>(context, listen: false);
                        store.dispatch(StartBookProgressAction(bookId));

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChapterViewPage(
                              chapters: chapters,
                              index: index,
                              bookId: bookId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
