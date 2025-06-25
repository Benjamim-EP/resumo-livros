// lib/services/tts_manager.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsContentType { versesOnly, versesAndCommentary }

class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

enum TtsPlayerState { playing, stopped }

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

  final List<TtsQueueItem> _queue = [];
  int _currentQueueIndex = -1;
  bool isContinuousPlayEnabled = false;

  Function(String)? onError;
  Function()? onStart;
  Function()? onComplete;

  void _initTts() {
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      playerState.value = TtsPlayerState.playing;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      // Quando a fala de um item termina, toca o próximo se houver
      if (isContinuousPlayEnabled && _currentQueueIndex < _queue.length - 1) {
        _playNextInQueue();
      } else {
        _stopAndClear(); // Para tudo se for o fim da fila ou modo não-contínuo
      }
      onComplete?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Manager Error: $msg");
      _stopAndClear();
      onError?.call(msg);
    });
  }

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
      // Atualiza o ID da seção que está tocando agora
      currentPlayingId.value = item.sectionId;
      _flutterTts.speak(item.textToSpeak);
    }
  }

  /// Inicia a reprodução de uma fila de itens.
  Future<void> speak(
      List<TtsQueueItem> itemsToPlay, String startSectionId) async {
    await stop();

    _queue.clear();

    // Se o modo contínuo não estiver ativo, a fila terá apenas o item inicial.
    if (!isContinuousPlayEnabled) {
      final startItem = itemsToPlay.firstWhere(
          (item) => item.sectionId == startSectionId,
          orElse: () => itemsToPlay.first);
      _queue.add(startItem);
      _currentQueueIndex = -1;
    } else {
      // Se for contínuo, adiciona todos os itens a partir do item inicial.
      int startIndex =
          itemsToPlay.indexWhere((item) => item.sectionId == startSectionId);
      if (startIndex == -1) {
        print("Error: Start section ID '$startSectionId' not found in queue.");
        return;
      }
      _queue.addAll(itemsToPlay.sublist(startIndex));
      _currentQueueIndex = -1;
    }

    _playNextInQueue();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _stopAndClear();
  }
}
