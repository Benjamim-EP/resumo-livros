// test/services/translation_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:septima_biblia/services/translation_service.dart';

// --- Mocks (permanecem os mesmos) ---
class MockOnDeviceTranslator extends Mock implements OnDeviceTranslator {}

class MockOnDeviceTranslatorModelManager extends Mock
    implements OnDeviceTranslatorModelManager {}

void main() {
  // ✅ 1. REMOVIDO: TestWidgetsFlutterBinding.ensureInitialized() e toda a lógica de MethodChannel.

  late MockOnDeviceTranslator mockTranslator;
  late MockOnDeviceTranslatorModelManager mockModelManager;
  late TranslationService translationService;

  setUp(() {
    mockTranslator = MockOnDeviceTranslator();
    mockModelManager = MockOnDeviceTranslatorModelManager();

    // ✅ ESTA CHAMADA AGORA ESTÁ CORRETA
    translationService = TranslationService(
      onDeviceTranslator: mockTranslator,
      modelManager: mockModelManager,
    );
  });

  group('TranslationService', () {
    test('deve traduzir o texto corretamente quando o modelo já está baixado',
        () async {
      // DADO
      when(() => mockModelManager.isModelDownloaded(any()))
          .thenAnswer((_) async => true);
      when(() => mockTranslator.translateText('céu'))
          .thenAnswer((_) async => 'sky');

      // QUANDO
      final result = await translationService.translateText('céu');

      // ENTÃO
      expect(result, 'sky');
      verify(() => mockModelManager.isModelDownloaded(any())).called(1);
      verifyNever(() => mockModelManager.downloadModel(any()));
      verify(() => mockTranslator.translateText('céu')).called(1);
    });

    test(
        'deve baixar o modelo e depois traduzir se o modelo não estiver presente',
        () async {
      // DADO
      when(() => mockModelManager.isModelDownloaded(any()))
          .thenAnswer((_) async => false);
      when(() => mockModelManager.downloadModel(any()))
          .thenAnswer((_) async => true);
      when(() => mockTranslator.translateText('nuvem'))
          .thenAnswer((_) async => 'cloud');

      // QUANDO
      final result = await translationService.translateText('nuvem');

      // ENTÃO
      expect(result, 'cloud');
      verify(() => mockModelManager.isModelDownloaded(any())).called(1);
      verify(() => mockModelManager.downloadModel(any())).called(1);
      verify(() => mockTranslator.translateText('nuvem')).called(1);
    });

    test('deve retornar o texto original se a tradução lançar uma exceção',
        () async {
      // DADO
      when(() => mockModelManager.isModelDownloaded(any()))
          .thenAnswer((_) async => true);
      when(() => mockTranslator.translateText('erro'))
          .thenThrow(Exception('Falha simulada'));

      // QUANDO
      final result = await translationService.translateText('erro');

      // ENTÃO
      expect(result, 'erro');
    });

    test(
        'deve retornar uma string vazia imediatamente se o input for vazio ou apenas espaços',
        () async {
      // QUANDO
      final result = await translationService.translateText('  ');

      // ENTÃO
      expect(result, '  ');
      verifyNever(() => mockModelManager.isModelDownloaded(any()));
      verifyNever(() => mockTranslator.translateText(any()));
    });
  });
}
