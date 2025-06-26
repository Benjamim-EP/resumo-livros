// lib/pages/bible_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import 'package:septima_biblia/pages/biblie_page/bible_navigation_controls.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/pages/biblie_page/bible_options_bar.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/bible_search_filter_bar.dart';
import 'package:septima_biblia/pages/biblie_page/bible_semantic_search_view.dart';
import 'package:septima_biblia/pages/biblie_page/section_item_widget.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ... (todo o código de _BiblePageViewModel e _BibleContentViewModel permanece o mesmo) ...

class _BiblePageViewModel {
  final String? initialBook;
  final int? initialBibleChapter;

  _BiblePageViewModel({
    this.initialBook,
    this.initialBibleChapter,
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    return _BiblePageViewModel(
      initialBook: store.state.userState.initialBibleBook,
      initialBibleChapter: store.state.userState.initialBibleChapter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BiblePageViewModel &&
          runtimeType == other.runtimeType &&
          initialBook == other.initialBook &&
          initialBibleChapter == other.initialBibleChapter;

  @override
  int get hashCode => initialBook.hashCode ^ initialBibleChapter.hashCode;
}

class _BibleContentViewModel {
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final Set<String> readSectionsForCurrentBook;

  _BibleContentViewModel({
    required this.userHighlights,
    required this.userNotes,
    required this.readSectionsForCurrentBook,
  });

  static _BibleContentViewModel fromStore(
      Store<AppState> store, String? currentSelectedBook) {
    return _BibleContentViewModel(
      userHighlights: store.state.userState.userHighlights,
      userNotes: store.state.userState.userNotes,
      readSectionsForCurrentBook: currentSelectedBook != null
          ? store.state.userState.readSectionsByBook[currentSelectedBook] ??
              const {}
          : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BibleContentViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userHighlights, other.userHighlights) &&
          mapEquals(userNotes, other.userNotes) &&
          setEquals(
              readSectionsForCurrentBook, other.readSectionsForCurrentBook);

  @override
  int get hashCode =>
      userHighlights.hashCode ^
      userNotes.hashCode ^
      readSectionsForCurrentBook.hashCode;
}

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  // ... (todo o estado de _BiblePageState permanece o mesmo) ...

  Map<String, dynamic>? booksMap;
  String? selectedBook;
  int? selectedChapter;

  String? _filterSelectedTestament;
  String? _filterSelectedBookAbbrev;
  String? _filterSelectedContentType;

  String selectedTranslation1 = 'nvi';
  String? selectedTranslation2 = 'acf';
  bool _isCompareModeActive = false;
  bool _isFocusModeActive = false;
  final FirestoreService _firestoreService = FirestoreService();

  String? _expandedItemId;
  String? _loadedExpandedContent;
  bool _isLoadingExpandedContent = false;

  // Hebraico Interlinear
  bool _showHebrewInterlinear = false;
  Map<String, dynamic>? _currentChapterHebrewData;

  // Grego Interlinear - NOVO
  bool _showGreekInterlinear = false;
  Map<String, dynamic>? _currentChapterGreekData;

  String? _lastRecordedHistoryRef;
  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};

  late ValueKey _futureBuilderKey;
  bool _hasProcessedInitialNavigation = false;

  bool _isSemanticSearchActive = false;
  final TextEditingController _semanticQueryController =
      TextEditingController();
  bool _showExtraOptions = false;

  final List<Map<String, String>> _tiposDeConteudoDisponiveisParaFiltro = [
    {'value': 'biblia_comentario_secao', 'display': 'Comentário da Seção'},
    {'value': 'biblia_versiculos', 'display': 'Versículos Bíblicos'},
  ];

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  bool _isSyncingScroll = false;

  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  Store<AppState>? _store;

  double _currentFontSizeMultiplier =
      1.0; // 1.0 = normal, <1.0 = menor, >1.0 = maior
  static const double MIN_FONT_MULTIPLIER = 0.8;
  static const double MAX_FONT_MULTIPLIER = 1.6;
  static const double FONT_STEP = 0.1;
  static const String FONT_SIZE_PREF_KEY = 'bible_font_size_multiplier';

  String?
      _sectionIdToScrollAfterLoad; // NOVO: Para armazenar o ID da seção alvo
  final Map<String, GlobalKey> _sectionItemKeys =
      {}; // NOVO: Para armazenar GlobalKeys das seções

  final TtsManager _ttsManager = TtsManager();
// NOVOS ESTADOS PARA GERENCIAR A FILA E O PLAYER
  final List<TtsQueueItem> _ttsQueue = [];
  int _currentTtsQueueIndex = -1;
  TtsPlayerState _currentPlayerState = TtsPlayerState.stopped;
  String? _currentlyPlayingSectionId;
  TtsContentType? _currentlyPlayingContentType;

  @override
  void initState() {
    _loadFontSizePreference();
    super.initState();
    _updateFutureBuilderKey(isInitial: true); // Chamar com isInitial
    _loadInitialData();
    _scrollController1.addListener(_syncScrollFrom1To2);
    _scrollController2.addListener(_syncScrollFrom2To1);

    _ttsManager.playerState.addListener(_onTtsStateChanged);
    //_ttsManager.onComplete =
    //_playNextInQueue; // Define o callback para continuar a fila
  }

  void _navigateToVerseFromSearch(String bookAbbrev, int chapter) {
    if (mounted) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(RequestBottomNavChangeAction(1));
    }
  }

  Future<void> _loadFontSizePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentFontSizeMultiplier = prefs.getDouble(FONT_SIZE_PREF_KEY) ?? 1.0;
      // Atualiza a chave do FutureBuilder se a fonte mudar na inicialização,
      // para que os itens já renderizados (se houver) usem a nova fonte.
      _updateFutureBuilderKey();
    });
  }

