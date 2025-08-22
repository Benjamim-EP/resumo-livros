// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Classe utilitária com métodos estáticos para carregar e processar dados da Bíblia a partir dos assets.
///
/// Esta classe foi refatorada para usar injeção de dependência do AssetBundle,
/// permitindo que seja facilmente testada com um bundle falso (mock) sem afetar
/// o funcionamento normal do aplicativo, que continuará usando o `rootBundle` padrão.
class BiblePageHelper {
  // Caches estáticos para evitar recarregar arquivos repetidamente.
  static Map<String, dynamic>? _hebrewStrongsLexicon;
  static Map<String, dynamic>? _greekStrongsLexicon;
  static Map<String, dynamic>? _booksMapCache;
  static final Map<String, List<dynamic>> _firestoreChapterCache = {};

  static const List<String> _firestoreTranslations = [
    'ARA',
    'ARC',
    'AS21',
    'JFAA',
    'NAA',
    'NBV',
    'NTLH',
    'NVT'
  ];

  /// Limpa os caches estáticos. Usado principalmente para garantir o isolamento em testes de unidade.
  @visibleForTesting
  static void clearCache() {
    _booksMapCache = null;
    _hebrewStrongsLexicon = null;
    _greekStrongsLexicon = null;
  }

  static Future<Map<String, String>> loadBookVariationsMapForGoTo(
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    try {
      final String jsonString = await assetBundle
          .loadString('assets/Biblia/book_variations_map_search.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      final Map<String, String> normalizedMap = {};

      String normalizeText(String text) {
        return unorm
            .nfd(text.toLowerCase().trim())
            .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
      }

      decodedJson.forEach((key, value) {
        normalizedMap[normalizeText(key)] = value.toString();
      });
      return normalizedMap;
    } catch (e) {
      print("Erro ao carregar book_variations_map_search.json: $e");
      return {};
    }
  }

  static Future<List<String>> getAllSectionIdsForChapter(
      String bookAbbrev, int chapter,
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final List<String> sectionIds = [];
    try {
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      final String sectionDataString =
          await assetBundle.loadString(sectionStructurePath);
      final List<dynamic> sections = json.decode(sectionDataString);

      for (var section in sections) {
        if (section is Map<String, dynamic>) {
          final List<int> verseNumbers =
              (section['verses'] as List?)?.cast<int>() ?? [];
          if (verseNumbers.isNotEmpty) {
            final String versesRangeStr = verseNumbers.length == 1
                ? verseNumbers.first.toString()
                : "${verseNumbers.first}-${verseNumbers.last}";
            sectionIds.add("${bookAbbrev}_c${chapter}_v$versesRangeStr");
          }
        }
      }
      return sectionIds;
    } catch (e) {
      print("Erro ao obter IDs de seção para $bookAbbrev $chapter: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> loadBooksMap(
      {AssetBundle? bundle}) async {
    if (_booksMapCache != null) {
      return _booksMapCache!;
    }
    final assetBundle = bundle ?? rootBundle;
    final String data = await assetBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    _booksMapCache = json.decode(data);
    return _booksMapCache!;
  }

  static final Map<String, String> _bookNameToAbbrevMap = {
    // (o seu mapa de abreviações permanece aqui, sem alterações)
    'gênesis': 'gn',
    'genesis': 'gn',
    'êxodo': 'ex',
    'exodo': 'ex',
    'levítico': 'lv',
    'levitico': 'lv',
    'números': 'nm',
    'numeros': 'nm',
    'deuteronômio': 'dt',
    'deuteronomio': 'dt',
    'josué': 'js',
    'josue': 'js',
    'juízes': 'jz',
    'juizes': 'jz',
    'rute': 'rt',
    '1 samuel': '1sm',
    '1º samuel': '1sm',
    '2 samuel': '2sm',
    '2º samuel': '2sm',
    '1 reis': '1rs',
    '1º reis': '1rs',
    '2 reis': '2rs',
    '2º reis': '2rs',
    '1 crônicas': '1cr',
    '1 cronicas': '1cr',
    '1º crônicas': '1cr',
    '2 crônicas': '2cr',
    '2 cronicas': '2cr',
    '2º crônicas': '2cr',
    'esdras': 'ed',
    'neemias': 'ne',
    'ester': 'et',
    'jó': 'job',
    'salmos': 'sl',
    'provérbios': 'pv',
    'proverbios': 'pv',
    'eclesiastes': 'ec',
    'cantares': 'ct',
    'cânticos': 'ct',
    'isaías': 'is',
    'isaias': 'is',
    'jeremias': 'jr',
    'lamentações': 'lm',
    'lamentacoes': 'lm',
    'ezequiel': 'ez',
    'daniel': 'dn',
    'oseias': 'os',
    'oséias': 'os',
    'joel': 'jl',
    'amós': 'am',
    'amos': 'am',
    'obadias': 'ob',
    'jonas': 'jn',
    'miqueias': 'mq',
    'miquéias': 'mq',
    'naum': 'na',
    'habacuque': 'hc',
    'sofonias': 'sf',
    'ageu': 'ag',
    'zacarias': 'zc',
    'malaquias': 'ml',
    'mateus': 'mt',
    'marcos': 'mc',
    'lucas': 'lc',
    'joão': 'jo',
    'joao': 'jo',
    'atos': 'at',
    'romanos': 'rm',
    '1 coríntios': '1co',
    '1 corintios': '1co',
    '1º coríntios': '1co',
    '2 coríntios': '2co',
    '2 corintios': '2co',
    '2º coríntios': '2co',
    'gálatas': 'gl',
    'galatas': 'gl',
    'efésios': 'ef',
    'efesios': 'ef',
    'filipenses': 'fp',
    'colossenses': 'cl',
    '1 tessalonicenses': '1ts',
    '1º tessalonicenses': '1ts',
    '2 tessalonicenses': '2ts',
    '2º tessalonicenses': '2ts',
    '1 timóteo': '1tm',
    '1 timoteo': '1tm',
    '1º timóteo': '1tm',
    '2 timóteo': '2tm',
    '2 timoteo': '2tm',
    '2º timóteo': '2tm',
    'tito': 'tt',
    'filemom': 'fm',
    'hebreus': 'hb',
    'tiago': 'tg',
    '1 pedro': '1pe',
    '1º pedro': '1pe',
    '2 pedro': '2pe',
    '2º pedro': '2pe',
    '1 joão': '1jo',
    '1º joão': '1jo',
    '2 joão': '2jo',
    '2º joão': '2jo',
    '3 joão': '3jo',
    '3º joão': '3jo',
    'judas': 'jd',
    'apocalipse': 'ap'
  };

  static String formatReferenceForTts(String reference) {
    return reference.replaceAllMapped(RegExp(r'(\d):(\d)'),
        (match) => '${match.group(1)} versiculo ${match.group(2)}');
  }

  static Future<String> getFullReferenceName(String abbreviatedReference,
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    try {
      final booksMap = await loadBooksMap(bundle: assetBundle);
      final regex = RegExp(r'^(\S+)\s*(.*)$');
      final match = regex.firstMatch(abbreviatedReference.trim());
      if (match != null) {
        final abbrev = match.group(1)?.toLowerCase() ?? '';
        final restOfReference = match.group(2) ?? '';
        if (booksMap.containsKey(abbrev)) {
          final bookName = booksMap[abbrev]?['nome'] ?? abbrev.toUpperCase();
          return '$bookName $restOfReference';
        }
      }
      return abbreviatedReference;
    } catch (e) {
      return abbreviatedReference;
    }
  }

  static Future<Map<String, dynamic>?> loadAndCacheHebrewStrongsLexicon(
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    if (_hebrewStrongsLexicon == null) {
      try {
        final String data = await assetBundle.loadString(
            'assets/Biblia/completa_traducoes/hebrew_strong_lexicon_traduzido.json');
        _hebrewStrongsLexicon = json.decode(data);
      } catch (e) {
        return null;
      }
    }
    return _hebrewStrongsLexicon;
  }

  static Map<String, dynamic>? get cachedHebrewStrongsLexicon =>
      _hebrewStrongsLexicon;

  static Future<Map<String, dynamic>?> loadAndCacheGreekStrongsLexicon(
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    if (_greekStrongsLexicon == null) {
      try {
        final String data = await assetBundle.loadString(
            'assets/Biblia/completa_traducoes/greek_strong_lexicon_traduzido.json');
        _greekStrongsLexicon = json.decode(data);
      } catch (e) {
        return null;
      }
    }
    return _greekStrongsLexicon;
  }

  static String? _getAbbrevFromPortugueseName(String bookName) {
    String normalizedName = unorm
        .nfd(bookName.toLowerCase().trim())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    return _bookNameToAbbrevMap[normalizedName];
  }

  static Future<List<String>> loadVersesFromReference(
      String reference, String translation,
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    if (reference.isEmpty) return ["Referência inválida."];

    final RegExp regex = RegExp(
        r"^\s*([1-3]?\s*[A-Za-zÀ-ÖØ-öø-ÿ]+)\s*(\d+)\s*[:\.]\s*(\d+)(?:\s*-\s*(\d+))?\s*$",
        caseSensitive: false);
    final Match? match = regex.firstMatch(reference.trim());

    if (match == null) return ["Formato de referência inválido: $reference"];

    String bookNamePart = match.group(1)!.trim();
    String chapterStr = match.group(2)!;
    String startVerseStr = match.group(3)!;
    String? endVerseStr = match.group(4);

    String? bookAbbrev;
    final Map<String, dynamic> booksMap =
        await loadBooksMap(bundle: assetBundle);

    final String potentialAbbrev = bookNamePart.toLowerCase();
    if (booksMap.containsKey(potentialAbbrev)) {
      bookAbbrev = potentialAbbrev;
    } else {
      bookAbbrev = _getAbbrevFromPortugueseName(bookNamePart);
    }

    if (bookAbbrev == null) {
      return ["Livro não reconhecido: $bookNamePart"];
    }

    final int? chapter = int.tryParse(chapterStr);
    final int? startVerse = int.tryParse(startVerseStr);
    final int? endVerse =
        endVerseStr != null ? int.tryParse(endVerseStr) : startVerse;

    if (chapter == null ||
        startVerse == null ||
        endVerse == null ||
        endVerse < startVerse) {
      return ["Capítulo/versículo(s) inválido(s) na referência: $reference"];
    }

    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      final String verseDataString =
          await assetBundle.loadString(verseDataPath);
      final List<dynamic> allVersesInChapter = json.decode(verseDataString);
      List<String> resultVerses = [];

      for (int i = startVerse; i <= endVerse; i++) {
        if (i > 0 && i <= allVersesInChapter.length) {
          resultVerses.add("${i} ${allVersesInChapter[i - 1].toString()}");
        } else {
          resultVerses.add("$i [Texto do verso não encontrado]");
        }
      }
      return resultVerses.isNotEmpty
          ? resultVerses
          : ["Versículos não encontrados para: $reference"];
    } catch (e) {
      print(
          "Erro ao carregar o arquivo de versículos para '$reference' (Abbrev: '$bookAbbrev', Cap: '$chapter'): $e");
      return ["Erro ao carregar versículos para: $reference"];
    }
  }

  static Map<String, dynamic>? get cachedGreekStrongsLexicon =>
      _greekStrongsLexicon;

  static Future<Map<String, dynamic>> loadChapterDataComparison(
    String bookAbbrev,
    int chapter,
    String translation1,
    String? translation2, {
    AssetBundle? bundle,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    List<Map<String, dynamic>> sections = [];
    Map<String, dynamic> verseData = {};
    try {
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      final String sectionData =
          await assetBundle.loadString(sectionStructurePath);
      final decodedSectionData = json.decode(sectionData);
      if (decodedSectionData is List) {
        sections = List<Map<String, dynamic>>.from(decodedSectionData
            .map((item) {
              if (item is Map)
                return {
                  'title': item['title']?.toString() ?? 'Seção',
                  'verses':
                      (item['verses'] as List<dynamic>?)?.cast<int>() ?? []
                };
              return null;
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>());
      }
    } catch (e) {
      sections = [];
    }

    try {
      verseData[translation1] = await _loadVerseDataForTranslation(
          bookAbbrev, chapter, translation1,
          bundle: assetBundle);
    } catch (e) {
      return {'sectionStructure': [], 'verseData': {}};
    }

    if (translation2 != null) {
      try {
        verseData[translation2] = await _loadVerseDataForTranslation(
            bookAbbrev, chapter, translation2,
            bundle: assetBundle);
      } catch (e) {
        verseData[translation2] = [];
      }
    }
    return {'sectionStructure': sections, 'verseData': verseData};
  }

  static Future<dynamic> _loadVerseDataForTranslation(
      String bookAbbrev, int chapter, String translation,
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;

    // --- LÓGICA DE DECISÃO ---

    // 1. Verifica se a tradução solicitada está na lista das que vêm do Firestore
    if (_firestoreTranslations.contains(translation.toUpperCase())) {
      // Cria uma chave única para o cache em memória
      final cacheKey = '${translation.toUpperCase()}_${bookAbbrev}_$chapter';

      // Se já estiver no cache, retorna imediatamente para máxima performance
      if (_firestoreChapterCache.containsKey(cacheKey)) {
        print(
            "BiblePageHelper: Carregando '${cacheKey}' do cache do Firestore.");
        return _firestoreChapterCache[cacheKey];
      }

      // Se não estiver no cache, busca no Firestore
      print("BiblePageHelper: Buscando '${cacheKey}' no Firestore...");
      try {
        // Monta o ID do documento como ele está no Firestore (ex: "ARA_gn")
        final docId = '${translation.toUpperCase()}_$bookAbbrev';
        final docSnapshot = await FirebaseFirestore.instance
            .collection('Bible') // Nome da sua coleção principal
            .doc(docId)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          // O campo 'chapters' é um mapa onde a chave é o número do capítulo como String
          final chapters = data?['chapters'] as Map<String, dynamic>? ?? {};
          // Acessa o capítulo específico e garante que é uma lista
          final verseList =
              chapters[chapter.toString()] as List<dynamic>? ?? [];

          // Salva o resultado no cache em memória para futuras solicitações
          _firestoreChapterCache[cacheKey] = verseList;
          print(
              "BiblePageHelper: '${cacheKey}' carregado do Firestore e salvo no cache.");
          return verseList;
        } else {
          print(
              "BiblePageHelper: Documento '$docId' não encontrado no Firestore.");
          _firestoreChapterCache[cacheKey] =
              []; // Salva um resultado vazio no cache para não buscar de novo
          return []; // Retorna lista vazia se não encontrar
        }
      } catch (e) {
        print(
            "BiblePageHelper: ERRO ao buscar capítulo do Firestore para '$cacheKey': $e");
        return []; // Retorna lista vazia em caso de erro de rede, etc.
      }
    }

    // 2. Se a tradução NÃO está na lista do Firestore, executa a lógica antiga de buscar dos assets locais
    else {
      print(
          "BiblePageHelper: Carregando tradução '$translation' dos assets locais...");
      String verseDataPath;

      if (translation == 'hebrew_original') {
        verseDataPath =
            'assets/Biblia/completa_traducoes/hebrew_original/$bookAbbrev/$chapter.json';
      } else if (translation == 'greek_interlinear') {
        verseDataPath =
            'assets/Biblia/completa_traducoes/greek_original/$bookAbbrev/$chapter.json';
      } else {
        // Para NVI, ACF, KJF, etc.
        verseDataPath =
            'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      }

      try {
        final String verseDataString =
            await assetBundle.loadString(verseDataPath);
        final decodedVerseData = json.decode(verseDataString);

        // A lógica de parsing para os tipos especiais (interlinear) permanece a mesma
        if (translation == 'hebrew_original' ||
            translation == 'greek_interlinear') {
          if (decodedVerseData is List) {
            return List<List<Map<String, String>>>.from(decodedVerseData.map(
                (verse) => (verse is List)
                    ? List<Map<String, String>>.from(verse
                        .map((wordData) => (wordData is Map)
                            ? Map<String, String>.from(wordData.map(
                                (key, value) =>
                                    MapEntry(key.toString(), value.toString())))
                            : <String, String>{})
                        .where((map) => map.isNotEmpty))
                    : <List<Map<String, String>>>[]));
          }
        } else {
          // Para traduções normais, apenas retorna a lista de strings
          if (decodedVerseData is List) {
            return List<String>.from(
                decodedVerseData.map((item) => item.toString()));
          }
        }
        // Se o formato não for uma lista, retorna uma lista vazia
        return [];
      } catch (e) {
        print(
            "BiblePageHelper: ERRO ao carregar tradução local '$translation' para $bookAbbrev $chapter: $e");
        return []; // Retorna lista vazia se o arquivo não for encontrado
      }
    }
  }

  static Future<String> loadSingleVerseText(String verseId, String translation,
      {AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    if (translation == 'hebrew_original' ||
        translation == 'greek_interlinear') {
      return "[Visualização interlinear]";
    }
    final parts = verseId.split('_');
    if (parts.length != 3) return "Referência inválida";
    final bookAbbrev = parts[0];
    final chapterForPath = parts[1];
    final verseIndex = int.tryParse(parts[2]);
    if (verseIndex == null) return "Verso inválido";
    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapterForPath.json';
      final String verseDataString =
          await assetBundle.loadString(verseDataPath);
      final decodedVerseData = json.decode(verseDataString);
      if (decodedVerseData is List &&
          verseIndex > 0 &&
          verseIndex <= decodedVerseData.length) {
        return decodedVerseData[verseIndex - 1].toString();
      } else {
        return "[Texto não encontrado]";
      }
    } catch (e) {
      return "[Erro ao carregar]";
    }
  }
}
