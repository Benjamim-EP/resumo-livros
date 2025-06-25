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

enum TtsPlayerState { playing, stopped }

// --- Chave de Persistência ---
const String _ttsVoicePrefsKey = 'user_selected_tts_voice';

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
    // >>> INÍCIO DA ALTERAÇÃO PRINCIPAL <<<
    // Define o motor a ser usado (apenas para Android)
    if (Platform.isAndroid) {
      try {
        // Tenta definir o motor do Google como o padrão para o app.
        // Isso resolve problemas em dispositivos Samsung e outros que têm
        // um motor TTS próprio de qualidade inferior ou sem pacotes de voz.
        await _flutterTts.setEngine("com.google.android.tts");
        print("TTS Manager: Motor TTS definido para 'com.google.android.tts'.");
      } catch (e) {
        print(
            "TTS Manager: Falha ao definir motor do Google. Usará o padrão do sistema. Erro: $e");
      }
    }
    // >>> FIM DA ALTERAÇÃO PRINCIPAL <<<

    // Carrega e aplica a voz salva na inicialização.
    await _loadAndSetVoice();

    // Configurações padrão de fala
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    // Configura os Handlers de evento
    _flutterTts.setStartHandler(() {
      playerState.value = TtsPlayerState.playing;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      if (_currentQueueIndex < _queue.length - 1) {
        _playNextInQueue();
      } else {
        _stopAndClear();
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

    // Encontra o índice do primeiro item da seção clicada.
    int startIndex =
        itemsToPlay.indexWhere((item) => item.sectionId == startSectionId);
    if (startIndex == -1) {
      print("Error: Start section ID '$startSectionId' not found in queue.");
      return;
    }

    // A fila interna SEMPRE conterá os itens da seção clicada em diante.
    _queue.addAll(itemsToPlay.sublist(startIndex));

    _currentQueueIndex = -1;
    _playNextInQueue();
  }

  /// Para a reprodução de áudio imediatamente.
  Future<void> stop() async {
    await _flutterTts.stop();
    _stopAndClear();
  }

  // --- MÉTODOS DE GERENCIAMENTO DE VOZ ---

  Future<void> _loadAndSetVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoiceJsonString = prefs.getString(_ttsVoicePrefsKey);

      if (savedVoiceJsonString != null) {
        // CORREÇÃO APLICADA AQUI TAMBÉM
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
      // CORREÇÃO PRINCIPAL APLICADA AQUI
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
