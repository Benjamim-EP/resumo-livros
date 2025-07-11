// lib/services/translation_service.dart
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  // O tradutor para realizar a tradução em si
  final _onDeviceTranslator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.portuguese,
    targetLanguage: TranslateLanguage.english,
  );

  // ✅ CORREÇÃO: O gerenciador de modelos agora é uma classe separada
  final _modelManager = OnDeviceTranslatorModelManager();

  /// Traduz um texto de português para inglês.
  /// Retorna o texto original em caso de erro.
  Future<String> translateText(String text) async {
    if (text.trim().isEmpty) {
      return text; // Retorna o texto vazio se não houver nada para traduzir
    }

    try {
      // ✅ CORREÇÃO: Usa o _modelManager para verificar e baixar o modelo
      final bool isModelDownloaded = await _modelManager
          .isModelDownloaded(TranslateLanguage.portuguese.bcpCode);

      if (!isModelDownloaded) {
        print("TranslationService: Baixando modelo de linguagem Português...");
        // Usa o _modelManager para fazer o download
        await _modelManager.downloadModel(TranslateLanguage.portuguese.bcpCode);
        print("TranslationService: Modelo baixado com sucesso.");
      }

      // A tradução em si ainda é feita pelo _onDeviceTranslator
      final String translatedText =
          await _onDeviceTranslator.translateText(text);
      print("TranslationService: Traduzido de '$text' para '$translatedText'");
      return translatedText;
    } catch (e) {
      print("Erro na tradução on-device: $e");
      return text; // Em caso de erro, retorna o texto original para a busca
    }
  }

  /// Libera os recursos do tradutor e do gerenciador quando não for mais necessário.
  void dispose() {
    _onDeviceTranslator.close();
    //_modelManager.close(); // ✅ CORREÇÃO: Também fecha o gerenciador
  }
}