// Nova função para salvar a preferência de tamanho da fonte
  Future<void> _saveFontSizePreference(double multiplier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(FONT_SIZE_PREF_KEY, multiplier);
  }

  void _increaseFontSize() {
    if (_currentFontSizeMultiplier < MAX_FONT_MULTIPLIER) {
      setState(() {
        _currentFontSizeMultiplier = (_currentFontSizeMultiplier + FONT_STEP)
            .clamp(MIN_FONT_MULTIPLIER, MAX_FONT_MULTIPLIER);
        _saveFontSizePreference(_currentFontSizeMultiplier);
        _updateFutureBuilderKey(); // Força a reconstrução do conteúdo com a nova fonte
      });
    }
  }

  void _decreaseFontSize() {
    if (_currentFontSizeMultiplier > MIN_FONT_MULTIPLIER) {
      setState(() {
        _currentFontSizeMultiplier = (_currentFontSizeMultiplier - FONT_STEP)
            .clamp(MIN_FONT_MULTIPLIER, MAX_FONT_MULTIPLIER);
        _saveFontSizePreference(_currentFontSizeMultiplier);
        _updateFutureBuilderKey(); // Força a reconstrução
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) {
      _store = StoreProvider.of<AppState>(context);
      final initialFilters = _store!.state.bibleSearchState.activeFilters;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _filterSelectedTestament = initialFilters['testamento'] as String?;
            _filterSelectedBookAbbrev =
                initialFilters['livro_curto'] as String?;
            _filterSelectedContentType = initialFilters['tipo'] as String?;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _semanticQueryController.dispose();
    _scrollController1.removeListener(_syncScrollFrom1To2);
    _scrollController2.removeListener(_syncScrollFrom2To1);
    _scrollController1.dispose();
    _scrollController2.dispose();

    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.onComplete = null;
    _ttsManager.stop();

    if (_store != null) {
      final userState = _store!.state.userState;
      if (userState.userId != null) {
        final pendingToAdd = userState.pendingSectionsToAdd;
        final pendingToRemove = userState.pendingSectionsToRemove;
        if (pendingToAdd.isNotEmpty || pendingToRemove.isNotEmpty) {
          _store!.dispatch(ProcessPendingBibleProgressAction());
        }
      }
      if (userState.pendingFirestoreWrites.isNotEmpty) {
        _store!.dispatch(ProcessPendingFirestoreWritesAction());
      }
    }
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (!mounted) return;
    final newPlayerState = _ttsManager.playerState.value;
    if (_currentPlayerState != newPlayerState) {
      setState(() {
        _currentPlayerState = newPlayerState;
        // Se a reprodução parou completamente, limpa o ID da seção
        if (newPlayerState == TtsPlayerState.stopped) {
          _currentlyPlayingSectionId = null;
          _currentlyPlayingContentType = null;
        }
      });
    }
  }

  /// Limpa a fila e para a reprodução.
  void _stopAndClearTtsQueue() {
    _ttsManager.stop();
    setState(() {
      _ttsQueue.clear();
      _currentTtsQueueIndex = -1;
      _currentlyPlayingSectionId = null;
      _currentlyPlayingContentType = null;
    });
  }

  /// Lida com cliques nos botões de áudio do SectionItemWidget.
  void _handlePlayRequest(String sectionId, TtsContentType contentType) {
    final isPlayingThisExactItem = _currentlyPlayingSectionId == sectionId &&
        _currentlyPlayingContentType == contentType;

    switch (_currentPlayerState) {
      case TtsPlayerState.stopped:
        _startNewPlayback(sectionId, contentType);
        break;
      case TtsPlayerState.playing:
        if (isPlayingThisExactItem) {
          _ttsManager.pause();
        } else {
          // Se está tocando outra coisa, para e inicia a nova.
          _startNewPlayback(sectionId, contentType);
        }
        break;
      case TtsPlayerState.paused:
        if (isPlayingThisExactItem) {
          // Se o clique foi no mesmo item que está pausado, continua.
          _ttsManager.restartCurrentItem();
        } else {
          // Se estava pausado e clicou em outro, inicia o novo.
          _startNewPlayback(sectionId, contentType);
        }
        break;
    }
  }

  void _startNewPlayback(
      String startSectionId, TtsContentType contentType) async {
    // Para qualquer reprodução anterior e limpa o estado visual.
    await _ttsManager.stop();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Preparando áudio..."), duration: Duration(seconds: 15)));

    try {
      final chapterData = await BiblePageHelper.loadChapterDataComparison(
          selectedBook!, selectedChapter!, selectedTranslation1, null);
      final List<Map<String, dynamic>> sections =
          List.from(chapterData['sectionStructure'] ?? []);
      final dynamic verseData = chapterData['verseData']?[selectedTranslation1];

      if (sections.isEmpty || verseData == null || verseData is! List<String>) {
        throw Exception("Dados do capítulo inválidos.");
      }

      List<TtsQueueItem> fullChapterQueue = [];

      List<String> splitTextIntoSentences(String text) {
        String sanitizedText = text
            .replaceAll(RegExp(r'\s{2,}', multiLine: true), ' ')
            .replaceAll(RegExp(r'\n'), ' ')
            .trim();

        if (sanitizedText.isEmpty) {
          return [];
        }

        List<String> sentences = sanitizedText.split(RegExp(r'(?<=[.?!])\s*'));

        final List<String> finalChunks = [];
        const int maxLength = 3500;

        for (var sentence in sentences) {
          if (sentence.length > maxLength) {
            for (var i = 0; i < sentence.length; i += maxLength) {
              final end = (i + maxLength > sentence.length)
                  ? sentence.length
                  : i + maxLength;
              finalChunks.add(sentence.substring(i, end));
            }
          } else if (sentence.trim().isNotEmpty) {
            finalChunks.add(sentence);
          }
        }
        return finalChunks;
      }

      for (var section in sections) {
        final List<int> verseNumbers =
            (section['verses'] as List?)?.cast<int>() ?? [];
        final String versesRangeForId = verseNumbers.isNotEmpty
            ? (verseNumbers.length == 1
                ? verseNumbers.first.toString()
                : "${verseNumbers.first}-${verseNumbers.last}")
            : "all";
        final String currentSectionId =
            "${selectedBook}_c${selectedChapter}_v$versesRangeForId";

        final String sectionTitle = section['title'] ?? '';
        if (sectionTitle.isNotEmpty) {
          fullChapterQueue.add(TtsQueueItem(
              sectionId: currentSectionId, textToSpeak: sectionTitle));
        }

        // >>> INÍCIO DA LÓGICA MODIFICADA PARA VERSÍCULOS <<<
        for (int i = 0; i < verseNumbers.length; i++) {
          int verseNum = verseNumbers[i];
          if (verseNum > 0 && verseNum <= verseData.length) {
            final verseText = verseData[verseNum - 1];
            String textToSpeak;

            // Se for o primeiro versículo da seção (i == 0), adiciona "Versículo".
            if (i == 0) {
              textToSpeak = "Versículo $verseNum. $verseText";
            } else {
              // Para os demais, apenas o número.
              textToSpeak = "$verseNum. $verseText";
            }

            fullChapterQueue.add(TtsQueueItem(
                sectionId: currentSectionId, textToSpeak: textToSpeak));
          }
        }
        // >>> FIM DA LÓGICA MODIFICADA PARA VERSÍCULOS <<<

        if (contentType == TtsContentType.versesAndCommentary) {
          final String versesRangeStr = verseNumbers.isNotEmpty
              ? (verseNumbers.length == 1
                  ? verseNumbers.first.toString()
                  : "${verseNumbers.first}-${verseNumbers.last}")
              : "all_verses_in_section";
          String abbrevForFirestore = selectedBook!;
          if (selectedBook!.toLowerCase() == 'job') {
            abbrevForFirestore = 'jó';
          }
          final commentaryDocId =
              "${abbrevForFirestore}_c${selectedChapter}_v$versesRangeStr";
          final commentaryData =
              await _firestoreService.getSectionCommentary(commentaryDocId);
          if (commentaryData != null && commentaryData['commentary'] is List) {
            final commentaryList = commentaryData['commentary'] as List;
            if (commentaryList.isNotEmpty) {
              fullChapterQueue.add(TtsQueueItem(
                  sectionId: currentSectionId,
                  textToSpeak: "Comentário da seção."));

              for (var item in commentaryList) {
                final text = (item as Map)['traducao']?.trim() ??
                    (item as Map)['original']?.trim() ??
                    '';
                if (text.isNotEmpty) {
                  final textSentences = splitTextIntoSentences(text);
                  for (var sentence in textSentences) {
                    String trimmedSentence = sentence.trim();
                    final RegExp listMarkerRegex =
                        RegExp(r'^(?:\d+|[IVXLCDM]+)\.$');
                    final RegExp bibleRefRegex = RegExp(r'[A-Za-z]+\s*\d+:\d+');

                    if (listMarkerRegex.hasMatch(trimmedSentence) &&
                        !bibleRefRegex.hasMatch(trimmedSentence)) {
                      print(
                          "TTS Queue: Ignorando marcador de lista: '$trimmedSentence'");
                      continue;
                    }

                    fullChapterQueue.add(TtsQueueItem(
                        sectionId: currentSectionId, textToSpeak: sentence));
                  }
                }
              }
            }
          }
        }
      }

      print("TTS Queue gerada com ${fullChapterQueue.length} itens.");
      for (int i = 0; i < fullChapterQueue.length; i++) {
        print(
            "Item $i (${fullChapterQueue[i].sectionId}): '${fullChapterQueue[i].textToSpeak}'");
      }

      setState(() {
        _currentlyPlayingSectionId = startSectionId;
        _currentlyPlayingContentType = contentType;
      });

      _ttsManager.speak(fullChapterQueue, startSectionId);
    } catch (e) {
      print("Erro em _startNewPlayback: $e");
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    }
  }

  Future<void> _loadCurrentChapterHebrewDataIfNeeded() async {
    if (selectedBook != null &&
        selectedChapter != null &&
        _showHebrewInterlinear &&
        (booksMap?[selectedBook]?['testament'] == 'Antigo')) {
      if (_currentChapterHebrewData != null &&
          _currentChapterHebrewData!['book'] == selectedBook &&
          _currentChapterHebrewData!['chapter'] == selectedChapter) {
        return;
      }
      try {
        final hebrewData = await BiblePageHelper.loadChapterDataComparison(
            selectedBook!, selectedChapter!, 'hebrew_original', null);
        if (mounted) {
          setState(() {
            _currentChapterHebrewData = {
              'book': selectedBook,
              'chapter': selectedChapter,
              'data': hebrewData['verseData']?['hebrew_original']
            };
          });
        }
      } catch (e) {
        if (mounted) setState(() => _currentChapterHebrewData = null);
      }
    } else if (!_showHebrewInterlinear && _currentChapterHebrewData != null) {
      if (mounted) setState(() => _currentChapterHebrewData = null);
    }
  }

  // <<< NOVA FUNÇÃO PARA CARREGAR DADOS DO GREGO INTERLINEAR >>>
  Future<void> _loadCurrentChapterGreekDataIfNeeded() async {
    if (selectedBook != null &&
        selectedChapter != null &&
        _showGreekInterlinear && // Usa a flag do grego
        (booksMap?[selectedBook]?['testament'] == 'Novo')) {
      // Verifica se é NT
      if (_currentChapterGreekData != null &&
          _currentChapterGreekData!['book'] == selectedBook &&
          _currentChapterGreekData!['chapter'] == selectedChapter) {
        return; // Já carregado
      }
      try {
        // Carrega usando a chave 'greek_interlinear'
        final greekData = await BiblePageHelper.loadChapterDataComparison(
            selectedBook!, selectedChapter!, 'greek_interlinear', null);
        if (mounted) {
          setState(() {
            _currentChapterGreekData = {
              'book': selectedBook,
              'chapter': selectedChapter,
              'data': greekData['verseData']?['greek_interlinear']
            };
          });
        }
      } catch (e) {
        if (mounted) setState(() => _currentChapterGreekData = null);
      }
    } else if (!_showGreekInterlinear && _currentChapterGreekData != null) {
      // Limpa se não for mais para mostrar
      if (mounted) setState(() => _currentChapterGreekData = null);
    }
  }

  void _syncScrollFrom1To2() {
    if (_isSyncingScroll ||
        !_scrollController1.hasClients ||
        !_scrollController2.hasClients) return;
    _isSyncingScroll = true;
    if (_scrollController2.offset != _scrollController1.offset) {
      _scrollController2.jumpTo(_scrollController1.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  void _syncScrollFrom2To1() {
    if (_isSyncingScroll ||
        !_scrollController1.hasClients ||
        !_scrollController2.hasClients) return;
    _isSyncingScroll = true;
    if (_scrollController1.offset != _scrollController2.offset) {
      _scrollController1.jumpTo(_scrollController2.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  String _normalizeSearchText(String text) {
    // ... (sem alterações)
    String normalized = text.toLowerCase();
    const Map<String, String> accentMap = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accentMap.forEach(
        (key, value) => normalized = normalized.replaceAll(key, value));
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _loadInitialData() async {
    final generalBooksMap = await BiblePageHelper.loadBooksMap();
    if (mounted) setState(() => booksMap = generalBooksMap);
    await _loadBookVariationsMapForGoTo();
    await BiblePageHelper.loadAndCacheHebrewStrongsLexicon();
    await BiblePageHelper
        .loadAndCacheGreekStrongsLexicon(); // <<< CARREGA LÉXICO GREGO
  }

  Future<void> _loadBookVariationsMapForGoTo() async {
    // ... (sem alterações)
    try {
      final String jsonString = await rootBundle
          .loadString('assets/Biblia/book_variations_map_search.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      final Map<String, String> normalizedMap = {};
      decodedJson.forEach((key, value) =>
          normalizedMap[_normalizeSearchText(key)] = value.toString());
      if (mounted) setState(() => _bookVariationsMap = normalizedMap);
    } catch (e) {
      if (mounted) setState(() => _bookVariationsMap = {});
    }
  }

  // Adicionado parâmetro opcional `isInitial`
  void _updateFutureBuilderKey({bool isInitial = false}) {
    if (mounted) {
      final keySuffix = isInitial ? '-initial' : '-updated';
      setState(() {
        _futureBuilderKey = ValueKey(
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-$_selectedBookSlug-${_showHebrewInterlinear}-${_showGreekInterlinear}-${_currentFontSizeMultiplier}$keySuffix'); // <<< ADICIONADO _currentFontSizeMultiplier
      });
    }
  }

  void _applyNavigationState(String book, int chapter,
      {bool forceKeyUpdate = false}) {
    if (!mounted) return;

    // <<< INÍCIO DA CORREÇÃO <<<
    // A condição mais importante: a navegação só acontece se o livro ou capítulo MUDOU.
    bool bookOrChapterChanged =
        selectedBook != book || selectedChapter != chapter;

    if (!bookOrChapterChanged && !forceKeyUpdate) {
      // Se nada mudou e não estamos forçando uma atualização, não fazemos nada.
      // Isso quebra o loop de reconstrução.
      return;
    }
    // >>> FIM DA CORREÇÃO <<<

    // O resto da lógica da função já verifica 'bookOrChapterChanged' para a maioria das coisas.
    // A adição da guarda no início é a camada extra de segurança.

    // Se o livro mudou
    if (selectedBook != book) {
      final newBookData = booksMap?[book] as Map<String, dynamic>?;

      if (newBookData?['testament'] != 'Antigo') {
        if (selectedTranslation1 == 'hebrew_original') {
          if (mounted) setState(() => selectedTranslation1 = 'nvi');
        }
        if (_isCompareModeActive && selectedTranslation2 == 'hebrew_original') {
          if (mounted) setState(() => selectedTranslation2 = 'acf');
        }
        if (_showHebrewInterlinear) {
          if (mounted) setState(() => _showHebrewInterlinear = false);
        }
      }

      if (newBookData?['testament'] != 'Novo') {
        if (selectedTranslation1 == 'greek_interlinear') {
          if (mounted) setState(() => selectedTranslation1 = 'nvi');
        }
        if (_isCompareModeActive &&
            selectedTranslation2 == 'greek_interlinear') {
          if (mounted) setState(() => selectedTranslation2 = 'acf');
        }
        if (_showGreekInterlinear) {
          if (mounted) setState(() => _showGreekInterlinear = false);
        }
      }
    }

    if (bookOrChapterChanged) {
      if (mounted) {
        setState(() {
          selectedBook = book;
          selectedChapter = chapter;
          _currentChapterHebrewData = null;
          _currentChapterGreekData = null;
          _updateSelectedBookSlug();
          if (_showHebrewInterlinear) _loadCurrentChapterHebrewDataIfNeeded();
          if (_showGreekInterlinear) _loadCurrentChapterGreekDataIfNeeded();
        });
      }
    }

    if (bookOrChapterChanged || forceKeyUpdate) {
      _updateFutureBuilderKey();
      _recordHistory(book,
          chapter); // _recordHistory já tem uma guarda interna, mas agora será chamado com menos frequência.
    }
  }

  Future<void> _showVoiceSelectionDialog() async {
    final theme = Theme.of(context);
    final availableVoices = await _ttsManager.getAvailableVoices();
    if (!mounted) return;
    if (availableVoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Nenhuma voz em Português (Brasil) encontrada.")));
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Selecionar Voz",
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableVoices.length,
              itemBuilder: (context, index) {
                final voice = availableVoices[index];
                final voiceName =
                    voice['name'] as String? ?? 'Voz Desconhecida';
                final displayName = voiceName
                    .split('#')
                    .last
                    .replaceAll('_', ' ')
                    .replaceFirst('-', ' ');
                return ListTile(
                  title: Text(displayName,
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    _ttsManager.setVoice(voice);
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Voz alterada para: $displayName")));
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancelar",
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _toggleItemExpansionInBiblePage(
      Map<String, dynamic> metadata, String itemId) async {
    if (!mounted) return; // Adiciona verificação

    if (_expandedItemId == itemId) {
      setState(() {
        _expandedItemId = null;
        _loadedExpandedContent = null;
        _isLoadingExpandedContent = false; // Garante que o loading para
      });
    } else {
      setState(() {
        _expandedItemId = itemId;
        _isLoadingExpandedContent = true;
        _loadedExpandedContent = null;
      });
      final content = await _fetchDetailedContentForBiblePage(metadata, itemId);
      if (mounted && _expandedItemId == itemId) {
        // Verifica se ainda é o mesmo item expandido
        setState(() {
          _loadedExpandedContent = content;
          _isLoadingExpandedContent = false;
        });
      } else if (mounted && _expandedItemId != itemId) {
        // Se o usuário clicou em outro item enquanto este carregava, não faz nada com o conteúdo antigo.
        // Se o item foi colapsado (_expandedItemId == null) enquanto carregava
        if (_isLoadingExpandedContent && _expandedItemId == null) {
          setState(() => _isLoadingExpandedContent = false);
        }
      }
    }
  }

  Future<String> _fetchDetailedContentForBiblePage(
      Map<String, dynamic> metadata, String itemIdFromSearch) async {
    final tipo = metadata['tipo'] as String?;
    String? bookAbbrevFromMeta = metadata['livro_curto'] as String?;
    final chapterStr = metadata['capitulo']?.toString();
    final versesRange = metadata['versiculos'] as String?;

    print(
        "Fetching detailed content for BiblePage - itemIdFromSearch: $itemIdFromSearch, tipo: $tipo, bookFromMeta: $bookAbbrevFromMeta, chapter: $chapterStr, verses: $versesRange");

    if (tipo == 'biblia_versiculos' &&
        bookAbbrevFromMeta != null &&
        chapterStr != null &&
        versesRange != null) {
      // Lógica para buscar versículos (permanece a mesma)
      try {
        // ... (código de busca de versículos como na versão anterior) ...
        final List<String> versesContent = [];
        final int? chapterInt = int.tryParse(chapterStr);
        if (chapterInt == null) return "Erro: Capítulo inválido.";

        final chapterDataMap = await BiblePageHelper.loadChapterDataComparison(
          bookAbbrevFromMeta,
          chapterInt,
          'nvi',
          null,
        );
        final dynamic nviVerseListData = chapterDataMap['verseData']?['nvi'];

        if (nviVerseListData != null && nviVerseListData is List) {
          final List<String> nviVerseList =
              nviVerseListData.map((e) => e.toString()).toList();
          List<int> verseNumbersToLoad = [];
          if (versesRange.contains('-')) {
            final parts = versesRange.split('-');
            if (parts.length == 2) {
              final start = int.tryParse(parts[0]);
              final end = int.tryParse(parts[1]);
              if (start != null && end != null && start <= end) {
                for (int i = start; i <= end; i++) verseNumbersToLoad.add(i);
              }
            }
          } else {
            final singleVerse = int.tryParse(versesRange);
            if (singleVerse != null) verseNumbersToLoad.add(singleVerse);
          }
          if (verseNumbersToLoad.isEmpty)
            return "Intervalo de versículos inválido: $versesRange";
          for (int vn in verseNumbersToLoad) {
            if (vn > 0 && vn <= nviVerseList.length) {
              versesContent.add("**$vn** ${nviVerseList[vn - 1]}");
            } else {
              versesContent.add("**$vn** [Texto não disponível na NVI]");
            }
          }
          return versesContent.isNotEmpty
              ? versesContent.join("\n\n")
              : "Texto dos versículos não encontrado.";
        } else {
          return "Dados dos versículos NVI não encontrados.";
        }
      } catch (e, s) {
        print(
            "Erro ao carregar versículos para $itemIdFromSearch: $e\nStack: $s");
        return "Erro ao carregar versículos.";
      }
    } else if (tipo == 'biblia_comentario_secao') {
      String docIdToFetch = itemIdFromSearch;

      // 1. Remove o sufixo '_bc' se ele existir no ID vindo da busca
      if (docIdToFetch.endsWith('_bc')) {
        docIdToFetch = docIdToFetch.substring(0, docIdToFetch.length - 3);
        print(
            "BiblePage _fetchDetailedContent: Sufixo '_bc' removido. ID agora: $docIdToFetch");
      }

      // 2. Corrige a abreviação de Jó se necessário (de 'job_' para 'jó_')
      //    Isso deve ser feito DEPOIS de remover o _bc, caso a busca retorne algo como 'job_c1_v1-5_bc'
      //    Especialmente se bookAbbrevFromMeta vier como 'job' e o itemIdFromSearch também.
      if (bookAbbrevFromMeta != null &&
          bookAbbrevFromMeta.toLowerCase() == 'job') {
        if (docIdToFetch.startsWith('job_')) {
          docIdToFetch = docIdToFetch.replaceFirst('job_', 'jó_');
          print(
              "BiblePage _fetchDetailedContent: ID de comentário para Jó ajustado para Firestore: $docIdToFetch (original da busca: $itemIdFromSearch)");
        }
      }

      print(
          "BiblePage _fetchDetailedContent: Tentando buscar comentário com Doc ID final: $docIdToFetch");

      try {
        final commentaryData =
            await _firestoreService.getSectionCommentary(docIdToFetch);

        if (commentaryData != null && commentaryData['commentary'] is List) {
          final List<dynamic> commentsRaw = commentaryData['commentary'];
          if (commentsRaw.isEmpty)
            return "Nenhum comentário disponível para esta seção.";
          final List<String> commentsText = commentsRaw
              .map((c) =>
                  (c is Map<String, dynamic>
                      ? (c['traducao'] as String?)?.trim() ??
                          (c['original'] as String?)?.trim()
                      : c.toString().trim()) ??
                  "")
              .where((text) => text.isNotEmpty)
              .toList();
          if (commentsText.isEmpty) return "Comentário com texto vazio.";
          return commentsText.join("\n\n---\n\n");
        }
        print(
            "Comentário não encontrado ou em formato inválido para a seção: $docIdToFetch");
        return "Comentário não encontrado para a seção.";
      } catch (e, s) {
        print(
            "Erro ao carregar comentário para $itemIdFromSearch (tentativa com docId: $docIdToFetch): $e\nStack: $s");
        return "Erro ao carregar comentário.";
      }
    }
    print("Tipo de conteúdo desconhecido ou dados insuficientes: $tipo");
    return "Detalhes não disponíveis para este tipo de conteúdo.";
  }

  void _processIntentOrInitialLoad(_BiblePageViewModel vm) {
    if (!mounted || booksMap == null) {
      print(
          "BiblePage: _processIntentOrInitialLoad - Abortando: widget não montado ou booksMap nulo.");
      return;
    }

    String targetBook;
    int targetChapter;
    bool isFromIntent = false;

    if (vm.initialBook != null && vm.initialBibleChapter != null) {
      targetBook = vm.initialBook!;
      targetChapter = vm.initialBibleChapter!;
      isFromIntent = true;
      print(
          "BiblePage: _processIntentOrInitialLoad - Navegação via intent: Livro: $targetBook, Cap: $targetChapter");
    } else {
      // Carregamento inicial ou retorno à aba sem intent específica
      // >>> INÍCIO DA CORREÇÃO <<<
      // Pega a última leitura diretamente do estado do Redux, em vez do ViewModel
      final store = StoreProvider.of<AppState>(context, listen: false);
      targetBook =
          store.state.userState.lastReadBookAbbrev ?? selectedBook ?? 'gn';
      targetChapter =
          store.state.userState.lastReadChapter ?? selectedChapter ?? 1;
      // >>> FIM DA CORREÇÃO <<<
      print(
          "BiblePage: _processIntentOrInitialLoad - Carregamento normal/última leitura: Livro: $targetBook, Cap: $targetChapter");
    }

    // O resto da função permanece igual...
    if (booksMap!.containsKey(targetBook)) {
      final bookData = booksMap![targetBook];
      final int totalChaptersInBook = (bookData['capitulos'] as int?) ?? 0;
      if (targetChapter < 1 ||
          (totalChaptersInBook > 0 && targetChapter > totalChaptersInBook)) {
        print(
            "BiblePage: _processIntentOrInitialLoad - Capítulo $targetChapter inválido para $targetBook (total: $totalChaptersInBook). Resetando para 1.");
        targetChapter = 1;
      }
    } else {
      print(
          "BiblePage: _processIntentOrInitialLoad - Livro $targetBook não encontrado. Resetando para Gênesis 1.");
      targetBook = 'gn';
      targetChapter = 1;
    }

    _applyNavigationState(targetBook, targetChapter,
        forceKeyUpdate: isFromIntent);

    if (!_hasProcessedInitialNavigation &&
        selectedBook != null &&
        selectedChapter != null) {
      _hasProcessedInitialNavigation = true;
      print(
          "BiblePage: _processIntentOrInitialLoad - _hasProcessedInitialNavigation = true. Carregando dados do usuário.");
      _loadUserDataIfNeeded(context);
    }
    print(
        "BiblePage: _processIntentOrInitialLoad - Finalizado. selectedBook: $selectedBook, selectedChapter: $selectedChapter, _sectionIdToScrollAfterLoad: $_sectionIdToScrollAfterLoad");
  }

  void _loadUserDataIfNeeded(BuildContext context) {
    // ... (sem alterações)
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (store.state.userState.userId != null &&
        store.state.userState.readSectionsByBook.isEmpty) {
      store.dispatch(LoadAllBibleProgressAction());
    }
  }

  void _updateSelectedBookSlug() {
    // ... (sem alterações)
    if (selectedBook != null &&
        booksMap != null &&
        booksMap![selectedBook] != null) {
      _selectedBookSlug = booksMap![selectedBook]?['slug'] as String?;
    } else {
      _selectedBookSlug = null;
    }
  }

  void _recordHistory(String bookAbbrev, int chapter) {
    final currentRef = "${bookAbbrev}_$chapter";
    if (_lastRecordedHistoryRef != currentRef) {
      if (mounted) {
        // Obtém o nome do livro do mapa local em vez de chamar o FirestoreService
        String bookNameForHistory = bookAbbrev.toUpperCase(); // Fallback
        if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
          // booksMap é o seu _localBooksMap
          bookNameForHistory =
              booksMap![bookAbbrev]?['nome'] ?? bookAbbrev.toUpperCase();
        }

        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(RecordReadingHistoryAction(
          bookAbbrev,
          chapter,
          // bookName: bookNameForHistory, // << Passar o nome para a ação se ela precisar
        ));
        // Nota: A ação RecordReadingHistoryAction no middleware precisará ser ajustada
        // para aceitar bookName ou obtê-lo de forma diferente se o FirestoreService não for mais a fonte.
        // Por enquanto, focaremos em fazer a BiblePage não chamar o getBookNameFromAbbrev do Firestore.
      }
      _lastRecordedHistoryRef = currentRef;
    }
  }

  void _navigateToChapter(String bookAbbrev, int chapter) {
    _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
  }

  void _previousChapter() {
    // ... (sem alterações na lógica principal, _applyNavigationState cuida das flags interlineares)
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    String newBookAbbrev = selectedBook!;
    int newChapter = selectedChapter!;
    if (selectedChapter! > 1) {
      newChapter = selectedChapter! - 1;
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex > 0) {
        newBookAbbrev = bookKeys[currentBookIndex - 1];
        newChapter = booksMap![newBookAbbrev]['capitulos'] as int;
      } else {
        return;
      }
    }
    _applyNavigationState(newBookAbbrev, newChapter, forceKeyUpdate: true);
  }

  void _nextChapter() {
    // ... (sem alterações na lógica principal, _applyNavigationState cuida das flags interlineares)
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    String newBookAbbrev = selectedBook!;
    int newChapter = selectedChapter!;
    int totalChaptersInCurrentBook =
        booksMap![selectedBook!]['capitulos'] as int;
    if (selectedChapter! < totalChaptersInCurrentBook) {
      newChapter = selectedChapter! + 1;
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex < bookKeys.length - 1) {
        newBookAbbrev = bookKeys[currentBookIndex + 1];
        newChapter = 1;
      } else {
        return;
      }
    }
    _applyNavigationState(newBookAbbrev, newChapter, forceKeyUpdate: true);
  }

  Future<void> _showGoToDialog() async {
    // ... (sem alterações)
    final TextEditingController controller = TextEditingController();
    String? errorTextInDialog;
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(builder: (sfbContext, setDialogState) {
            final theme = Theme.of(sfbContext);
            return AlertDialog(
              backgroundColor: theme.dialogBackgroundColor,
              title: Text("Ir para Referência",
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: controller,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                      hintText: "Ex: Gn 1 ou João 3:16",
                      errorText: errorTextInDialog),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _parseAndNavigateForGoTo(
                      value, dialogContext, (newError) {
                    if (mounted)
                      setDialogState(() => errorTextInDialog = newError);
                  }),
                ),
                const SizedBox(height: 8),
                Text("Formatos: Livro Cap ou Livro Cap:Ver",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12)),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text("Cancelar",
                        style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)))),
                TextButton(
                    onPressed: () => _parseAndNavigateForGoTo(
                            controller.text, dialogContext, (newError) {
                          if (mounted)
                            setDialogState(() => errorTextInDialog = newError);
                        }),
                    child: Text("Ir",
                        style: TextStyle(color: theme.colorScheme.primary))),
              ],
            );
          });
        });
  }

  void _parseAndNavigateForGoTo(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    // ... (sem alterações)
    String userInput = input.trim();
    if (userInput.isEmpty) {
      updateErrorText("Digite uma referência.");
      return;
    }
    String normalizedUserInput = _normalizeSearchText(userInput);
    String? foundBookAbbrev;
    String remainingInputForChapterAndVerse = "";
    List<String> sortedVariationKeys = _bookVariationsMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (String normalizedVariationKeyInMap in sortedVariationKeys) {
      if (normalizedUserInput.startsWith(normalizedVariationKeyInMap)) {
        foundBookAbbrev = _bookVariationsMap[normalizedVariationKeyInMap];
        remainingInputForChapterAndVerse = normalizedUserInput
            .substring(normalizedVariationKeyInMap.length)
            .trim();
        if (normalizedVariationKeyInMap == "jo" &&
            (userInput.toLowerCase().startsWith("jó") ||
                userInput.toLowerCase().startsWith("job"))) {
          if (_bookVariationsMap.containsValue("job")) {
            bool isPotentiallyJob = _bookVariationsMap.entries.any((e) =>
                (e.key == "jó" ||
                    e.key == "job" ||
                    e.key == "jo com acento circunflexo" ||
                    e.key == "jô") &&
                e.value == "job");
            if (isPotentiallyJob && foundBookAbbrev == "jo")
              foundBookAbbrev = "job";
          }
        }
        break;
      }
    }
    if (foundBookAbbrev == null) {
      updateErrorText(
          "Livro não reconhecido. Verifique o nome e tente novamente.");
      return;
    }
    final RegExp chapVerseRegex =
        RegExp(r"^\s*(\d+)\s*(?:[:\.]\s*(\d+)(?:\s*-\s*(\d+))?)?\s*$");
    final Match? cvMatch =
        chapVerseRegex.firstMatch(remainingInputForChapterAndVerse);
    if (cvMatch == null || cvMatch.group(1) == null) {
      updateErrorText(
          "Formato de capítulo/versículo inválido. Use 'Livro Cap' ou 'Livro Cap:Ver'.");
      return;
    }
    final int? chapter = int.tryParse(cvMatch.group(1)!);
    if (chapter == null) {
      updateErrorText("Número do capítulo inválido.");
      return;
    }
    _finalizeNavigation(
        foundBookAbbrev, chapter, dialogContext, updateErrorText);
  }

  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
    // ... (sem alterações)
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
        if (Navigator.canPop(dialogContext)) Navigator.of(dialogContext).pop();
        updateErrorText(null);
      } else {
        updateErrorText(
            'Capítulo $chapter inválido para ${bookData['nome']}. (${bookData['capitulos']} caps).');
      }
    } else {
      updateErrorText(
          'Livro "$bookAbbrev" (abreviação) não encontrado no sistema.');
    }
  }

  void _applyFiltersToReduxAndSearch() {
    if (!mounted || _store == null) return;

    _store!.dispatch(
        SetBibleSearchFilterAction('testamento', _filterSelectedTestament));
    _store!.dispatch(
        SetBibleSearchFilterAction('livro_curto', _filterSelectedBookAbbrev));
    _store!.dispatch(
        SetBibleSearchFilterAction('tipo', _filterSelectedContentType));

    final queryToSearch = _semanticQueryController.text.trim();
    if (queryToSearch.isNotEmpty) {
      print(
          "UI (BiblePage): Despachando SearchBibleSemanticAction com query: $queryToSearch");
      _store!.dispatch(SearchBibleSemanticAction(queryToSearch));
      // >>> REMOVER A NAVEGAÇÃO ABAIXO <<<
      // Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //         builder: (context) =>
      //             BibleSearchResultsPage(initialQuery: queryToSearch)));
    } else {
      // Se a query for vazia, limpa os resultados atuais para mostrar o histórico
      _store!.dispatch(SearchBibleSemanticSuccessAction([]));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Digite um termo para buscar ou selecione do histórico.')));
    }
  }

  void _clearFiltersInReduxAndResetLocal() {
    // ... (sem alterações)
    if (!mounted || _store == null) return;
    setState(() {
      _filterSelectedTestament = null;
      _filterSelectedBookAbbrev = null;
      _filterSelectedContentType = null;
    });
    _store!.dispatch(ClearBibleSearchFiltersAction());
  }

  /// Lida com os cliques no botão de áudio global na AppBar.
  void _handleGlobalAudioControl() {
    if (!mounted) return;

    if (_currentPlayerState == TtsPlayerState.playing) {
      _ttsManager.pause();
    } else if (_currentPlayerState == TtsPlayerState.paused) {
      // "restartCurrentItem" continuará a fala do item pausado.
      _ttsManager.restartCurrentItem();
    }
  }

  List<Widget> _buildAppBarActions(
      BuildContext context, ThemeData theme, _BiblePageViewModel viewModel) {
    Color defaultIconColor = theme.appBarTheme.actionsIconTheme?.color ??
        theme.colorScheme.onPrimary;
    Color activeSemanticSearchIconColor = theme.colorScheme.secondary;

    if (_isFocusModeActive) {
      return [
        IconButton(
          icon: Icon(Icons.fullscreen_exit, color: defaultIconColor),
          tooltip: "Sair do Modo Foco",
          onPressed: () {
            if (mounted) {
              setState(() {
                _isFocusModeActive = false;
              });
            }
          },
        ),
      ];
    }

    List<Widget> actions = [];

    // Este botão só aparece se o áudio estiver tocando ou pausado.
    if (_currentPlayerState != TtsPlayerState.stopped) {
      actions.add(
        IconButton(
          icon: Icon(
            _currentPlayerState == TtsPlayerState.playing
                ? Icons.pause_circle_outline_rounded // Ícone de pausa
                : Icons.play_circle_outline_rounded, // Ícone de play
            color: theme.colorScheme.secondary, // Cor de destaque
            size: 28, // Tamanho um pouco maior
          ),
          tooltip: _currentPlayerState == TtsPlayerState.playing
              ? "Pausar Leitura"
              : "Continuar Leitura",
          onPressed:
              _handleGlobalAudioControl, // Chama a nova função de controle
        ),
      );
    }

    if (_isSemanticSearchActive) {
      // Ações quando a busca semântica está ATIVA
      actions.add(IconButton(
        icon: Icon(Icons.search,
            color: activeSemanticSearchIconColor,
            size: 26), // Ícone de lupa para EXECUTAR a busca
        tooltip: "Buscar",
        onPressed:
            _applyFiltersToReduxAndSearch, // Chama a função que aplica filtros e busca
      ));
      actions.add(IconButton(
        icon: Icon(Icons.close, color: defaultIconColor, size: 26),
        tooltip: "Fechar Busca",
        onPressed: () {
          if (mounted) {
            setState(() {
              _isSemanticSearchActive = false;
              _semanticQueryController
                  .clear(); // Limpa o texto da busca ao fechar
              // Opcional: Limpar filtros e resultados do Redux se desejar
              // StoreProvider.of<AppState>(context, listen: false).dispatch(ClearBibleSearchFiltersAction());
              // StoreProvider.of<AppState>(context, listen: false).dispatch(SearchBibleSemanticSuccessAction([]));
            });
          }
        },
      ));
    } else {
      actions.add(IconButton(
        icon: Icon(Icons.manage_search_outlined,
            color: defaultIconColor, size: 26),
        tooltip: "Ir para referência",
        onPressed: _showGoToDialog,
      ));
      actions.add(IconButton(
        icon: SvgPicture.asset(
          'assets/icons/buscasemantica.svg',
          colorFilter: ColorFilter.mode(defaultIconColor, BlendMode.srcIn),
          width: 24, // Tamanho do SVG
          height: 24,
        ),
        tooltip: "Busca Semântica",
        onPressed: () {
          //final store = StoreProvider.of<AppState>(context, listen: false);
          // if (store.state.userState.isGuestUser) {
          //   showLoginRequiredDialog(context,
          //       featureName: "a busca avançada na Bíblia");
          // } else {
          setState(() {
            _isSemanticSearchActive = true;
            _showExtraOptions = false;
          });
          //}
        },
      ));
      actions.add(IconButton(
        icon: Icon(Icons.more_vert, color: defaultIconColor, size: 26),
        tooltip: "Mais Opções",
        onPressed: () {
          setState(() {
            _showExtraOptions = !_showExtraOptions;
          });
        },
      ));
    }
    return actions;
  }

  // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  // FUNÇÃO REMOVIDA
  // Widget _buildExtraOptionsBar(ThemeData theme) { ... }
  // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  Widget _buildSemanticSearchTextField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 10.0), // Aumentado padding vertical
      child: TextField(
        controller: _semanticQueryController,
        autofocus: _isSemanticSearchActive,
        style: TextStyle(
            color: theme.textTheme.bodyLarge?.color ?? Colors.white,
            fontSize: 15), // Fonte um pouco maior
        decoration: InputDecoration(
          hintText: 'Busca semântica na Bíblia...',
          hintStyle: TextStyle(
              color: theme.hintColor.withOpacity(0.8),
              fontSize: 15), // Hint com mais contraste
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
                left: 14.0,
                right: 10.0,
                top: 10.0,
                bottom: 10.0), // Ajuste fino do padding do ícone
            child: SvgPicture.asset(
              'assets/icons/buscasemantica.svg',
              colorFilter: ColorFilter.mode(
                  theme.iconTheme.color?.withOpacity(0.7) ?? theme.hintColor,
                  BlendMode.srcIn),
              width: 20,
              height: 20,
            ),
          ),
          suffixIcon: _semanticQueryController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: theme.iconTheme.color?.withOpacity(0.7), size: 22),
                  tooltip: "Limpar busca",
                  onPressed: () {
                    _semanticQueryController.clear();
                    // Opcional: se quiser que a lista de resultados limpe imediatamente
                    // StoreProvider.of<AppState>(context, listen: false).dispatch(SearchBibleSemanticSuccessAction([]));
                  },
                )
              : null,
          isDense: true, // Torna o campo um pouco mais compacto verticalmente
          contentPadding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 10), // Padding interno
          filled: true,
          fillColor: theme.inputDecorationTheme.fillColor ??
              theme.cardColor.withOpacity(0.08), // Cor de fundo sutil
          border: OutlineInputBorder(
            // Borda padrão
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.5), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            // Borda quando não focado
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.4), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            // Borda quando focado
            borderRadius: BorderRadius.circular(25.0),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.8),
          ),
        ),
        onChanged: (query) {
          // Você pode adicionar um debounce aqui se quiser busca "enquanto digita"
          // Mas atualmente a busca é acionada por onSubmitted ou pelo botão na AppBar
        },
        onSubmitted: (query) {
          _applyFiltersToReduxAndSearch();
        },
        textInputAction:
            TextInputAction.search, // Para o botão de "buscar" no teclado
      ),
    );
  }

  Widget _buildSemanticSearchFilterWidgets(ThemeData theme) {
    return BibleSearchFilterBar(
      initialBooksMap: booksMap, // Passa o booksMap já carregado pela BiblePage
      initialActiveFilters: _store?.state.bibleSearchState.activeFilters ?? {},
      onFilterChanged: (
          {String? testament, String? bookAbbrev, String? contentType}) {
        // Atualiza o estado local da BiblePage (se ainda precisar deles aqui)
        // E/OU despacha ações para o Redux se a barra de filtro não fizer isso diretamente
        // Para este exemplo, vamos assumir que a busca é disparada pelo botão principal na AppBar
        // então só precisamos que a BiblePage saiba quais filtros estão selecionados para
        // a próxima chamada a _applyFiltersToReduxAndSearch.
        // A UI da barra de filtros (chips) já se atualiza internamente.
        setState(() {
          _filterSelectedTestament = testament;
          _filterSelectedBookAbbrev = bookAbbrev;
          _filterSelectedContentType = contentType;
        });
        // Se quiser que o filtro seja aplicado no Redux imediatamente:
        // _store?.dispatch(SetBibleSearchFilterAction('testamento', testament));
        // _store?.dispatch(SetBibleSearchFilterAction('livro_curto', bookAbbrev));
        // _store?.dispatch(SetBibleSearchFilterAction('tipo', contentType));
      },
      onClearFilters: () {
        // Esta função é chamada quando o botão de limpar dentro da barra é tocado
        _clearFiltersInReduxAndResetLocal(); // Sua função existente na BiblePage
      },
    );
  }

  // ... (o restante do arquivo bible_page.dart, incluindo _buildSingleViewContent, build, etc., permanece o mesmo)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _BiblePageViewModel>(
      converter: (store) => _BiblePageViewModel.fromStore(store),
      onInit: (store) {
        _store = store;
        if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasProcessedInitialNavigation) {
              _processIntentOrInitialLoad(_BiblePageViewModel.fromStore(store));
            }
          });
        }
        _loadUserDataIfNeeded(context);

        final initialFilters = store.state.bibleSearchState.activeFilters;
        if (_filterSelectedTestament != initialFilters['testamento'] ||
            _filterSelectedBookAbbrev != initialFilters['livro_curto'] ||
            _filterSelectedContentType != initialFilters['tipo']) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _filterSelectedTestament =
                    initialFilters['testamento'] as String?;
                _filterSelectedBookAbbrev =
                    initialFilters['livro_curto'] as String?;
                _filterSelectedContentType = initialFilters['tipo'] as String?;
              });
            }
          });
        }
      },
      builder: (context, viewModel) {
        if (booksMap == null || _bookVariationsMap.isEmpty) {
          return Scaffold(
              appBar: AppBar(title: const Text('Bíblia')),
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary)));
        }
        if (selectedBook == null || selectedChapter == null) {
          if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                _processIntentOrInitialLoad(viewModel);
              }
            });
          }
          return Scaffold(
              appBar: AppBar(title: const Text('Bíblia')),
              body: Center(
                  child: Text("Carregando Bíblia...",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color))));
        }

        // Determina o título da AppBar
        String appBarTitleText; // Removida inicialização aqui
        if (_isSemanticSearchActive) {
          appBarTitleText = "Busca na Bíblia";
        } else {
          appBarTitleText = (booksMap?[selectedBook]?['nome'] ?? 'Bíblia');
          if (_isFocusModeActive) {
            // No modo foco, o título já inclui o capítulo se não for busca semântica
            if (selectedChapter != null) appBarTitleText += ' $selectedChapter';
          } else if (_isCompareModeActive) {
            appBarTitleText = 'Comparar Traduções';
          }
          // Se não for foco nem comparação, e não for busca semântica, o título já está correto
          // (nome do livro), e o capítulo pode ser adicionado se desejado.
          // Se a barra de opções extras não estiver visível, podemos adicionar o capítulo ao título.
          else if (!_showExtraOptions && selectedChapter != null) {
            appBarTitleText += ' $selectedChapter';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitleText),
            leading: _isFocusModeActive ? const SizedBox.shrink() : null,
            actions: [
              // >>> ADICIONE O BOTÃO DE TOGGLE PARA LEITURA CONTÍNUA AQUI <<<
              if (!_isSemanticSearchActive) // Mostra apenas se não estiver em modo de busca
                IconButton(
                  icon: Icon(Icons.record_voice_over_outlined,
                      color: theme.iconTheme.color),
                  tooltip: "Alterar Voz",
                  onPressed: _showVoiceSelectionDialog,
                ),
              ..._buildAppBarActions(context, theme, viewModel),
            ],
          ),
          body: PageStorage(
            bucket: _pageStorageBucket,
            child: Column(
              children: [
                if (_isSemanticSearchActive && !_isFocusModeActive)
                  _buildSemanticSearchTextField(theme),
                if (_isSemanticSearchActive && !_isFocusModeActive)
                  _buildSemanticSearchFilterWidgets(theme),

                // >>> INÍCIO DA MODIFICAÇÃO: Uso do novo widget <<<
                if (_showExtraOptions &&
                    !_isSemanticSearchActive &&
                    !_isFocusModeActive)
                  BibleOptionsBar(
                    selectedTranslation1: selectedTranslation1,
                    selectedTranslation2: selectedTranslation2,
                    selectedBook: selectedBook,
                    booksMap: booksMap,
                    isCompareModeActive: _isCompareModeActive,
                    isFocusModeActive: _isFocusModeActive,
                    showHebrewInterlinear: _showHebrewInterlinear,
                    showGreekInterlinear: _showGreekInterlinear,
                    currentFontSizeMultiplier: _currentFontSizeMultiplier,
                    minFontMultiplier: MIN_FONT_MULTIPLIER,
                    maxFontMultiplier: MAX_FONT_MULTIPLIER,
                    onTranslation1Changed: (value) {
                      if (mounted && value != selectedTranslation2) {
                        interstitialManager
                            .tryShowInterstitial(
                                fromScreen:
                                    "BiblePage_ChangeTranslation1_To_$value")
                            .then((_) {
                          if (mounted) {
                            setState(() {
                              selectedTranslation1 = value;
                              if ((value == 'hebrew_original' &&
                                      selectedTranslation2 ==
                                          'hebrew_original') ||
                                  (value == 'greek_interlinear' &&
                                      selectedTranslation2 ==
                                          'greek_interlinear')) {
                                selectedTranslation2 =
                                    (value == 'nvi' || value == 'acf')
                                        ? 'aa'
                                        : 'nvi';
                              }
                              _updateFutureBuilderKey();
                              if (value == 'hebrew_original' &&
                                  _showHebrewInterlinear)
                                _showHebrewInterlinear = false;
                              if (value == 'greek_interlinear' &&
                                  _showGreekInterlinear)
                                _showGreekInterlinear = false;
                            });
                          }
                        });
                      }
                    },
                    onTranslation2Changed: (value) {
                      if (mounted && value != selectedTranslation1) {
                        interstitialManager
                            .tryShowInterstitial(
                                fromScreen:
                                    "BiblePage_ChangeTranslation2_To_$value")
                            .then((_) {
                          if (mounted) {
                            setState(() {
                              selectedTranslation2 = value;
                              _updateFutureBuilderKey();
                            });
                          }
                        });
                      }
                    },
                    onToggleCompareMode: () {
                      if (mounted) {
                        setState(() {
                          _isCompareModeActive = !_isCompareModeActive;
                          if (_isCompareModeActive &&
                              selectedTranslation1 == selectedTranslation2) {
                            selectedTranslation2 =
                                (selectedTranslation1 == 'nvi') ? 'acf' : 'nvi';
                          }
                          if (!_isCompareModeActive) {
                            selectedTranslation2 = null;
                          }
                          if (_isCompareModeActive) {
                            if (_showHebrewInterlinear)
                              _showHebrewInterlinear = false;
                            if (_showGreekInterlinear)
                              _showGreekInterlinear = false;
                          }
                          _updateFutureBuilderKey();
                        });
                      }
                    },
                    onToggleFocusMode: () {
                      if (mounted) {
                        setState(
                            () => _isFocusModeActive = !_isFocusModeActive);
                        _updateFutureBuilderKey();
                      }
                    },
                    onToggleHebrewInterlinear: () {
                      if (!_showHebrewInterlinear) {
                        interstitialManager.tryShowInterstitial(
                            fromScreen: "BiblePage_ToggleHebrewInterlinear");
                      }
                      setState(() {
                        _showHebrewInterlinear = !_showHebrewInterlinear;
                        if (_showHebrewInterlinear) {
                          _showGreekInterlinear = false;
                          _loadCurrentChapterHebrewDataIfNeeded();
                        } else {
                          _currentChapterHebrewData = null;
                        }
                        _updateFutureBuilderKey();
                      });
                    },
                    onToggleGreekInterlinear: () {
                      if (!_showGreekInterlinear) {
                        interstitialManager.tryShowInterstitial(
                            fromScreen: "BiblePage_ToggleGreekInterlinear");
                      }
                      setState(() {
                        _showGreekInterlinear = !_showGreekInterlinear;
                        if (_showGreekInterlinear) {
                          _showHebrewInterlinear = false;
                          _loadCurrentChapterGreekDataIfNeeded();
                        } else {
                          _currentChapterGreekData = null;
                        }
                        _updateFutureBuilderKey();
                      });
                    },
                    onIncreaseFontSize: _increaseFontSize,
                    onDecreaseFontSize: _decreaseFontSize,
                  ),
                // >>> FIM DA MODIFICAÇÃO <<<

                Expanded(
                  child: (_isSemanticSearchActive && !_isFocusModeActive)
                      // Se a busca semântica está ativa, mostra a UI de busca
                      ? BibleSemanticSearchView(
                          onToggleItemExpansion:
                              _toggleItemExpansionInBiblePage,
                          onNavigateToVerse: _navigateToVerseFromSearch,
                          expandedItemId: _expandedItemId,
                          isLoadingExpandedContent: _isLoadingExpandedContent,
                          loadedExpandedContent: _loadedExpandedContent,
                          fontSizeMultiplier: _currentFontSizeMultiplier,
                        )
                      // Senão, mostra a UI de leitura da Bíblia
                      : (selectedBook != null &&
                              selectedChapter != null &&
                              _selectedBookSlug != null)
                          ? FutureBuilder<Map<String, dynamic>>(
                              key: _futureBuilderKey,
                              future: BiblePageHelper.loadChapterDataComparison(
                                  selectedBook!,
                                  selectedChapter!,
                                  selectedTranslation1,
                                  _isCompareModeActive
                                      ? selectedTranslation2
                                      : null),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator(
                                          color: theme.colorScheme.primary));
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SingleChildScrollView(
                                        child: Text(
                                          'ERRO AO CARREGAR CAPÍTULO $selectedBook $selectedChapter:\n${snapshot.error}\n\n${snapshot.stackTrace}',
                                          style: TextStyle(
                                              color: theme.colorScheme.error,
                                              fontSize: 14),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data == null ||
                                    snapshot.data!.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'Nenhum dado bíblico encontrado para $selectedBook $selectedChapter.',
                                      style: TextStyle(
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                          fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }

                                final chapterData = snapshot.data!;
                                final List<Map<String, dynamic>> sections =
                                    List<Map<String, dynamic>>.from(
                                        chapterData['sectionStructure'] ?? []);
                                final Map<String, dynamic> verseDataMap =
                                    Map<String, dynamic>.from(
                                        chapterData['verseData'] ?? {});

                                final dynamic primaryTranslationVerseData =
                                    verseDataMap[selectedTranslation1];

                                bool primaryDataMissing =
                                    (primaryTranslationVerseData == null ||
                                        (primaryTranslationVerseData is List &&
                                            primaryTranslationVerseData
                                                .isEmpty));

                                if (primaryDataMissing) {
                                  return Center(
                                      child: Text(
                                    'Conteúdo do capítulo não encontrado para a tradução $selectedTranslation1.',
                                    style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ));
                                }

                                // Usando DelayedLoading para evitar um "salto" na UI
                                return DelayedLoading(
                                  loading: false,
                                  delay: const Duration(milliseconds: 50),
                                  loadingIndicator: Center(
                                      child: CircularProgressIndicator(
                                          color: theme.colorScheme.primary)),
                                  child: () {
                                    dynamic hebrewDataForInterlinearView;
                                    if (_showHebrewInterlinear &&
                                        _currentChapterHebrewData != null &&
                                        _currentChapterHebrewData!['book'] ==
                                            selectedBook &&
                                        _currentChapterHebrewData!['chapter'] ==
                                            selectedChapter) {
                                      hebrewDataForInterlinearView =
                                          _currentChapterHebrewData!['data'];
                                    }

                                    dynamic greekDataForInterlinearView;
                                    if (_showGreekInterlinear &&
                                        _currentChapterGreekData != null &&
                                        _currentChapterGreekData!['book'] ==
                                            selectedBook &&
                                        _currentChapterGreekData!['chapter'] ==
                                            selectedChapter) {
                                      greekDataForInterlinearView =
                                          _currentChapterGreekData!['data'];
                                    }

                                    if (!_isCompareModeActive) {
                                      return _buildSingleViewContent(
                                        theme,
                                        sections,
                                        primaryTranslationVerseData,
                                        selectedTranslation1 ==
                                            'hebrew_original',
                                        selectedTranslation1 ==
                                            'greek_interlinear',
                                        hebrewDataForInterlinearView,
                                        greekDataForInterlinearView,
                                        _currentFontSizeMultiplier,
                                      );
                                    } else {
                                      final dynamic
                                          comparisonTranslationVerseData =
                                          (_isCompareModeActive &&
                                                  selectedTranslation2 != null)
                                              ? verseDataMap[
                                                  selectedTranslation2!]
                                              : null;
                                      if (comparisonTranslationVerseData ==
                                              null ||
                                          (comparisonTranslationVerseData
                                                      is List &&
                                                  comparisonTranslationVerseData
                                                      .isEmpty) &&
                                              selectedTranslation2 != null) {
                                        return Center(
                                            child: Text(
                                          'Tradução de comparação "$selectedTranslation2" não encontrada para este capítulo.',
                                          style: TextStyle(
                                              color: theme.colorScheme.error,
                                              fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ));
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildComparisonColumn(
                                                  context,
                                                  sections,
                                                  primaryTranslationVerseData
                                                      as List,
                                                  _scrollController1,
                                                  selectedTranslation1,
                                                  isHebrew:
                                                      selectedTranslation1 ==
                                                          'hebrew_original',
                                                  isGreek:
                                                      selectedTranslation1 ==
                                                          'greek_interlinear',
                                                  fontSizeMultiplier:
                                                      _currentFontSizeMultiplier,
                                                  listViewKey: PageStorageKey<
                                                          String>(
                                                      '$selectedBook-$selectedChapter-$selectedTranslation1-compareView'))),
                                          VerticalDivider(
                                              width: 1,
                                              color: theme.dividerColor
                                                  .withOpacity(0.5),
                                              thickness: 0.5),
                                          Expanded(
                                              child: _buildComparisonColumn(
                                                  context,
                                                  sections,
                                                  (comparisonTranslationVerseData
                                                          as List?) ??
                                                      [],
                                                  _scrollController2,
                                                  selectedTranslation2!,
                                                  isHebrew:
                                                      selectedTranslation2 ==
                                                          'hebrew_original',
                                                  isGreek:
                                                      selectedTranslation2 ==
                                                          'greek_interlinear',
                                                  fontSizeMultiplier:
                                                      _currentFontSizeMultiplier,
                                                  listViewKey: PageStorageKey<
                                                          String>(
                                                      '$selectedBook-$selectedChapter-$selectedTranslation2-compareView'))),
                                        ],
                                      );
                                    }
                                  },
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                ),
                // >>> INÍCIO DA MODIFICAÇÃO: Uso do novo widget <<<
                Visibility(
                  visible: !_isFocusModeActive &&
                      !_isSemanticSearchActive &&
                      !_showExtraOptions,
                  child: BibleNavigationControls(
                    selectedBook: selectedBook,
                    selectedChapter: selectedChapter,
                    booksMap: booksMap,
                    onPreviousChapter: _previousChapter,
                    onNextChapter: _nextChapter,
                    onBookChanged: (value) {
                      if (mounted && value != null)
                        _navigateToChapter(value, 1);
                    },
                    onChapterChanged: (value) {
                      if (mounted && value != null && selectedBook != null) {
                        _navigateToChapter(selectedBook!, value);
                      }
                    },
                  ),
                ),
                // >>> FIM DA MODIFICAÇÃO <<<
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleViewContent(
    ThemeData theme,
    List<Map<String, dynamic>> sections, // Estrutura de seções do capítulo
    dynamic
        primaryTranslationVerseData, // Dados dos versos para a tradução principal
    bool
        isPrimaryTranslationHebrew, // Flag: a tradução principal é hebraico interlinear?
    bool
        isPrimaryTranslationGreek, // Flag: a tradução principal é grego interlinear?
    dynamic
        hebrewInterlinearChapterData, // Dados do capítulo inteiro para hebraico interlinear complementar
    dynamic
        greekInterlinearChapterData, // Dados do capítulo inteiro para grego interlinear complementar
    double fontSizeMultiplier, // Multiplicador para o tamanho da fonte
  ) {
    return StoreConnector<AppState, _BibleContentViewModel>(
      converter: (store) =>
          _BibleContentViewModel.fromStore(store, selectedBook),
      builder: (context, contentViewModel) {
        final listViewKey = PageStorageKey<String>(
            '$selectedBook-$selectedChapter-$selectedTranslation1-singleView-content-$_showHebrewInterlinear-$_showGreekInterlinear-$fontSizeMultiplier');

        // A limpeza de _sectionItemKeys é feita em _applyNavigationState

        return ListView.builder(
          key: listViewKey,
          padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              top: _isFocusModeActive ? 8.0 : 0.0),
          itemCount: sections.isNotEmpty
              ? sections.length
              : (primaryTranslationVerseData != null &&
                      (primaryTranslationVerseData as List).isNotEmpty
                  ? (primaryTranslationVerseData as List).length
                  : 0),
          itemBuilder: (context, index) {
            String itemScrollKeyId;
            GlobalKey itemKey;
            Widget itemWidget;

            if (sections.isNotEmpty) {
              final section = sections[index];
              final List<int> verseNumbersInSection =
                  (section['verses'] as List?)?.cast<int>() ?? [];
              final String versesRangeStrInSection = (section['verses']
                              as List?)
                          ?.cast<int>()
                          .isNotEmpty ??
                      false
                  ? ((section['verses'] as List).cast<int>().length == 1
                      ? (section['verses'] as List).cast<int>().first.toString()
                      : "${(section['verses'] as List).cast<int>().first}-${(section['verses'] as List).cast<int>().last}")
                  : "all_verses_in_section_${index}";

              itemScrollKeyId =
                  "${selectedBook}_c${selectedChapter}_v$versesRangeStrInSection";
              _sectionItemKeys.putIfAbsent(itemScrollKeyId, () => GlobalKey());
              itemKey = _sectionItemKeys[itemScrollKeyId]!;

              List<List<Map<String, String>>>? hebrewDataForThisSection;
              if (_showHebrewInterlinear &&
                  !isPrimaryTranslationHebrew &&
                  hebrewInterlinearChapterData != null &&
                  hebrewInterlinearChapterData is List) {
                hebrewDataForThisSection = [];
                for (int verseNumInChapter in verseNumbersInSection) {
                  if (verseNumInChapter > 0 &&
                      verseNumInChapter <=
                          hebrewInterlinearChapterData.length) {
                    hebrewDataForThisSection.add(List<Map<String, String>>.from(
                        hebrewInterlinearChapterData[verseNumInChapter - 1]));
                  } else {
                    hebrewDataForThisSection.add([]);
                  }
                }
              }

              List<List<Map<String, String>>>? greekDataForThisSection;
              if (_showGreekInterlinear &&
                  !isPrimaryTranslationGreek &&
                  greekInterlinearChapterData != null &&
                  greekInterlinearChapterData is List) {
                greekDataForThisSection = [];
                for (int verseNumInChapter in verseNumbersInSection) {
                  if (verseNumInChapter > 0 &&
                      verseNumInChapter <= greekInterlinearChapterData.length) {
                    greekDataForThisSection.add(List<Map<String, String>>.from(
                        greekInterlinearChapterData[verseNumInChapter - 1]));
                  } else {
                    greekDataForThisSection.add([]);
                  }
                }
              }

              itemWidget = SectionItemWidget(
                key: itemKey,
                sectionTitle: section['title'] ?? 'Seção Desconhecida',
                verseNumbersInSection: verseNumbersInSection,
                allVerseDataInChapter: primaryTranslationVerseData,
                bookSlug: _selectedBookSlug!,
                bookAbbrev: selectedBook!,
                chapterNumber: selectedChapter!,
                versesRangeStr: versesRangeStrInSection,
                userHighlights: contentViewModel.userHighlights,
                userNotes: contentViewModel.userNotes,
                isHebrew: isPrimaryTranslationHebrew,
                isGreekInterlinear: isPrimaryTranslationGreek,
                isRead: contentViewModel.readSectionsForCurrentBook.contains(
                    "${selectedBook}_c${selectedChapter}_v$versesRangeStrInSection"),
                showHebrewInterlinear:
                    _showHebrewInterlinear && !isPrimaryTranslationHebrew,
                showGreekInterlinear:
                    _showGreekInterlinear && !isPrimaryTranslationGreek,
                hebrewInterlinearSectionData: hebrewDataForThisSection,
                greekInterlinearSectionData: greekDataForThisSection,
                fontSizeMultiplier: fontSizeMultiplier,
                //isContinuousPlayActive: true,
                onPlayRequest: _handlePlayRequest,
                currentPlayerState: _currentPlayerState,
                currentlyPlayingSectionId: _currentlyPlayingSectionId,
                currentlyPlayingContentType: _currentlyPlayingContentType,
              );
            } else if (primaryTranslationVerseData != null &&
                (primaryTranslationVerseData as List).isNotEmpty) {
              final verseNumber = index + 1;
              final dynamic mainVerseDataItem =
                  (primaryTranslationVerseData as List)[index];

              List<Map<String, String>>? hebrewVerseForInterlinear;
              if (_showHebrewInterlinear &&
                  !isPrimaryTranslationHebrew &&
                  hebrewInterlinearChapterData != null &&
                  hebrewInterlinearChapterData
                      is List<List<Map<String, String>>> &&
                  index < hebrewInterlinearChapterData.length) {
                hebrewVerseForInterlinear = hebrewInterlinearChapterData[index];
              }

              List<Map<String, String>>? greekVerseForInterlinear;
              if (_showGreekInterlinear &&
                  !isPrimaryTranslationGreek &&
                  greekInterlinearChapterData != null &&
                  greekInterlinearChapterData
                      is List<List<Map<String, String>>> &&
                  index < greekInterlinearChapterData.length) {
                greekVerseForInterlinear = greekInterlinearChapterData[index];
              }

              itemScrollKeyId =
                  "${selectedBook}_c${selectedChapter}_v$verseNumber";
              _sectionItemKeys.putIfAbsent(itemScrollKeyId, () => GlobalKey());
              itemKey = _sectionItemKeys[itemScrollKeyId]!;

              itemWidget = BiblePageWidgets.buildVerseItem(
                  key: itemKey,
                  verseNumber: verseNumber,
                  verseData: mainVerseDataItem,
                  selectedBook: selectedBook,
                  selectedChapter: selectedChapter,
                  context: context,
                  userHighlights: contentViewModel.userHighlights,
                  userNotes: contentViewModel.userNotes,
                  fontSizeMultiplier: fontSizeMultiplier,
                  isHebrew: isPrimaryTranslationHebrew,
                  isGreekInterlinear: isPrimaryTranslationGreek,
                  showHebrewInterlinear:
                      _showHebrewInterlinear && !isPrimaryTranslationHebrew,
                  showGreekInterlinear:
                      _showGreekInterlinear && !isPrimaryTranslationGreek,
                  hebrewVerseData: hebrewVerseForInterlinear,
                  greekVerseData: greekVerseForInterlinear);
            } else {
              return const SizedBox.shrink();
            }

            // Lógica de scroll e limpeza da intent
            if (_sectionIdToScrollAfterLoad == itemScrollKeyId) {
              print(
                  "BiblePage (itemBuilder): Tentando agendar scroll para $itemScrollKeyId. _sectionIdToScrollAfterLoad: $_sectionIdToScrollAfterLoad");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                bool scrolledSuccessfully = false;
                if (itemKey.currentContext != null && mounted) {
                  Scrollable.ensureVisible(
                    itemKey.currentContext!,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOutCubic,
                    alignment: 0.15,
                  );
                  scrolledSuccessfully = true;
                  print(
                      "BiblePage: Scroll para $itemScrollKeyId AGENDADO/EXECUTADO.");
                } else {
                  print(
                      "BiblePage: Scroll para $itemScrollKeyId FALHOU (pós-build) - contexto nulo ou desmontado.");
                }

                if (mounted && _sectionIdToScrollAfterLoad == itemScrollKeyId) {
                  print(
                      "BiblePage: Limpando intent do Redux e _sectionIdToScrollAfterLoad para $itemScrollKeyId.");
                  StoreProvider.of<AppState>(context, listen: false)
                      .dispatch(SetInitialBibleLocationAction(null, null));
                  setState(() {
                    _sectionIdToScrollAfterLoad = null;
                  });
                }
              });
            }
            return itemWidget;
          },
        );
      },
    );
  }

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections, // Estrutura de seções do capítulo
      List
          verseColumnData, // Dados dos versos para ESTA coluna (pode ser List<String> ou List<List<Map<String,String>>>)
      ScrollController scrollController,
      String
          currentTranslation, // Chave da tradução (ex: "nvi", "hebrew_original", "greek_interlinear")
      {bool isHebrew = false, // Se esta coluna é a tradução hebraica original
      bool isGreek = false, // Se esta coluna é a tradução grega interlinear
      required double fontSizeMultiplier, // Multiplicador do tamanho da fonte
      required PageStorageKey listViewKey}) {
    final theme = Theme.of(context);

    // Verifica se há dados para exibir
    if (verseColumnData.isEmpty &&
        sections.isEmpty &&
        currentTranslation.isNotEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                  "Tradução '$currentTranslation' indisponível para este capítulo.",
                  style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color, fontSize: 13),
                  textAlign: TextAlign.center)));
    }

    // O StoreConnector aqui é para obter os dados de destaques, notas e progresso de leitura
    // que são relevantes para qualquer visualização de versículo.
    return StoreConnector<AppState, _BibleContentViewModel>(
        converter: (store) =>
            _BibleContentViewModel.fromStore(store, selectedBook),
        builder: (context, contentViewModel) {
          return ListView.builder(
            key: listViewKey, // Chave para preservar o estado de rolagem
            controller:
                scrollController, // Controlador para sincronizar a rolagem
            padding: EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 16.0,
                top: _isFocusModeActive
                    ? 8.0
                    : 0.0), // Padding ajustado para modo foco
            itemCount: sections.isNotEmpty
                ? sections
                    .length // Se houver seções, o itemCount é o número de seções
                : (verseColumnData.isNotEmpty
                    ? 1
                    : 0), // Senão, 1 item se houver dados de verso, ou 0
            itemBuilder: (context, index) {
              // 'index' aqui é o índice da seção ou 0 se não houver seções
              if (sections.isNotEmpty) {
                // --- RENDERIZA POR SEÇÃO ---
                final section = sections[index]; // Pega a seção atual
                final String sectionTitle = section['title'] ?? 'Seção';
                final List<int> verseNumbersInSection =
                    (section['verses'] as List?)?.cast<int>() ?? [];

                // Determina o ID da seção para rastrear o progresso de leitura
                final String versesRangeStrForSection = (section['verses']
                                as List?)
                            ?.cast<int>()
                            .isNotEmpty ??
                        false
                    ? ((section['verses'] as List).cast<int>().length == 1
                        ? (section['verses'] as List)
                            .cast<int>()
                            .first
                            .toString()
                        : "${(section['verses'] as List).cast<int>().first}-${(section['verses'] as List).cast<int>().last}")
                    : "all_verses_in_section"; // Fallback se 'verses' estiver vazio
                final String currentSectionId =
                    "${selectedBook}_c${selectedChapter}_v$versesRangeStrForSection";
                final bool isSectionRead = contentViewModel
                    .readSectionsForCurrentBook
                    .contains(currentSectionId);

                final String sectionDisplayKey = section['verses']?.join('-') ??
                    sectionTitle; // Chave para o widget da seção

                return Column(
                    key: ValueKey(
                        'compare_col_section_${currentTranslation}_${sectionTitle}_$sectionDisplayKey${isSectionRead ? '_read' : '_unread'}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding:
                              const EdgeInsets.only(top: 16.0, bottom: 4.0),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Text(sectionTitle,
                                        style: TextStyle(
                                            color: isSectionRead
                                                ? theme.primaryColor
                                                : theme.colorScheme
                                                    .primary, // Destaque se lido
                                            fontSize: 16 *
                                                fontSizeMultiplier, // Aplica multiplicador
                                            fontWeight: FontWeight.bold))),
                                // Botão para marcar seção como lida/não lida
                                IconButton(
                                    icon: Icon(
                                        isSectionRead
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        color: isSectionRead
                                            ? theme.primaryColor
                                            : theme.iconTheme.color
                                                ?.withOpacity(0.7),
                                        size: 20 *
                                            fontSizeMultiplier), // Aplica multiplicador
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: isSectionRead
                                        ? "Desmarcar como lido"
                                        : "Marcar como lido",
                                    onPressed: () {
                                      StoreProvider.of<AppState>(context,
                                              listen: false)
                                          .dispatch(
                                              ToggleSectionReadStatusAction(
                                                  bookAbbrev: selectedBook!,
                                                  sectionId: currentSectionId,
                                                  markAsRead: !isSectionRead));
                                    })
                              ])),
                      // Renderiza cada versículo dentro da seção
                      ...verseNumbersInSection.map((verseNumber) {
                        final verseIndexInChapterData =
                            verseNumber - 1; // Ajusta para índice 0
                        dynamic verseDataItemForThisColumn;

                        // Pega os dados do versículo específico para esta coluna
                        if (verseIndexInChapterData >= 0 &&
                            verseIndexInChapterData < verseColumnData.length) {
                          verseDataItemForThisColumn =
                              verseColumnData[verseIndexInChapterData];
                        } else {
                          // Fallback se o dado do verso não estiver disponível (raro, mas seguro)
                          verseDataItemForThisColumn = (isHebrew || isGreek)
                              ? []
                              : "[Texto Indisponível]";
                        }

                        return BiblePageWidgets.buildVerseItem(
                          key: ValueKey<String>(
                              'compare_col_${currentTranslation}_${selectedBook}_${selectedChapter}_$verseNumber'),
                          verseNumber: verseNumber,
                          verseData:
                              verseDataItemForThisColumn, // Passa os dados do verso para esta coluna
                          selectedBook: selectedBook,
                          selectedChapter: selectedChapter,
                          context: context,
                          userHighlights: contentViewModel.userHighlights,
                          userNotes: contentViewModel.userNotes,
                          fontSizeMultiplier:
                              fontSizeMultiplier, // Passa o multiplicador
                          isHebrew:
                              isHebrew, // True se esta coluna for hebraica
                          isGreekInterlinear:
                              isGreek, // True se esta coluna for grega interlinear
                          // showHebrewInterlinear e showGreekInterlinear são false aqui,
                          // pois estamos no modo de comparação, e o interlinear complementar não é mostrado.
                          // hebrewVerseData e greekVerseData também são null.
                        );
                      }),
                    ]);
              } else if (verseColumnData.isNotEmpty) {
                // --- RENDERIZA TODOS OS VERSOS DO CAPÍTULO (SE NÃO HOUVER SEÇÕES) ---
                // Isso acontece se o arquivo de seções (blocos) não existir ou estiver vazio.
                return Column(
                    key: ValueKey(
                        'compare_col_all_verses_${currentTranslation}_${selectedBook}_${selectedChapter}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(verseColumnData.length,
                        (verseIndexInChapter) {
                      final verseNumber = verseIndexInChapter + 1;
                      final dynamic verseDataItem =
                          verseColumnData[verseIndexInChapter];
                      return BiblePageWidgets.buildVerseItem(
                          key: ValueKey<String>(
                              'compare_col_all_${currentTranslation}_${selectedBook}_${selectedChapter}_$verseNumber'),
                          verseNumber: verseNumber,
                          verseData: verseDataItem,
                          selectedBook: selectedBook,
                          selectedChapter: selectedChapter,
                          context: context,
                          userHighlights: contentViewModel.userHighlights,
                          userNotes: contentViewModel.userNotes,
                          fontSizeMultiplier:
                              fontSizeMultiplier, // Passa o multiplicador
                          isHebrew: isHebrew,
                          isGreekInterlinear: isGreek
                          // Novamente, sem interlineares complementares no modo de comparação
                          );
                    }));
              }
              // Se não há seções nem dados de verso, retorna um widget vazio.
              return const SizedBox.shrink();
            },
          );
        });
  }
}

class DelayedLoading extends StatefulWidget {
  // ... (sem alterações)
  final bool loading;
  final Widget Function() child;
  final Duration delay;
  final Widget loadingIndicator;
  const DelayedLoading(
      {super.key,
      required this.loading,
      required this.child,
      this.delay = const Duration(milliseconds: 300),
      required this.loadingIndicator});
  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  // ... (sem alterações)
  bool _showLoadingIndicator = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.loading) _startTimer();
  }

  @override
  void didUpdateWidget(DelayedLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _showLoadingIndicator = false;
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _cancelTimer();
      if (mounted) setState(() => _showLoadingIndicator = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted && widget.loading)
        setState(() => _showLoadingIndicator = true);
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoadingIndicator && widget.loading) return widget.loadingIndicator;
    return widget.child();
  }
}
