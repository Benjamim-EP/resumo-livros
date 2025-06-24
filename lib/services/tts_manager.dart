// lib/services/tts_manager.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Enum para representar o tipo de conteúdo a ser lido pelo TTS.
enum TtsContentType { versesOnly, versesAndCommentary }

/// Representa um item que pode ser reproduzido.
class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

/// Enum para os possíveis estados do player de TTS.
enum TtsPlayerState { playing, stopped }

/// Gerencia a funcionalidade de Text-to-Speech (TTS) para todo o aplicativo.
class TtsManager {
  // --- Padrão Singleton ---
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal() {
    _initTts();
  }
  // -------------------------

  final FlutterTts _flutterTts = FlutterTts();

  // --- Notificadores de Estado para a UI ---
  final ValueNotifier<TtsPlayerState> playerState =
      ValueNotifier(TtsPlayerState.stopped);
  final ValueNotifier<String?> currentPlayingId = ValueNotifier(null);

  // --- Controle de Reprodução ---
  bool isContinuousPlayEnabled = false;

  void _initTts() {
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    // Handlers para atualizar o estado
    _flutterTts.setStartHandler(() {
      playerState.value = TtsPlayerState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _stopAndClearState();
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Manager Error: $msg");
      _stopAndClearState();
    });

    // Handler para saber qual parte do texto está sendo falada
    _flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      // Esta lógica é um pouco mais complexa e pode ser implementada depois
      // para destacar a seção atual na UI enquanto fala.
      // Por agora, vamos manter simples.
    });
  }

  /// Apenas limpa as variáveis de estado, sem interagir com o plugin.
  void _stopAndClearState() {
    currentPlayingId.value = null;
    playerState.value = TtsPlayerState.stopped;
  }

  /// Inicia a reprodução. Constrói o texto completo e faz uma única chamada.
  Future<void> speak(
      List<TtsQueueItem> itemsToPlay, String startSectionId) async {
    if (itemsToPlay.isEmpty) return;

    await stop(); // Garante que qualquer fala anterior seja parada.

    int startIndex =
        itemsToPlay.indexWhere((item) => item.sectionId == startSectionId);
    if (startIndex == -1) {
      print("Error: Start section ID '$startSectionId' not found.");
      return;
    }

    // Define qual seção está "tocando" para a UI reagir.
    // Para simplificar, consideramos a seção inicial como a que está tocando.
    currentPlayingId.value = startSectionId;

    // Constrói a string completa para ser lida.
    final StringBuffer fullTextBuffer = StringBuffer();

    // Se o modo contínuo estiver ativado, lê a partir da seção inicial até o fim.
    // Se não, lê apenas a seção inicial.
    final List<TtsQueueItem> playlist = isContinuousPlayEnabled
        ? itemsToPlay.sublist(startIndex)
        : [itemsToPlay[startIndex]];

    for (var item in playlist) {
      fullTextBuffer.writeln(item.textToSpeak);
      fullTextBuffer.writeln(" "); // Adiciona uma pequena pausa entre as seções
    }

    final String textToSpeak = fullTextBuffer.toString();

    if (textToSpeak.isNotEmpty) {
      await _flutterTts.speak(textToSpeak);
    } else {
      _stopAndClearState();
    }
  }

  /// Para a reprodução de áudio imediatamente.
  Future<void> stop() async {
    await _flutterTts.stop();
    _stopAndClearState();
  }
}
