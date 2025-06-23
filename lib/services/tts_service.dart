// lib/services/tts_service.dart
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  // Callbacks para o middleware usar
  Function()? onStart;
  Function()? onComplete;
  Function(String)? onError;

  // Padrão Singleton para ter uma única instância
  TextToSpeechService._internal() {
    _initTts();
  }
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;

  void _initTts() {
    _flutterTts.setStartHandler(() {
      print("TTS Service: Iniciou a fala.");
      _isPlaying = true;
      onStart?.call(); // Chama o callback se estiver definido
    });

    _flutterTts.setCompletionHandler(() {
      print("TTS Service: Concluiu a fala.");
      _isPlaying = false;
      onComplete?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Service: Erro - $msg");
      _isPlaying = false;
      onError?.call(msg);
    });

    // Configurações padrão
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5);
  }

  bool get isPlaying => _isPlaying;

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      if (_isPlaying) {
        await stop();
      }
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    if (_isPlaying) {
      _isPlaying = false;
      // O completionHandler pode não ser chamado na parada manual,
      // então chamamos o callback aqui para garantir que o estado Redux seja atualizado.
      onComplete?.call();
    }
  }

  // Você pode adicionar outros métodos como setLanguage, setSpeechRate se o middleware precisar chamá-los
}
