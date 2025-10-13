// lib/services/tts_manager.dart
// lib/services/tts_manager.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:septima_biblia/consts/bible_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// Enums e Classes de Dados (sem alterações)
enum TtsContentType { versesOnly, versesAndCommentary }

class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

enum TtsPlayerState { playing, stopped, paused }

// Constantes (sem alterações)
const String _ttsVoicePrefsKey = 'user_selected_tts_voice';
const Map<String, String> _voiceDisplayNames = {
  'pt-br-x-afs-local': 'Voz Feminina 2 (Offline)',
  'pt-br-x-pte-local': 'Voz Feminina 1 (Offline)',
  'pt-br-x-ptd-local': 'Voz Masculina 1 (Offline)',
};

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  // <<< INÍCIO DA GRANDE MUDANÇA: MAPAS ESTÁTICOS >>>

  // 1. O mapa de variações agora é uma constante estática no código.
  static const Map<String, String> _bookVariationsMap = {
    "genesis": "gn", "gênesis": "gn", "gen": "gn", "exodo": "ex", "êxodo": "ex",
    "levitico": "lv", "levítico": "lv", "numeros": "nm", "números": "nm",
    "deuteronomio": "dt", "deuteronômio": "dt", "josue": "js", "josué": "js",
    "juizes": "jz", "juízes": "jz", "rute": "rt", "1 samuel": "1sm",
    "1samuel": "1sm",
    "1 sm": "1sm", "1sam": "1sm", "2 samuel": "2sm", "2samuel": "2sm",
    "2 sm": "2sm",
    "2sam": "2sm", "1 reis": "1rs", "1reis": "1rs", "2 reis": "2rs",
    "2reis": "2rs",
    "1 cronicas": "1cr", "1 crônicas": "1cr", "1cronicas": "1cr",
    "2 cronicas": "2cr",
    "2 crônicas": "2cr", "2cronicas": "2cr", "esdras": "ed", "neemias": "ne",
    "ester": "et", "jó": "job", "job": "job", "salmos": "sl", "salmo": "sl",
    "sls": "sl",
    "proverbios": "pv", "provérbios": "pv", "eclesiastes": "ec",
    "cantico dos canticos": "ct",
    "cântico dos cânticos": "ct", "cantares": "ct", "isaias": "is",
    "isaías": "is",
    "jeremias": "jr", "lamentacoes": "lm", "lamentações": "lm",
    "ezequiel": "ez",
    "daniel": "dn", "oseias": "os", "oséias": "os", "joel": "jl", "amos": "am",
    "amós": "am", "obadias": "ob", "jonas": "jn", "miqueias": "mq",
    "miquéias": "mq",
    "naum": "na", "habacuque": "hc", "sofonias": "sf", "ageu": "ag",
    "zacarias": "zc",
    "malaquias": "ml", "mateus": "mt", "marcos": "mc", "lucas": "lc",
    "joao": "jo",
    "joão": "jo", "atos": "at", "atos dos apostolos": "at", "romanos": "rm",
    "1 corintios": "1co", "1 coríntios": "1co", "1corintios": "1co",
    "2 corintios": "2co",
    "2 coríntios": "2co", "2corintios": "2co", "galatas": "gl", "gálatas": "gl",
    "efesios": "ef", "efésios": "ef", "filipenses": "fp", "colossenses": "cl",
    "1 tessalonicenses": "1ts", "1tessalonicenses": "1ts",
    "2 tessalonicenses": "2ts",
    "2tessalonicenses": "2ts", "1 timoteo": "1tm", "1 timóteo": "1tm",
    "1timoteo": "1tm",
    "2 timoteo": "2tm", "2 timóteo": "2tm", "2timoteo": "2tm", "tito": "tt",
    "filemom": "fm", "filemon": "fm", "hebreus": "hb", "tiago": "tg",
    "1 pedro": "1pe",
    "1pedro": "1pe", "2 pedro": "2pe", "2pedro": "2pe", "1 joao": "1jo",
    "1 joão": "1jo",
    "1joao": "1jo", "2 joao": "2jo", "2 joão": "2jo", "2joao": "2jo",
    "3 joao": "3jo",
    "3 joão": "3jo", "3joao": "3jo", "judas": "jd", "apocalipse": "ap"
    // Nota: A variação "jo" já aponta para "joão"
  };

  // 2. O mapa final combinado é construído uma única vez quando a classe é carregada.
  static final Map<String, String> _variationToFullNameMap =
      _createCombinedMap();

  // 3. Função auxiliar que constrói o mapa combinado.
  static Map<String, String> _createCombinedMap() {
    print("TTS Manager: Construindo mapa combinado de livros para TTS...");
    final finalMap = <String, String>{};

    String normalize(String text) => unorm
        .nfd(text.toLowerCase())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');

    _bookVariationsMap.forEach((variation, abbrev) {
      final fullName = ABBREV_TO_FULL_NAME_MAP[abbrev];
      if (fullName != null) {
        finalMap[normalize(variation)] = fullName;
      }
    });

    // Garante que o nome completo também seja uma chave
    ABBREV_TO_FULL_NAME_MAP.forEach((abbrev, fullName) {
      finalMap[normalize(fullName)] = fullName;
    });

    print(
        "TTS Manager: Mapa combinado de livros para TTS construído com sucesso.");
    return finalMap;
  }

  // <<< FIM DA GRANDE MUDANÇA >>>

  // Variáveis de estado (sem alterações)
  final ValueNotifier<TtsPlayerState> playerState =
      ValueNotifier(TtsPlayerState.stopped);
  final ValueNotifier<String?> currentPlayingId = ValueNotifier(null);
  final List<TtsQueueItem> _queue = [];
  int _currentQueueIndex = -1;

  // Callbacks (sem alterações)
  Function(String)? onError;
  Function()? onStart;
  Function()? onComplete;

  TtsManager._internal() {
    _initTts();
  }

  // <<< FUNÇÃO DE PRÉ-PROCESSAMENTO ATUALIZADA >>>
  String _preprocessTextForTts(String text) {
    // Regex aprimorada (sem alterações, já estava boa)
    final RegExp bibleRefRegex = RegExp(
      r'\b([1-3]?\s*[a-zA-ZçÇáéíóúâêôãõ\.]+)\s*(\d+)(?::(\d+(?:-\d+)?))?\b',
      caseSensitive: false,
    );

    String normalize(String text) => unorm
        .nfd(text.toLowerCase())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');

    return text.replaceAllMapped(bibleRefRegex, (match) {
      String bookNamePart = match.group(1)!.trim();
      String chapter = match.group(2)!;
      String? verses = match.group(3);

      String normalizedBookName = normalize(bookNamePart);

      // Usa o mapa estático _variationToFullNameMap
      String? bookFullName = _variationToFullNameMap[normalizedBookName];

      if (bookFullName == null) {
        return match.group(0)!;
      }

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
  }

  void _initTts() async {
    // <<< REMOVIDO: a chamada para _loadAndPrepareBookMaps() não é mais necessária aqui >>>
    if (kIsWeb) return;

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
      if (playerState.value != TtsPlayerState.playing) {
        playerState.value = TtsPlayerState.playing;
      }
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
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

      // Pré-processa o texto ANTES de enviar para o motor TTS
      final processedText = _preprocessTextForTts(item.textToSpeak);
      print(
          "TTS Manager: Texto Original: '${item.textToSpeak}' -> Processado: '$processedText'");

      _flutterTts.speak(processedText);
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
    if (kIsWeb) return;
    if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
      final currentItem = _queue[_currentQueueIndex];
      playerState.value = TtsPlayerState.playing;

      // Pré-processa o texto ANTES de reiniciar
      final processedText = _preprocessTextForTts(currentItem.textToSpeak);
      await _flutterTts.speak(processedText);

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
