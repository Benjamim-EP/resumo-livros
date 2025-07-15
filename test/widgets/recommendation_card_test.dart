// test/widgets/recommendation_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/book_details_page.dart';
import 'package:septima_biblia/pages/library_page/recommendation_card.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import '../mocks/mock_navigator_observer.dart';

// Mocks
class MockStore extends Mock implements Store<AppState> {}

class MockAppState extends Mock implements AppState {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  // Dados mockados que usaremos nos testes
  final mockRecommendation = {
    'book_id': 'c-s-lewis-o-problema-da-dor',
    'titulo': 'O Problema da Dor',
    'autor': 'C. S. Lewis',
    'cover': 'https://exemplo.com/capa.jpg',
    'recommendation_reason':
        'Este livro é perfeito para entender o sofrimento.',
  };

  final mockRecommendationWithoutCover = {
    'book_id': 'livro-sem-capa',
    'titulo': 'Livro Sem Capa',
    'autor': 'Autor Teste',
    'cover': '',
    'recommendation_reason': 'Uma recomendação.',
  };

  late MockNavigatorObserver mockNavigatorObserver;
  late MockStore mockStore;

  setUpAll(() {
    registerFallbackValue(MaterialPageRoute(builder: (_) => const SizedBox()));
    registerFallbackValue(MockState());
  });

  setUp(() {
    mockNavigatorObserver = MockNavigatorObserver();
    mockStore = MockStore();
  });

  Widget buildTestableWidget(Widget child) {
    return StoreProvider<AppState>(
      store: mockStore,
      child: MaterialApp(
        home: Scaffold(body: child),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  group('RecommendationCard', () {
    setUp(() {
      final mockState = MockAppState();
      final mockBooksState = BooksState(bookDetails: {});
      when(() => mockState.booksState).thenReturn(mockBooksState);
      when(() => mockStore.state).thenReturn(mockState);
      when(() => mockStore.dispatch(any())).thenReturn(null);
      when(() => mockStore.onChange).thenAnswer((_) => const Stream.empty());
    });

    // Cenário 1
    testWidgets(
      'deve renderizar todos os elementos corretamente quando os dados estão completos',
      (WidgetTester tester) async {
        // Envolve o teste para mockar a imagem de rede
        await mockNetworkImagesFor(() => tester.pumpWidget(buildTestableWidget(
              RecommendationCard(recommendation: mockRecommendation),
            )));

        expect(find.text('O Problema da Dor'), findsOneWidget);
        expect(find.text('C. S. Lewis'), findsOneWidget);
        expect(find.text('“Este livro é perfeito para entender o sofrimento.”'),
            findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Ver Livro'), findsOneWidget);
      },
    );

    // Cenário 2 (não precisa de mock de imagem, pois não há imagem)
    testWidgets('não deve renderizar a imagem se a URL da capa estiver vazia',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        RecommendationCard(recommendation: mockRecommendationWithoutCover),
      ));
      expect(find.text('Livro Sem Capa'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    // Cenário 3
    testWidgets(
        'deve navegar para BookDetailsPage ao tocar no botão "Ver Livro"',
        (WidgetTester tester) async {
      // Envolve a renderização com o mock de imagem
      await mockNetworkImagesFor(() => tester.pumpWidget(buildTestableWidget(
            RecommendationCard(recommendation: mockRecommendation),
          )));

      // QUANDO: Simula o toque no botão
      await tester.tap(find.text('Ver Livro'));

      // ✅ CORREÇÃO: Usa pump() em vez de pumpAndSettle()
      // Avança um único frame, o que é suficiente para a chamada do Navigator.push ser processada.
      await tester.pump();

      // ENTÃO: A verificação continua a mesma
      final captured =
          verify(() => mockNavigatorObserver.didPush(captureAny(), any()))
              .captured;

      expect(captured.last, isA<MaterialPageRoute>());
      final pushedRoute = captured.last as MaterialPageRoute;

      expect(pushedRoute.builder(MockBuildContext()), isA<BookDetailsPage>());

      final bookDetailsPage =
          pushedRoute.builder(MockBuildContext()) as BookDetailsPage;
      expect(bookDetailsPage.bookId, 'c-s-lewis-o-problema-da-dor');
    });

    // Cenário 4
    testWidgets(
        'o botão "Ver Livro" deve estar desabilitado se o book_id for nulo ou vazio',
        (WidgetTester tester) async {
      final recommendationWithoutId =
          Map<String, dynamic>.from(mockRecommendation)..remove('book_id');
      await tester.pumpWidget(buildTestableWidget(
        RecommendationCard(recommendation: recommendationWithoutId),
      ));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}

// Classe de estado mockada
class MockState extends Mock implements AppState {}
