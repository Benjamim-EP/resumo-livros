// lib/services/tts_manager.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:septima_biblia/consts/bible_constants.dart'; // >>> 1. IMPORTAR CONSTANTES
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
const Map<String, String> _voiceDisplayNames = {
  'pt-br-x-afs-local': 'Voz Masculina 1 (Offline)',
  'pt-br-x-pte-local': 'Voz Feminina 1 (Offline)',
  'pt-br-x-ptd-local': 'Voz Masculina 2 (Offline)',
};

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

  // >>> INÍCIO DA MODIFICAÇÃO 1/3: Função de pré-processamento de texto <<<

  /// Pré-processa um texto, convertendo referências bíblicas em formato falável.
  /// Ex: "Gn 3:2-5" se torna "Gênesis, capítulo 3, versículos 2 a 5".
  String _preprocessTextForTts(String text) {
    // Regex para encontrar referências como: 1Jo 1:9, Gn 3:2-5, Sl 119:105, 2 Co 5:17
    // A regex foi aprimorada para ser mais precisa
    final RegExp bibleRefRegex = RegExp(
      r'\b([1-3]?\s*[a-zA-ZçÇéÉáÁúÚíÍóÓâÂêÊôÔãÃõÕ]+)\s+(\d+)(?::(\d+(?:-\d+)?))?\b',
      caseSensitive: false,
    );

    String processedText = text.replaceAllMapped(bibleRefRegex, (match) {
      String bookAbbrevRaw =
          match.group(1)!.trim().toLowerCase().replaceAll(' ', '');
      String chapter = match.group(2)!;
      String? verses = match.group(3); // Pode ser nulo, ex: "Gn 1"

      // Trata abreviações comuns que podem não estar no mapa, ex: "jo" vs "jó"
      if (bookAbbrevRaw == 'jo' && text.toLowerCase().contains('jó')) {
        bookAbbrevRaw = 'job';
      }

      String bookFullName =
          ABBREV_TO_FULL_NAME_MAP[bookAbbrevRaw] ?? match.group(1)!;

      if (verses != null) {
        if (verses.contains('-')) {
          final verseParts = verses.split('-');
          return '$bookFullName, capítulo $chapter, versículos ${verseParts[0]} a ${verseParts[1]}';
        } else {
          return '$bookFullName, capítulo $chapter, versículo $verses';
        }
      } else {
        return '$bookFullName, capítulo $chapter';
      }
    });

    // Caso especial: se a string INTEIRA era só uma referência, adicione contexto.
    // Ex: "2co 6:14" se torna "Referência: 2 Coríntios..."
    final isOnlyReference = bibleRefRegex.allMatches(text.trim()).length == 1 &&
        bibleRefRegex.firstMatch(text.trim())?.group(0) == text.trim();

    if (isOnlyReference) {
      // Remove a vírgula final se houver
      if (processedText.endsWith(', ')) {
        processedText = processedText.substring(0, processedText.length - 2);
      }
      return 'Referência: $processedText.';
    }

    // Adiciona uma pequena pausa após a referência processada para melhorar a fluidez.
    processedText = processedText.replaceAllMapped(
        RegExp(r'(versículos? \d+(?: a \d+)?)'),
        (match) => '${match.group(0)!}, ');

    return processedText;
  }

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
      // >>> INÍCIO DA MODIFICAÇÃO 3/3: Pré-processa o texto aqui também <<<
      final processedText = _preprocessTextForTts(currentItem.textToSpeak);
      // Chama speak com o texto do item atual, reiniciando-o.
      await _flutterTts.speak(processedText);
      // >>> FIM DA MODIFICAÇÃO 3/3 <<<
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
        // --- INÍCIO DA MODIFICAÇÃO: Filtrar apenas as vozes desejadas ---
        return voices
            .where((voice) =>
                voice is Map &&
                // A chave da verificação agora é se o nome técnico da voz está no nosso mapa
                _voiceDisplayNames.containsKey(voice['name']))
            .map((voice) => voice as Map<dynamic, dynamic>)
            .toList();
        // --- FIM DA MODIFICAÇÃO ---
      }
      return [];
    } catch (e) {
      print("TTS Manager: Erro ao obter vozes: $e");
      return [];
    }
  }

  // --- INÍCIO DA NOVA ADIÇÃO: Função para obter o nome amigável ---
  /// Retorna o nome amigável para uma voz, ou o nome original se não houver mapeamento.
  String getVoiceDisplayName(String? rawVoiceName) {
    if (rawVoiceName == null) return 'Voz Desconhecida';
    return _voiceDisplayNames[rawVoiceName] ?? rawVoiceName;
  }
  // --- FIM DA NOVA ADIÇÃO ---

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
