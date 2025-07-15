// lib/services/translation_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  final OnDeviceTranslator onDeviceTranslator;
  final OnDeviceTranslatorModelManager modelManager;

  // ✅ CONSTRUTOR CORRIGIDO
  TranslationService({
    OnDeviceTranslator?
        onDeviceTranslator, // Nome do parâmetro corresponde ao da classe
    OnDeviceTranslatorModelManager? modelManager,
  })  : this.onDeviceTranslator = onDeviceTranslator ??
            OnDeviceTranslator(
              sourceLanguage: TranslateLanguage.portuguese,
              targetLanguage: TranslateLanguage.english,
            ),
        this.modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  Future<String> translateText(String text) async {
    if (text.trim().isEmpty || kIsWeb) {
      return text;
    }

    try {
      final bool isModelDownloaded = await modelManager
          .isModelDownloaded(TranslateLanguage.portuguese.bcpCode);

      if (!isModelDownloaded) {
        print("TranslationService: Baixando modelo de linguagem Português...");
        await modelManager.downloadModel(TranslateLanguage.portuguese.bcpCode);
        print("TranslationService: Modelo baixado com sucesso.");
      }

      final String translatedText =
          await onDeviceTranslator.translateText(text);
      print("TranslationService: Traduzido de '$text' para '$translatedText'");
      return translatedText;
    } catch (e) {
      print("Erro na tradução on-device: $e");
      return text;
    }
  }

  void dispose() {
    onDeviceTranslator.close();
  }
}
