// lib/services/tts_manager.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:septima_biblia/consts/bible_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// --- Enums e Classes de Dados ---
enum TtsContentType {
  versesOnly,
  versesAndCommentary,
}

class TtsQueueItem {
  final String sectionId;
  final String textToSpeak;
  TtsQueueItem({required this.sectionId, required this.textToSpeak});
}

enum TtsPlayerState { playing, stopped, paused }

// --- Chaves e Constantes de Persistência ---
const String _ttsVoicePrefsKey = 'user_selected_tts_voice';
const Map<String, String> _voiceDisplayNames = {
  'pt-br-x-afs-local': 'Voz Feminina 2 (Offline)',
  'pt-br-x-pte-local': 'Voz Feminina 1 (Offline)',
  'pt-br-x-ptd-local': 'Voz Masculina 1 (Offline)',
};

class TtsManager {
  // --- Singleton ---
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  // --- Mapas Estáticos para Nomes de Livros ---
  static const Map<String, String> _bookVariationsMap = {
    "genesis": "gn",
    "gênesis": "gn",
    "gen": "gn",
    "exodo": "ex",
    "êxodo": "ex",
    "levitico": "lv",
    "levítico": "lv",
    "numeros": "nm",
    "números": "nm",
    "deuteronomio": "dt",
    "deuteronômio": "dt",
    "josue": "js",
    "josué": "js",
    "juizes": "jz",
    "juízes": "jz",
    "rute": "rt",
    "1 samuel": "1sm",
    "1samuel": "1sm",
    "1 sm": "1sm",
    "1sam": "1sm",
    "2 samuel": "2sm",
    "2samuel": "2sm",
    "2 sm": "2sm",
    "2sam": "2sm",
    "1 reis": "1rs",
    "1reis": "1rs",
    "2 reis": "2rs",
    "2reis": "2rs",
    "1 cronicas": "1cr",
    "1 crônicas": "1cr",
    "1cronicas": "1cr",
    "2 cronicas": "2cr",
    "2 crônicas": "2cr",
    "2cronicas": "2cr",
    "esdras": "ed",
    "neemias": "ne",
    "ester": "et",
    "jó": "job",
    "job": "job",
    "salmos": "sl",
    "salmo": "sl",
    "sls": "sl",
    "proverbios": "pv",
    "provérbios": "pv",
    "eclesiastes": "ec",
    "cantico dos canticos": "ct",
    "cântico dos cânticos": "ct",
    "cantares": "ct",
    "isaias": "is",
    "isaías": "is",
    "jeremias": "jr",
    "lamentacoes": "lm",
    "lamentações": "lm",
    "ezequiel": "ez",
    "daniel": "dn",
    "oseias": "os",
    "oséias": "os",
    "joel": "jl",
    "amos": "am",
    "amós": "am",
    "obadias": "ob",
    "jonas": "jn",
    "miqueias": "mq",
    "miquéias": "mq",
    "naum": "na",
    "habacuque": "hc",
    "sofonias": "sf",
    "ageu": "ag",
    "zacarias": "zc",
    "malaquias": "ml",
    "mateus": "mt",
    "marcos": "mc",
    "lucas": "lc",
    "joao": "jo",
    "joão": "jo",
    "atos": "at",
    "atos dos apostolos": "at",
    "romanos": "rm",
    "1 corintios": "1co",
    "1 coríntios": "1co",
    "1corintios": "1co",
    "2 corintios": "2co",
    "2 coríntios": "2co",
    "2corintios": "2co",
    "galatas": "gl",
    "gálatas": "gl",
    "efesios": "ef",
    "efésios": "ef",
    "filipenses": "fp",
    "colossenses": "cl",
    "1 tessalonicenses": "1ts",
    "1tessalonicenses": "1ts",
    "2 tessalonicenses": "2ts",
    "2tessalonicenses": "2ts",
    "1 timoteo": "1tm",
    "1 timóteo": "1tm",
    "1timoteo": "1tm",
    "2 timoteo": "2tm",
    "2 timóteo": "2tm",
    "2timoteo": "2tm",
    "tito": "tt",
    "filemom": "fm",
    "filemon": "fm",
    "hebreus": "hb",
    "tiago": "tg",
    "1 pedro": "1pe",
    "1pedro": "1pe",
    "2 pedro": "2pe",
    "2pedro": "2pe",
    "1 joao": "1jo",
    "1 joão": "1jo",
    "1joao": "1jo",
    "2 joao": "2jo",
    "2 joão": "2jo",
    "2joao": "2jo",
    "3 joao": "3jo",
    "3 joão": "3jo",
    "3joao": "3jo",
    "judas": "jd",
    "apocalipse": "ap"
  };

  static final Map<String, String> _variationToFullNameMap =
      _createCombinedMap();

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

    ABBREV_TO_FULL_NAME_MAP.forEach((abbrev, fullName) {
      finalMap[normalize(fullName)] = fullName;
    });

