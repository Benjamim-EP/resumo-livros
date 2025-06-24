// lib/services/tts_manager.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Enum para o tipo de conteúdo a ser lido
enum TtsContentType { versesOnly, versesAndCommentary }

// Classe para representar um item na nossa fila de leitura
class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

enum TtsPlayerState { playing, stopped, paused }

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<TtsPlayerState> playerState =
      ValueNotifier(TtsPlayerState.stopped);
  final ValueNotifier<String?> currentPlayingId = ValueNotifier(null);

  // Fila de leitura contínua
  final List<TtsQueueItem> _queue = [];
  int _currentQueueIndex = -1;
  bool isContinuousPlayEnabled = false; // Estado do modo contínuo

  void _initTts() {
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      playerState.value = TtsPlayerState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      // Quando uma fala termina, verifica se deve tocar o próximo item da fila
      if (isContinuousPlayEnabled && _currentQueueIndex < _queue.length - 1) {
        _playNextInQueue();
      } else {
        // Se não houver próximo item ou o modo contínuo estiver desativado, para tudo.
        _stopAndClear();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Manager Error: $msg");
      _stopAndClear();
    });
  }

  // Limpa a fila e para a reprodução
  void _stopAndClear() {
    _queue.clear();
    _currentQueueIndex = -1;
    currentPlayingId.value = null;
    playerState.value = TtsPlayerState.stopped;
  }

  void _playNextInQueue() {
    _currentQueueIndex++;
    if (_currentQueueIndex < _queue.length) {
      final item = _queue[_currentQueueIndex];
      currentPlayingId.value = item.sectionId;
      _flutterTts.speak(item.textToSpeak);
    }
  }

  // Novo método para iniciar a fala, agora com uma fila
  Future<void> speak(
      List<TtsQueueItem> itemsToPlay, String startSectionId) async {
    await stop(); // Sempre para a reprodução anterior

    _queue.clear();
    _queue.addAll(itemsToPlay);

    // Encontra o índice do item inicial
    int startIndex =
        _queue.indexWhere((item) => item.sectionId == startSectionId);
    if (startIndex == -1) {
      print("Error: Start section ID not found in queue.");
      return;
    }

    _currentQueueIndex =
        startIndex - 1; // Começará do índice correto no _playNextInQueue
    _playNextInQueue();
  }

  Future<void> stop() async {
    _stopAndClear();
    await _flutterTts.stop();
  }
}
