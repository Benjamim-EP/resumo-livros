// lib/services/tts_manager.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Enums e Classes de Dados ---
enum TtsContentType { versesOnly, versesAndCommentary }

class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

enum TtsPlayerState { playing, stopped, paused }

// --- Chave de Persistência ---
const String _ttsVoicePrefsKey = 'user_selected_tts_voice';

/// Gerencia a funcionalidade de Text-to-Speech (TTS) para todo o aplicativo.
///
/// Utiliza o padrão Singleton para garantir uma única instância, evitando
/// conflitos e gerenciando centralmente a fila de reprodução, o estado e
/// a seleção de voz.
class TtsManager {
  // --- Singleton ---
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();

  // --- Estado ---
  final ValueNotifier<TtsPlayerState> playerState =
      ValueNotifier(TtsPlayerState.stopped);
  final ValueNotifier<String?> currentPlayingId = ValueNotifier(null);
  final List<TtsQueueItem> _queue = [];
  int _currentQueueIndex = -1;

  // --- Callbacks ---
  Function(String)? onError;
  Function()? onStart;
  Function()? onComplete;

  void _initTts() async {
    if (Platform.isAndroid) {
      try {
        await _flutterTts.setEngine("com.google.android.tts");
        print("TTS Manager: Motor TTS definido para 'com.google.android.tts'.");
      } catch (e) {
        print("TTS Manager: Falha ao definir motor do Google. Erro: $e");
      }
    }
    await _loadAndSetVoice();
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      // Somente muda para 'playing' se não estiver já nesse estado (evita loops com restart)
      if (playerState.value != TtsPlayerState.playing) {
        playerState.value = TtsPlayerState.playing;
      }
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      // Se a fala terminou naturalmente (não foi pausada), avança na fila.
      if (playerState.value != TtsPlayerState.paused) {
        if (_currentQueueIndex < _queue.length - 1) {
          _playNextInQueue();
        } else {
          _stopAndClear();
        }
        onComplete?.call();
      }
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
      currentPlayingId.value = item.sectionId;
      _flutterTts.speak(item.textToSpeak);
    } else {
      _stopAndClear();
    }
  }

  /// Inicia a reprodução de uma fila de itens a partir de um ID específico.
  Future<void> speak(
      List<TtsQueueItem> itemsToPlay, String startSectionId) async {
    await stop();
    _queue.clear();

    int startIndex =
        itemsToPlay.indexWhere((item) => item.sectionId == startSectionId);
    if (startIndex == -1) {
      print("Error: Start section ID '$startSectionId' not found in queue.");
      return;
    }

    _queue.addAll(itemsToPlay.sublist(startIndex));

    _currentQueueIndex = -1;
    _playNextInQueue();
  }

  /// Para a reprodução de áudio imediatamente.
  Future<void> stop() async {
    await _flutterTts.stop();
    _stopAndClear();
  }

  /// Pausa a fala atual.
  Future<void> pause() async {
    if (playerState.value == TtsPlayerState.playing) {
      var result = await _flutterTts.pause();
      if (result == 1) {
        // 1 indica sucesso
        playerState.value = TtsPlayerState.paused;
        print("TTS Manager: Fala pausada.");
      }
    }
  }

  /// REINICIA a fala do item atual da fila.
  Future<void> restartCurrentItem() async {
    if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
      final currentItem = _queue[_currentQueueIndex];
      // Atualiza o estado manualmente para refletir a ação de tocar
      playerState.value = TtsPlayerState.playing;
      // Chama speak com o texto do item atual, reiniciando-o.
      await _flutterTts.speak(currentItem.textToSpeak);
      print("TTS Manager: Reiniciando item atual da fila.");
    }
  }

  // --- MÉTODOS DE GERENCIAMENTO DE VOZ ---
  Future<void> _loadAndSetVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoiceJsonString = prefs.getString(_ttsVoicePrefsKey);

      if (savedVoiceJsonString != null) {
        final savedVoiceMap =
            Map<String, String>.from(json.decode(savedVoiceJsonString));
        await _flutterTts.setVoice(savedVoiceMap);
        print("TTS Manager: Voz salva '${savedVoiceMap['name']}' aplicada.");
      } else {
        await _flutterTts.setLanguage("pt-BR");
        print(
            "TTS Manager: Nenhuma voz salva encontrada. Usando idioma padrão pt-BR.");
      }
    } catch (e) {
      print("TTS Manager: Erro ao carregar/definir voz: $e");
      await _flutterTts.setLanguage("pt-BR");
    }
  }

  Future<List<Map<dynamic, dynamic>>> getAvailableVoices() async {
    try {
      var voices = await _flutterTts.getVoices;
      if (voices is List) {
        return voices
            .where((voice) =>
                voice is Map &&
                voice['locale'] != null &&
                voice['locale'].toString().toLowerCase().contains('pt-br'))
            .map((voice) => voice as Map<dynamic, dynamic>)
            .toList();
      }
      return [];
    } catch (e) {
      print("TTS Manager: Erro ao obter vozes: $e");
      return [];
    }
  }

  Future<void> setVoice(Map<dynamic, dynamic> voice) async {
    try {
      final Map<String, String> voiceToSet = voice.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      await _flutterTts.setVoice(voiceToSet);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ttsVoicePrefsKey, json.encode(voiceToSet));
      print("TTS Manager: Voz '${voice['name']}' definida e salva.");
    } catch (e) {
      print("TTS Manager: Erro ao definir a voz: $e");
    }
  }
}
