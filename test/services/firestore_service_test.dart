// test/services/firestore_service_test.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:septima_biblia/services/firestore_service.dart';

// --- Mocks ---
// Criação das classes "dublês" para cada tipo de objeto do Firestore.
// Isso nos permite simular a API do Firestore sem fazer chamadas de rede reais.
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  // Declaração das variáveis de mock e do serviço que serão usadas nos testes.
  late MockFirebaseFirestore mockFirestore;
  late FirestoreService firestoreService;

  // --- Mocks para cada nível da hierarquia ---
  // Livros
  late MockCollectionReference mockLivrosCollection;
  late MockDocumentReference mockBookDocument;
  late MockDocumentSnapshot mockBookSnapshot;

  // Destaques
  late MockCollectionReference mockHighlightsRootCollection;
  late MockDocumentReference mockUserHighlightDoc;
  late MockCollectionReference mockHighlightsSubcollection;

  // Notas
  late MockCollectionReference mockNotesRootCollection;
  late MockDocumentReference mockUserNotesDoc;
  late MockCollectionReference mockNotesSubcollection;
  late MockQuerySnapshot mockNotesQuerySnapshot;

  // O `setUp` é executado antes de CADA teste, garantindo um ambiente limpo e isolado.
  setUp(() {
    // 1. Instancia os mocks
    mockFirestore = MockFirebaseFirestore();

    // Mocks para o fluxo de livros
    mockLivrosCollection = MockCollectionReference();
    mockBookDocument = MockDocumentReference();
    mockBookSnapshot = MockDocumentSnapshot();

    // Mocks para o fluxo de destaques
    mockHighlightsRootCollection = MockCollectionReference();
    mockUserHighlightDoc = MockDocumentReference();
    mockHighlightsSubcollection = MockCollectionReference();

    // Mocks para o fluxo de notas
    mockNotesRootCollection = MockCollectionReference();
    mockUserNotesDoc = MockDocumentReference();
    mockNotesSubcollection = MockCollectionReference();
    mockNotesQuerySnapshot = MockQuerySnapshot();

    // 2. Instancia o serviço que vamos testar, injetando a dependência mockada.
    firestoreService = FirestoreService(firestoreInstance: mockFirestore);

    // 3. Registra um fallback para qualquer chamada a `any(named: '...'))`
    //    Isso é necessário porque `FieldValue.serverTimestamp()` não pode ser
    //    comparado diretamente em `verify`.
    registerFallbackValue(FieldValue.serverTimestamp());
  });

  group('FirestoreService - fetchBookDetails', () {
    // Cenário 1: Livro Encontrado
    test('deve retornar os dados do livro quando o documento existe', () async {
      // DADO (Arrange): Configura a cadeia de chamadas mockadas.
      // firestore.collection('livros') -> .doc('id_valido') -> .get()
      when(() => mockFirestore.collection('livros'))
          .thenReturn(mockLivrosCollection);
      when(() => mockLivrosCollection.doc('id_valido'))
          .thenReturn(mockBookDocument);
      when(() => mockBookDocument.get())
          .thenAnswer((_) async => mockBookSnapshot);

      // Configura o resultado final do snapshot.
      when(() => mockBookSnapshot.exists).thenReturn(true);
      when(() => mockBookSnapshot.data()).thenReturn({
        'titulo': 'Cristianismo Puro e Simples',
        'autor': 'C.S. Lewis',
        'cover_principal': 'url_da_capa.jpg'
      });

      // QUANDO (Act): Executa a função a ser testada.
      final result = await firestoreService.fetchBookDetails('id_valido');

      // ENTÃO (Assert): Verifica se o resultado é o esperado.
      expect(result, isNotNull);
      expect(result?['titulo'], 'Cristianismo Puro e Simples');
      expect(result?['bookId'], 'id_valido');
    });

    // Cenário 2: Livro Não Encontrado
    test('deve retornar null quando o documento do livro não existe', () async {
      // DADO
      when(() => mockFirestore.collection('livros'))
          .thenReturn(mockLivrosCollection);
      when(() => mockLivrosCollection.doc('id_invalido'))
          .thenReturn(mockBookDocument);
      when(() => mockBookDocument.get())
          .thenAnswer((_) async => mockBookSnapshot);
      when(() => mockBookSnapshot.exists)
          .thenReturn(false); // A única diferença

      // QUANDO
      final result = await firestoreService.fetchBookDetails('id_invalido');

      // ENTÃO
      expect(result, isNull);
    });

    // Cenário 3: Erro de Rede
    test('deve relançar uma FirebaseException se a chamada .get() falhar',
        () async {
      // DADO
      when(() => mockFirestore.collection('livros'))
          .thenReturn(mockLivrosCollection);
      when(() => mockLivrosCollection.doc(any())).thenReturn(mockBookDocument);
      when(() => mockBookDocument.get()).thenThrow(FirebaseException(
          plugin: 'firestore',
          code: 'unavailable',
          message: 'Falha de rede simulada'));

      // QUANDO e ENTÃO: Verifica que a chamada da função lança uma exceção do tipo esperado.
      expect(() => firestoreService.fetchBookDetails('qualquer_id'),
          throwsA(isA<FirebaseException>()));
    });
  });

  group('FirestoreService - Highlights & Notes', () {
    // Cenário 4: saveHighlight (CORRIGIDO)
    test('deve chamar os métodos corretos do Firestore ao salvar um destaque',
        () async {
      // DADO
      const userId = 'user123';
      const verseId = 'gn_1_1';

      when(() => mockFirestore.collection('userVerseHighlights'))
          .thenReturn(mockHighlightsRootCollection);
      when(() => mockHighlightsRootCollection.doc(userId))
          .thenReturn(mockUserHighlightDoc);
      when(() => mockUserHighlightDoc.collection('highlights'))
          .thenReturn(mockHighlightsSubcollection);
      when(() => mockHighlightsSubcollection.doc(verseId))
          .thenReturn(mockBookDocument);

      // ✅ CORREÇÃO: Usa `any()` para capturar argumentos posicionais, não nomeados.
      when(() => mockBookDocument.set(any())).thenAnswer((_) async {});
      when(() => mockUserHighlightDoc.set(any(), any()))
          .thenAnswer((_) async {});

      // QUANDO
      await firestoreService.saveHighlight(
        userId,
        verseId,
        '#FFFF00',
        tags: ['fé'],
        fullVerseText: 'No princípio...',
      );

      // ENTÃO
      // 1. Captura o primeiro argumento posicional passado para mockBookDocument.set()
      final capturedData =
          verify(() => mockBookDocument.set(captureAny())).captured.single;

      expect(capturedData, isA<Map<String, dynamic>>());
      expect(capturedData['color'], '#FFFF00');
      expect(capturedData['tags'], ['fé']);
      expect(capturedData['fullVerseText'], 'No princípio...');
      expect(capturedData['timestamp'], isA<FieldValue>());

      // 2. Captura os argumentos da chamada no documento do usuário
      final capturedUserDocCall = verify(() => mockUserHighlightDoc.set(
            captureAny(), // Captura o primeiro argumento (data)
            captureAny(), // Captura o segundo argumento (SetOptions)
          )).captured;

      final capturedUserData = capturedUserDocCall[0] as Map<String, dynamic>;
      final capturedSetOptions = capturedUserDocCall[1] as SetOptions?;

      expect(capturedUserData.containsKey('updatedAt'), isTrue);
      expect(capturedSetOptions, isA<SetOptions>());
    });

    // Cenário 5: loadUserNotesRaw (CORRIGIDO)
    test('deve carregar e retornar um mapa de notas do usuário', () async {
      // DADO
      const userId = 'user123';

      final mockDoc1 = MockQueryDocumentSnapshot();
      when(() => mockDoc1.id).thenReturn('jn_3_16');
      when(() => mockDoc1.data()).thenReturn({'text': 'Nota sobre João 3:16'});

      final mockDoc2 = MockQueryDocumentSnapshot();
      when(() => mockDoc2.id).thenReturn('rm_8_28');
      when(() => mockDoc2.data())
          .thenReturn({'text': 'Nota sobre Romanos 8:28'});

      // ✅ CORREÇÃO: Configura a cadeia completa de mocks dentro do teste.
      when(() => mockFirestore.collection('userVerseNotes'))
          .thenReturn(mockNotesRootCollection);
      when(() => mockNotesRootCollection.doc(userId))
          .thenReturn(mockUserNotesDoc);
      when(() => mockUserNotesDoc.collection('notes'))
          .thenReturn(mockNotesSubcollection);
      when(() => mockNotesSubcollection.get())
          .thenAnswer((_) async => mockNotesQuerySnapshot);

      // Configura o resultado da query
      when(() => mockNotesQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

      // QUANDO
      final result = await firestoreService.loadUserNotesRaw(userId);

      // ENTÃO
      expect(result, isA<Map<String, Map<String, dynamic>>>());
      expect(result.length, 2);
      expect(result.containsKey('jn_3_16'), isTrue);
      expect(result['rm_8_28']?['text'], 'Nota sobre Romanos 8:28');
    });
  });
}
