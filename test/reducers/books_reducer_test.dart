// test/reducers/books_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';

void main() {
  // O group() organiza testes relacionados.
  group('BooksReducer', () {
    // Teste 1: Estado inicial
    test('deve retornar o estado inicial se o estado passado for nulo', () {
      final initialState = BooksState();
      // Chama o reducer com um estado nulo (não acontece na prática, mas testa o default)
      // e uma ação que ele não conhece.
      final newState = booksReducer(initialState, "Ação Desconhecida");

      // Verifica se o estado retornado é o mesmo que o inicial
      expect(newState.isLoading, false);
      expect(newState.bookDetails, isEmpty);
      expect(newState.weeklyRecommendations, isEmpty);
    });

    // Teste 2: Ação BookDetailsLoadedAction
    test(
        'deve adicionar detalhes de um novo livro ao estado ao receber BookDetailsLoadedAction',
        () {
      // DADO: um estado inicial vazio
      final initialState = BooksState();

      // E os dados de um novo livro
      final bookId = 'cs-lewis-cristianismo';
      final bookData = {
        'titulo': 'Cristianismo Puro e Simples',
        'autor': 'C. S. Lewis'
      };
      final action = BookDetailsLoadedAction(bookId, bookData);

      // QUANDO: o reducer é chamado com a ação
      final newState = booksReducer(initialState, action);

      // ENTÃO: o novo estado deve conter os detalhes do livro
      expect(newState.bookDetails.length, 1);
      expect(newState.bookDetails[bookId], isNotNull);
      expect(newState.bookDetails[bookId]?['titulo'],
          'Cristianismo Puro e Simples');
    });

    // Teste 3: Preservar detalhes existentes
    test('deve adicionar detalhes de um segundo livro sem remover o primeiro',
        () {
      // DADO: um estado que já contém um livro
      final initialState = BooksState(bookDetails: {
        'cs-lewis-cristianismo': {'titulo': 'Cristianismo Puro e Simples'}
      });

      // E os dados de um segundo livro
      final newBookId = 'cs-lewis-o-problema-da-dor';
      final newBookData = {'titulo': 'O Problema da Dor'};
      final action = BookDetailsLoadedAction(newBookId, newBookData);

      // QUANDO: o reducer é chamado com a nova ação
      final newState = booksReducer(initialState, action);

      // ENTÃO: o novo estado deve conter AMBOS os livros
      expect(newState.bookDetails.length, 2);
      expect(newState.bookDetails['cs-lewis-cristianismo'],
          isNotNull); // Verifica se o antigo ainda existe
      expect(newState.bookDetails[newBookId]?['titulo'],
          'O Problema da Dor'); // Verifica se o novo foi adicionado
    });

    // Teste 4: Atualizar detalhes de um livro existente
    test(
        'deve atualizar os detalhes de um livro se o mesmo ID for recebido novamente',
        () {
      // DADO: um estado que já contém um livro com dados antigos
      final bookId = 'cs-lewis-cristianismo';
      final initialState = BooksState(bookDetails: {
        bookId: {'titulo': 'Cristianismo V1', 'versao': 1}
      });

      // E novos dados para o MESMO livro
      final updatedBookData = {'titulo': 'Cristianismo V2', 'versao': 2};
      final action = BookDetailsLoadedAction(bookId, updatedBookData);

      // QUANDO: o reducer é chamado
      final newState = booksReducer(initialState, action);

      // ENTÃO: os detalhes devem ser os novos
      expect(newState.bookDetails.length, 1);
      expect(newState.bookDetails[bookId]?['titulo'], 'Cristianismo V2');
      expect(newState.bookDetails[bookId]?['versao'], 2);
    });
  });
}