    print(
        "TTS Manager: Mapa combinado de livros para TTS construído com sucesso.");
    return finalMap;
  }

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

  TtsManager._internal() {
    _initTts();
  }

  String _preprocessTextForTts(String text) {
    String? lastBook;
    String? lastChapter;
    String normalize(String text) => unorm
        .nfd(text.toLowerCase())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');

    final RegExp fullRefRegex = RegExp(
      r'\b([1-3]?\s*[a-zA-ZçÇáéíóúâêôãõ\.]+)\s*(\d+)(?::(\d+(?:(?:-\d+)|(?:,\s*\d+))*))?\b',
      caseSensitive: false,
    );

    String processedText = text.replaceAllMapped(fullRefRegex, (match) {
      String bookNamePart = match.group(1)!.trim();
      String chapter = match.group(2)!;
      String? verses = match.group(3);

      String normalizedBookName = normalize(bookNamePart);
      String? bookFullName = _variationToFullNameMap[normalizedBookName];

      if (bookFullName == null) {
        return match.group(0)!;
      }

      lastBook = bookFullName;
      lastChapter = chapter;

      if (verses != null) {
        String versesSpoken = verses.replaceAll(',', ' e');
        if (verses.contains('-')) {
          final verseParts = verses.split('-');
          return '$bookFullName, capítulo $chapter, versículos ${verseParts[0]} a ${verseParts[1]}';
        } else {
          return '$bookFullName, capítulo $chapter, versículo $versesSpoken';
        }
      } else {
        return '$bookFullName, capítulo $chapter';
      }
    });

    final RegExp shortRefRegex = RegExp(r'\b(\d+):(\d+(?:-\d+)?)\b');
    processedText = processedText.replaceAllMapped(shortRefRegex, (match) {
      if (match.input.substring(0, match.start).trim().endsWith(',')) {
        return match.group(0)!;
      }

      String chapter = match.group(1)!;
      String verses = match.group(2)!;

      if (lastBook == null) {
        return match.group(0)!;
      }

      String bookFullName = lastBook!;
      lastChapter = chapter;

      if (verses.contains('-')) {
        final verseParts = verses.split('-');
        return '$bookFullName, capítulo $chapter, versículos ${verseParts[0]} a ${verseParts[1]}';
      } else {
        return '$bookFullName, capítulo $chapter, versículo $verses';
      }
    });

    return processedText;
  }

  void _initTts() async {
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
      final processedText = _preprocessTextForTts(item.textToSpeak);
      print(
          "TTS Manager: Texto Original: '${item.textToSpeak}' -> Processado: '$processedText'");
      _flutterTts.speak(processedText);
    } else {
      _stopAndClear();
    }
  }

  Future<void> speak(
      List<TtsQueueItem> itemsToPlay, String startSectionId) async {
    if (kIsWeb) return;
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

  Future<void> stop() async {
    if (kIsWeb) return;
    await _flutterTts.stop();
    _stopAndClear();
  }

  Future<void> pause() async {
    if (kIsWeb) return;
    if (playerState.value == TtsPlayerState.playing) {
      var result = await _flutterTts.pause();
      if (result == 1) {
        playerState.value = TtsPlayerState.paused;
      }
    }
  }

  Future<void> restartCurrentItem() async {
    if (kIsWeb) return;
    if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
      final currentItem = _queue[_currentQueueIndex];
      playerState.value = TtsPlayerState.playing;
      final processedText = _preprocessTextForTts(currentItem.textToSpeak);
      await _flutterTts.speak(processedText);
    }
  }

  Future<void> _loadAndSetVoice() async {
    if (kIsWeb) return;
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
    if (kIsWeb) return [];
    try {
      var voices = await _flutterTts.getVoices;
      if (voices is List) {
        return voices
            .where((voice) =>
                voice is Map && _voiceDisplayNames.containsKey(voice['name']))
            .map((voice) => voice as Map<dynamic, dynamic>)
            .toList();
      }
      return [];
    } catch (e) {
      print("TTS Manager: Erro ao obter vozes: $e");
      return [];
    }
  }

  String getVoiceDisplayName(String? rawVoiceName) {
    if (rawVoiceName == null) return 'Voz Desconhecida';
    return _voiceDisplayNames[rawVoiceName] ?? rawVoiceName;
  }

  Future<void> setVoice(Map<dynamic, dynamic> voice) async {
    if (kIsWeb) return;
    try {
      final Map<String, String> voiceToSet =
          voice.map((key, value) => MapEntry(key.toString(), value.toString()));
      await _flutterTts.setVoice(voiceToSet);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ttsVoicePrefsKey, json.encode(voiceToSet));
      print("TTS Manager: Voz '${voice['name']}' definida e salva.");
    } catch (e) {
      print("TTS Manager: Erro ao definir a voz: $e");
    }
  }
}
