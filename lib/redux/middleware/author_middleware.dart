import 'package:redux/redux.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/author_service.dart';
import '../../services/book_service.dart'; // Para buscar livros do autor

List<Middleware<AppState>> createAuthorMiddleware() {
  final authorService = AuthorService();
  final bookService = BookService();

  return [
    TypedMiddleware<AppState, LoadAuthorsAction>(_loadAuthors(authorService)),
    TypedMiddleware<AppState, LoadAuthorDetailsAction>(
        _loadAuthorDetails(authorService, bookService)),
    TypedMiddleware<AppState, ClearAuthorDetailsAction>(
        _clearAuthorDetails), // Middleware para limpar
  ];
}

void Function(Store<AppState>, LoadAuthorsAction, NextDispatcher) _loadAuthors(
    AuthorService authorService) {
  return (Store<AppState> store, LoadAuthorsAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final authors = await authorService.fetchAllAuthors();
      store.dispatch(AuthorsLoadedAction(authors));
    } catch (e) {
      print('Erro ao carregar autores: $e');
      // Opcional: Despachar ação de erro
    }
  };
}

void Function(Store<AppState>, LoadAuthorDetailsAction, NextDispatcher)
    _loadAuthorDetails(AuthorService authorService, BookService bookService) {
  return (Store<AppState> store, LoadAuthorDetailsAction action,
      NextDispatcher next) async {
    next(action);
    // Opcional: Verificar se já está carregando ou se já carregou este autor para evitar chamadas duplicadas
    // if (store.state.authorState.isLoading || store.state.authorState.authorDetails?['id'] == action.authorId) {
    //   return;
    // }
    // store.dispatch(SetAuthorLoadingAction(true)); // Exemplo de ação de loading

    try {
      final authorDetails =
          await authorService.fetchAuthorDetails(action.authorId);
      if (authorDetails != null) {
        store.dispatch(
            AuthorDetailsLoadedAction(action.authorId, authorDetails));

        // Buscar os livros associados
        final List<String> bookIds =
            List<String>.from(authorDetails['livros'] ?? []);
        final List<Map<String, dynamic>> books = [];
        for (final bookId in bookIds) {
          final bookDetailsMap = await bookService.fetchBookDetails(
              bookId); // Usar fetchBookDetails que retorna Map
          if (bookDetailsMap != null) {
            // Adiciona apenas os campos necessários ou o mapa inteiro
            books.add({
              'bookId': bookId, // Certifique-se que o ID está incluído
              'titulo': bookDetailsMap['titulo'] ?? 'Sem título',
              'cover': bookDetailsMap['cover'] ?? '',
              'rating_score': bookDetailsMap['nota']?['score'] ??
                  0.0, // Exemplo, ajuste conforme seus dados
              // Adicione outros campos se necessário
            });
          }
        }
        store.dispatch(AuthorBooksLoadedAction(action.authorId, books));
      } else {
        print(
            'Middleware: Nenhum detalhe encontrado para o autor ${action.authorId}');
        // Opcional: Despachar ação de erro ou estado vazio
      }
    } catch (e) {
      print('Middleware: Erro ao carregar detalhes do autor: $e');
      // Opcional: Despachar ação de erro
    } finally {
      // store.dispatch(SetAuthorLoadingAction(false)); // Finaliza o loading
    }
  };
}

// Middleware simples para lidar com a limpeza do estado do autor
void Function(Store<AppState>, ClearAuthorDetailsAction, NextDispatcher)
    _clearAuthorDetails = (Store<AppState> store,
        ClearAuthorDetailsAction action, NextDispatcher next) {
  // A lógica de limpeza real acontece no reducer. O middleware apenas passa a ação adiante.
  next(action);
  print("Middleware: Ação ClearAuthorDetailsAction processada.");
};
