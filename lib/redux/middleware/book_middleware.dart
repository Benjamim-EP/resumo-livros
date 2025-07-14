// lib/redux/middleware/book_middleware.dart

import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/book_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

// ✅ Esta é a função que o seu store.dart precisa
List<Middleware<AppState>> createBookMiddleware() {
  final bookService = BookService();

  // O único middleware que precisamos aqui é o que carrega os detalhes de um livro.
  final loadBookDetails = _createLoadBookDetailsMiddleware(bookService);

  return [
    TypedMiddleware<AppState, LoadBookDetailsAction>(loadBookDetails),
    // Outros middlewares relacionados a livros poderiam ser adicionados aqui no futuro.
  ];
}

// Função privada que define a lógica do middleware.
void Function(Store<AppState>, LoadBookDetailsAction, NextDispatcher)
    _createLoadBookDetailsMiddleware(BookService bookService) {
  return (store, action, next) async {
    next(
        action); // Passa a ação para os reducers, caso queiram ativar um estado de loading

    try {
      print(
          "BookMiddleware: Carregando detalhes para o livro ID: ${action.bookId}");

      final bookDetails = await bookService.fetchBookDetails(action.bookId);

      if (bookDetails != null) {
        // Se os detalhes foram encontrados, despacha a ação de sucesso
        store.dispatch(BookDetailsLoadedAction(action.bookId, bookDetails));
        print(
            "BookMiddleware: Detalhes para ${action.bookId} carregados com sucesso.");
      } else {
        // Se o livro não foi encontrado no Firestore
        print("BookMiddleware: Livro com ID ${action.bookId} não encontrado.");
        // Opcional: Despachar uma ação de falha para a UI mostrar uma mensagem
        // store.dispatch(BookDetailsFailedAction("Livro não encontrado."));
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          CustomNotificationService.showError(context, 'Livro não encontrado.');
        }
      }
    } catch (e) {
      // Em caso de erro de rede ou outro problema
      print(
          "BookMiddleware: Erro ao carregar detalhes do livro ${action.bookId}: $e");
      // store.dispatch(BookDetailsFailedAction(e.toString()));
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        CustomNotificationService.showError(
            context, 'Falha ao carregar detalhes do livro.');
      }
    }
  };
}
