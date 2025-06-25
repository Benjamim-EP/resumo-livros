// lib/pages/bible_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/bible_search_filter_bar.dart';
import 'package:septima_biblia/pages/biblie_page/bible_search_results_page.dart';
import 'package:septima_biblia/pages/biblie_page/section_item_widget.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/pages/biblie_page/utils.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
// ignore: unused_import
import 'package:septima_biblia/pages/biblie_page/bible_search_results_page.dart'
    show StringExtension;
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/tts_manager.dart';
// import 'package:septima_biblia/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class _BiblePageViewModel {
  final String? initialBook;
  final int? initialBibleChapter;
  // REMOVIDOS: lastReadBookAbbrev, lastReadChapter, userId, pendingWritesCount
  // Eles não são necessários para a lógica de navegação inicial e causam reconstruções desnecessárias.

  _BiblePageViewModel({
    this.initialBook,
    this.initialBibleChapter,
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    // Agora o ViewModel só se importa com a INTENÇÃO de navegação.
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
  Map<String, dynamic>? booksMap;
  String? selectedBook;
  int? selectedChapter;

  bool _isContinuousPlayActive = false;
  final TtsManager _ttsManager = TtsManager();

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

  @override
  void initState() {
    _loadFontSizePreference();
    super.initState();
    _updateFutureBuilderKey(isInitial: true); // Chamar com isInitial
    _loadInitialData();
    _scrollController1.addListener(_syncScrollFrom1To2);
    _scrollController2.addListener(_syncScrollFrom2To1);
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

  // >>> NOVA FUNÇÃO PARA GERAR A FILA DE LEITURA <<<
  Future<void> _handlePlayRequest(
      String startSectionId, TtsContentType contentType) async {
    // Mostra um indicador de "preparando áudio" para o usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 16),
            Text("Preparando áudio..."),
          ],
        ),
        duration: Duration(
            seconds: 10), // Duração longa, será removida programaticamente
      ),
    );

    try {
      // Pega os dados atuais do capítulo
      final chapterData = await BiblePageHelper.loadChapterDataComparison(
        selectedBook!,
        selectedChapter!,
        selectedTranslation1,
        null,
      );

      final List<Map<String, dynamic>> sections =
          List<Map<String, dynamic>>.from(
              chapterData['sectionStructure'] ?? []);
      final dynamic verseData = chapterData['verseData']?[selectedTranslation1];

      if (sections.isEmpty || verseData == null || verseData is! List<String>) {
        ScaffoldMessenger.of(context)
            .removeCurrentSnackBar(); // Remove a msg de "preparando"
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Não foi possível gerar o áudio.")));
        return;
      }

      List<TtsQueueItem> queue = [];

      // Itera sobre todas as seções para construir a fila completa
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

        // 1. Adiciona o título da seção à fila
        final String sectionTitle = section['title'] ?? '';
        if (sectionTitle.isNotEmpty) {
          queue.add(TtsQueueItem(
              sectionId: currentSectionId, textToSpeak: sectionTitle));
        }

        // 2. Adiciona cada versículo como um item separado na fila
        for (int verseNum in verseNumbers) {
          if (verseNum > 0 && verseNum <= verseData.length) {
            final verseText = verseData[verseNum - 1];
            // Adiciona "Versículo X" para clareza no áudio
            queue.add(TtsQueueItem(
                sectionId: currentSectionId,
                textToSpeak: "Versículo $verseNum. $verseText"));
          }
        }

        // 3. Se for modo estudo, busca e adiciona cada parágrafo do comentário
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
              // Adiciona uma introdução para o comentário
              queue.add(TtsQueueItem(
                  sectionId: currentSectionId,
                  textToSpeak: "Comentário da seção."));

              // Adiciona cada parágrafo do comentário como um item separado
              for (var item in commentaryList) {
                final text = (item as Map)['traducao']?.trim() ??
                    (item as Map)['original']?.trim() ??
                    '';
                if (text.isNotEmpty) {
                  queue.add(TtsQueueItem(
                      sectionId: currentSectionId, textToSpeak: text));
                }
              }
            }
          }
        }
      }

      // Remove a mensagem de "preparando" e inicia a fala
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      _ttsManager.speak(queue, startSectionId);
    } catch (e) {
      print("Erro em _handlePlayRequest: $e");
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ocorreu um erro ao preparar o áudio.")));
    }
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
                  icon: Icon(
                    _isContinuousPlayActive
                        ? Icons.playlist_play_rounded
                        : Icons.playlist_add_check_rounded,
                    color: _isContinuousPlayActive
                        ? theme.colorScheme.secondary
                        : theme.iconTheme.color,
                  ),
                  tooltip: _isContinuousPlayActive
                      ? "Desativar Leitura Contínua"
                      : "Ativar Leitura Contínua",
                  onPressed: () {
                    setState(() {
                      _isContinuousPlayActive = !_isContinuousPlayActive;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_isContinuousPlayActive
                          ? "Modo de leitura contínua ativado."
                          : "Modo de leitura contínua desativado."),
                      duration: const Duration(seconds: 2),
                    ));
                  },
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
                if (_showExtraOptions &&
                    !_isSemanticSearchActive &&
                    !_isFocusModeActive)
                  _buildExtraOptionsBar(theme),
                Expanded(
                  child: (selectedBook != null &&
                          selectedChapter != null &&
                          _selectedBookSlug != null &&
                          !_isSemanticSearchActive)
                      ? FutureBuilder<Map<String, dynamic>>(
                          key: _futureBuilderKey,
                          future: BiblePageHelper.loadChapterDataComparison(
                              selectedBook!, // selectedBook não será nulo neste ponto da lógica do build
                              selectedChapter!, // selectedChapter não será nulo neste ponto
                              selectedTranslation1,
                              _isCompareModeActive
                                  ? selectedTranslation2
                                  : null),
                          builder: (context, snapshot) {
                            // ----- INÍCIO DOS LOGS DETALHADOS -----
                            print(
                                "-----------------------------------------------------");
                            print(
                                "BiblePage FutureBuilder - Início do Builder");
                            print("  Key: $_futureBuilderKey");
                            print(
                                "  Selected Book: $selectedBook, Chapter: $selectedChapter, Translation1: $selectedTranslation1, Translation2: $selectedTranslation2, CompareMode: $_isCompareModeActive");
                            print(
                                "  ConnectionState: ${snapshot.connectionState}");

                            if (snapshot.hasError) {
                              print(
                                  "  ERRO NO FUTUREBUILDER: ${snapshot.error}");
                              print(
                                  "  STACKTRACE DO ERRO: ${snapshot.stackTrace}");
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    // Para permitir scroll se a mensagem de erro for longa
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

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              print("  FutureBuilder: Aguardando dados...");
                              return Center(
                                  child: CircularProgressIndicator(
                                      color: theme.colorScheme.primary));
                            }

                            if (!snapshot.hasData || snapshot.data == null) {
                              print(
                                  "  FutureBuilder: Sem dados (snapshot.hasData é false ou snapshot.data é null).");
                              return Center(
                                child: Text(
                                  'Nenhum dado bíblico encontrado para $selectedBook $selectedChapter.',
                                  style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            if (snapshot.data!.isEmpty) {
                              print(
                                  "  FutureBuilder: Dados recebidos, mas o mapa retornado está vazio.");
                              return Center(
                                child: Text(
                                  'Os dados do capítulo $selectedBook $selectedChapter estão vazios ou não foram encontrados corretamente.',
                                  style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            print(
                                "  FutureBuilder: Dados carregados com sucesso. Conteúdo parcial do snapshot.data: ${snapshot.data.toString().substring(0, (snapshot.data.toString().length > 300 ? 300 : snapshot.data.toString().length))}..."); // Log inicial dos dados

                            // ----- FIM DOS LOGS DETALHADOS -----

                            final chapterData = snapshot
                                .data!; // Agora sabemos que não é nulo e não está vazio
                            final List<Map<String, dynamic>> sections =
                                List<Map<String, dynamic>>.from(
                                    chapterData['sectionStructure'] ?? []);
                            final Map<String, dynamic> verseDataMap =
                                Map<String, dynamic>.from(
                                    chapterData['verseData'] ?? {});

                            final dynamic primaryTranslationVerseData =
                                verseDataMap[selectedTranslation1];
                            final dynamic comparisonTranslationVerseData =
                                (_isCompareModeActive &&
                                        selectedTranslation2 != null)
                                    ? verseDataMap[selectedTranslation2!]
                                    : null;

                            bool isCurrentTranslation1PrimaryHebrew =
                                selectedTranslation1 == 'hebrew_original';
                            bool isCurrentTranslation1PrimaryGreek =
                                selectedTranslation1 == 'greek_interlinear';

                            bool primaryDataMissing = false;
                            if (isCurrentTranslation1PrimaryHebrew ||
                                isCurrentTranslation1PrimaryGreek) {
                              primaryDataMissing =
                                  (primaryTranslationVerseData == null ||
                                      (primaryTranslationVerseData is List &&
                                          primaryTranslationVerseData.isEmpty));
                            } else {
                              primaryDataMissing =
                                  (primaryTranslationVerseData == null ||
                                      (primaryTranslationVerseData is List &&
                                          primaryTranslationVerseData.isEmpty));
                            }

                            if (primaryDataMissing) {
                              print(
                                  "  FutureBuilder: primaryDataMissing é true para a tradução principal '$selectedTranslation1'. VerseData: $primaryTranslationVerseData");
                              return Center(
                                  child: Text(
                                'Conteúdo do capítulo não encontrado para a tradução $selectedTranslation1.',
                                style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                    fontSize: 16),
                                textAlign: TextAlign.center,
                              ));
                            }

                            print(
                                "  FutureBuilder: Dados válidos. Chamando DelayedLoading/buildSingleViewContent.");
                            print(
                                "-----------------------------------------------------");

                            return DelayedLoading(
                              loading:
                                  false, // O FutureBuilder já gerenciou o estado de carregamento.
                              // Se você tiver um loading interno no DelayedLoading que dependa do snapshot, ajuste.
                              delay: const Duration(milliseconds: 50),
                              loadingIndicator: Center(
                                  child: CircularProgressIndicator(
                                      color: theme.colorScheme.primary)),
                              child: () {
                                print(
                                    "  DelayedLoading Child: Construindo conteúdo da Bíblia...");
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
                                    isCurrentTranslation1PrimaryHebrew,
                                    isCurrentTranslation1PrimaryGreek,
                                    hebrewDataForInterlinearView,
                                    greekDataForInterlinearView,
                                    _currentFontSizeMultiplier,
                                  );
                                } else {
                                  if (comparisonTranslationVerseData == null ||
                                      (comparisonTranslationVerseData is List &&
                                              comparisonTranslationVerseData
                                                  .isEmpty) &&
                                          selectedTranslation2 != null) {
                                    print(
                                        "  DelayedLoading Child (Compare Mode): Dados da tradução de comparação ($selectedTranslation2) ausentes ou vazios.");
                                    return Center(
                                        child: Text(
                                      'Tradução de comparação "$selectedTranslation2" não encontrada para este capítulo.',
                                      style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ));
                                  }
                                  final list1Data = primaryTranslationVerseData
                                      as List; // Assumindo que não é nulo e é lista
                                  final list2Data =
                                      comparisonTranslationVerseData
                                          as List?; // Pode ser nulo ou lista

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: _buildComparisonColumn(
                                              context,
                                              sections,
                                              list1Data,
                                              _scrollController1,
                                              selectedTranslation1,
                                              isHebrew:
                                                  isCurrentTranslation1PrimaryHebrew,
                                              isGreek:
                                                  isCurrentTranslation1PrimaryGreek,
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
                                              list2Data ??
                                                  [], // Passa lista vazia se nulo
                                              _scrollController2,
                                              selectedTranslation2!, // Não será nulo se _isCompareModeActive e comparisonTranslationVerseData não for nulo
                                              isHebrew: selectedTranslation2 ==
                                                  'hebrew_original',
                                              isGreek: selectedTranslation2 ==
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
                      : (_isSemanticSearchActive &&
                              !_isFocusModeActive) // Se ESTIVER em modo de busca semântica
                          ? StoreConnector<AppState, BibleSearchState>(
                              converter: (store) =>
                                  store.state.bibleSearchState,
                              distinct:
                                  true, // Evita reconstruções desnecessárias se o searchState não mudar
                              onInit: (store) {
                                if (store.state.bibleSearchState.searchHistory
                                        .isEmpty &&
                                    !store.state.bibleSearchState
                                        .isLoadingHistory) {
                                  print(
                                      "BiblePage (Search Mode): Disparando LoadSearchHistoryAction no onInit.");
                                  store.dispatch(LoadSearchHistoryAction());
                                }
                              },
                              builder: (context, searchState) {
                                final theme = Theme.of(
                                    context); // Pega o tema aqui para usar nos widgets filhos

                                // 1. Se está carregando uma NOVA busca (isLoading é true E currentQuery foi definido)
                                if (searchState.isLoading &&
                                    searchState.currentQuery.isNotEmpty) {
                                  print(
                                      "BiblePage Semantic Search: Mostrando loader para nova busca ativa (Query: '${searchState.currentQuery}').");
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                // 2. Se houve um erro na busca (e não está mais carregando)
                                if (!searchState.isLoading &&
                                    searchState.error != null) {
                                  print(
                                      "BiblePage Semantic Search: Mostrando erro: ${searchState.error}");
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                          "Erro na busca: ${searchState.error}",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: theme.colorScheme.error)),
                                    ),
                                  );
                                }

                                // 3. Se houver resultados da busca ATUAL, mostra eles
                                if (searchState.results.isNotEmpty) {
                                  print(
                                      "BiblePage Semantic Search: Mostrando ${searchState.results.length} resultados da busca para '${searchState.currentQuery}'.");
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(8.0),
                                    itemCount: searchState.results.length,
                                    itemBuilder: (context, index) {
                                      final item = searchState.results[index];
                                      final itemId = item['id'] as String? ??
                                          'unknown_id_$index';
                                      Map<String, dynamic> metadata = {};
                                      final rawMetadata = item['metadata'];
                                      if (rawMetadata is Map) {
                                        metadata = Map<String, dynamic>.from(
                                            rawMetadata.map((key, value) =>
                                                MapEntry(
                                                    key.toString(), value)));
                                      }

                                      final tipoResultado =
                                          metadata['tipo'] as String?;
                                      String? commentaryTitle =
                                          metadata['titulo_comentario']
                                              as String?;
                                      final reference =
                                          "${metadata['livro_completo'] ?? metadata['livro_curto'] ?? '?'} ${metadata['capitulo'] ?? '?'}:${metadata['versiculos'] ?? '?'}";
                                      final score = item['score'] as double?;
                                      final bool isExpanded =
                                          _expandedItemId == itemId;

                                      String previewContent =
                                          "Toque para ver detalhes";
                                      if (tipoResultado ==
                                          'biblia_comentario_secao') {
                                        previewContent = commentaryTitle ??
                                            "Ver comentário...";
                                      } else if (tipoResultado ==
                                          'biblia_versiculos') {
                                        previewContent = "Ver versículos...";
                                      }

                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6.0),
                                        color: theme.cardColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ListTile(
                                              title: Text(reference,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.textTheme
                                                          .titleLarge?.color)),
                                              subtitle: Text(previewContent,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: theme.textTheme
                                                          .bodyMedium?.color
                                                          ?.withOpacity(0.7))),
                                              trailing: Icon(
                                                  isExpanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  color: theme.iconTheme.color),
                                              onTap: () =>
                                                  _toggleItemExpansionInBiblePage(
                                                      metadata, itemId),
                                            ),
                                            if (isExpanded)
                                              AnimatedSize(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                                child: Container(
                                                  width: double.infinity,
                                                  color: theme.colorScheme
                                                      .surfaceVariant
                                                      .withOpacity(0.1),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 12.0),
                                                  child:
                                                      _isLoadingExpandedContent
                                                          ? const Center(
                                                              child: Padding(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              8.0),
                                                                  child: SizedBox(
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                      child: CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2.5))))
                                                          : (_loadedExpandedContent !=
                                                                      null &&
                                                                  _loadedExpandedContent!
                                                                      .isNotEmpty
                                                              ? MarkdownBody(
                                                                  data:
                                                                      _loadedExpandedContent!,
                                                                  selectable:
                                                                      true,
                                                                  styleSheet: MarkdownStyleSheet
                                                                          .fromTheme(
                                                                              theme)
                                                                      .copyWith(
                                                                    p: theme.textTheme.bodyMedium?.copyWith(
                                                                        fontSize:
                                                                            14 *
                                                                                _currentFontSizeMultiplier,
                                                                        height:
                                                                            1.5,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                                    strong: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                                    blockSpacing:
                                                                        8.0,
                                                                  ),
                                                                )
                                                              : Text(
                                                                  "Conteúdo não disponível ou não pôde ser carregado.",
                                                                  style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant
                                                                          .withOpacity(
                                                                              0.7)))),
                                                ),
                                              ),
                                            if (isExpanded &&
                                                !_isLoadingExpandedContent &&
                                                _loadedExpandedContent != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 8.0,
                                                    top: 4.0,
                                                    bottom: 8.0),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: TextButton.icon(
                                                    icon: Icon(Icons.menu_book,
                                                        size: 18,
                                                        color: theme.colorScheme
                                                            .primary),
                                                    label: Text(
                                                        "Abrir na Bíblia",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 6),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      final bookAbbrevNav =
                                                          metadata[
                                                                  'livro_curto']
                                                              as String?;
                                                      final chapterStrNav =
                                                          metadata['capitulo']
                                                              ?.toString();
                                                      int? chapterIntNav;
                                                      if (chapterStrNav != null)
                                                        chapterIntNav =
                                                            int.tryParse(
                                                                chapterStrNav);

                                                      if (bookAbbrevNav !=
                                                              null &&
                                                          chapterIntNav !=
                                                              null) {
                                                        StoreProvider.of<
                                                                    AppState>(
                                                                context,
                                                                listen: false)
                                                            .dispatch(SetInitialBibleLocationAction(
                                                                bookAbbrevNav,
                                                                chapterIntNav));
                                                        StoreProvider.of<
                                                                    AppState>(
                                                                context,
                                                                listen: false)
                                                            .dispatch(
                                                                RequestBottomNavChangeAction(
                                                                    1));
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Não foi possível abrir na Bíblia. Dados incompletos.')));
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                            if (score != null && !isExpanded)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 16.0,
                                                    bottom: 8.0,
                                                    top: 0),
                                                child: Text(
                                                    "Similaridade: ${score.toStringAsFixed(3)}",
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.grey[600])),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }

                                // 4. Se NÃO há query ATIVA (campo de busca vazio) E HÁ histórico, mostra o histórico
                                if (searchState.currentQuery.isEmpty &&
                                    searchState.searchHistory.isNotEmpty) {
                                  print(
                                      "BiblePage Semantic Search: Mostrando histórico de ${searchState.searchHistory.length} buscas.");
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0, vertical: 12.0),
                                        child: Text(
                                            "Histórico de Buscas Recentes:",
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    color: theme
                                                        .colorScheme.onSurface
                                                        .withOpacity(0.9))),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount:
                                              searchState.searchHistory.length,
                                          itemBuilder: (context, index) {
                                            final historyEntry = searchState
                                                .searchHistory[index];
                                            final String query =
                                                historyEntry['query']
                                                        as String? ??
                                                    'Busca inválida';
                                            final String? timestampStr =
                                                historyEntry['timestamp']
                                                    as String?;
                                            final DateTime? timestamp =
                                                timestampStr != null
                                                    ? DateTime.tryParse(
                                                        timestampStr)
                                                    : null;

                                            return ListTile(
                                              leading: Icon(Icons.history,
                                                  color: theme.iconTheme.color
                                                      ?.withOpacity(0.6)),
                                              title: Text(query,
                                                  style: theme
                                                      .textTheme.bodyLarge),
                                              subtitle: timestamp != null
                                                  ? Text(
                                                      DateFormat(
                                                              'dd/MM/yy HH:mm')
                                                          .format(timestamp
                                                              .toLocal()),
                                                      style: theme
                                                          .textTheme.bodySmall)
                                                  : null,
                                              trailing: Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 16,
                                                  color: theme.iconTheme.color
                                                      ?.withOpacity(0.5)),
                                              onTap: () {
                                                _semanticQueryController.text =
                                                    query;
                                                StoreProvider.of<AppState>(
                                                        context,
                                                        listen: false)
                                                    .dispatch(
                                                        ViewSearchFromHistoryAction(
                                                            historyEntry));
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // 5. Se houve uma busca ATIVA mas não encontrou resultados (e não está carregando)
                                if (!searchState.isLoading &&
                                    searchState.results.isEmpty &&
                                    searchState.currentQuery.isNotEmpty) {
                                  print(
                                      "BiblePage Semantic Search: Nenhum resultado para '${searchState.currentQuery}'.");
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        "Nenhum resultado encontrado para '${searchState.currentQuery}' com os filtros aplicados.",
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  );
                                }

                                // 6. Mensagem padrão (campo de busca vazio e sem histórico, ou carregando histórico)
                                print(
                                    "BiblePage Semantic Search: Exibindo mensagem padrão/carregando histórico (isLoadingHistory: ${searchState.isLoadingHistory}).");
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      searchState.isLoadingHistory
                                          ? "Carregando histórico..."
                                          : "Digite sua busca acima e pressione o ícone de lupa para pesquisar. Seu histórico aparecerá aqui.",
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                ),
                Visibility(
                    visible: !_isFocusModeActive &&
                        !_isSemanticSearchActive &&
                        !_showExtraOptions,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12.0),
                      child: Row(children: [
                        IconButton(
                            icon: Icon(Icons.chevron_left,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                                size: 32),
                            onPressed: _previousChapter,
                            tooltip: "Capítulo Anterior",
                            splashRadius: 24),
                        Expanded(
                            flex: 3,
                            child: UtilsBiblePage.buildBookDropdown(
                                context: context,
                                selectedBook: selectedBook,
                                booksMap: booksMap,
                                onChanged: (value) {
                                  if (mounted && value != null)
                                    _navigateToChapter(value, 1);
                                },
                                iconColor: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                                textColor: theme.colorScheme.onSurface,
                                backgroundColor:
                                    theme.cardColor.withOpacity(0.15))),
                        const SizedBox(width: 8),
                        if (selectedBook != null)
                          Expanded(
                              flex: 2,
                              child: UtilsBiblePage.buildChapterDropdown(
                                  context: context,
                                  selectedChapter: selectedChapter,
                                  booksMap: booksMap,
                                  selectedBook: selectedBook,
                                  onChanged: (value) {
                                    if (mounted &&
                                        value != null &&
                                        selectedBook != null) {
                                      _navigateToChapter(selectedBook!, value);
                                    }
                                  },
                                  iconColor: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  textColor: theme.colorScheme.onSurface,
                                  backgroundColor:
                                      theme.cardColor.withOpacity(0.15))),
                        IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                                size: 32),
                            onPressed: _nextChapter,
                            tooltip: "Próximo Capítulo",
                            splashRadius: 24),
                      ]),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtraOptionsBar(ThemeData theme) {
    bool isCurrentTranslation1PrimaryHebrew =
        selectedTranslation1 == 'hebrew_original';
    bool isCurrentTranslation1PrimaryGreek =
        selectedTranslation1 == 'greek_interlinear';

    bool canShowHebrewToggle =
        booksMap?[selectedBook]?['testament'] == 'Antigo' &&
            !isCurrentTranslation1PrimaryHebrew &&
            !_isCompareModeActive;

    bool canShowGreekToggle = booksMap?[selectedBook]?['testament'] == 'Novo' &&
        !isCurrentTranslation1PrimaryGreek &&
        !_isCompareModeActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.1),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0, // Espaçamento horizontal entre os botões
        runSpacing:
            4.0, // Espaçamento vertical entre as linhas de botões (se quebrar)
        children: [
          // Botão para selecionar a Tradução 1
          ElevatedButton.icon(
            icon: const Icon(Icons.translate, size: 18),
            label: Text(selectedTranslation1.toUpperCase(),
                style: const TextStyle(fontSize: 12)),
            onPressed: () {
              // <<< MODIFICAR ESTE onPressed
              BiblePageWidgets.showTranslationSelection(
                context: context,
                selectedTranslation: selectedTranslation1,
                onTranslationSelected: (value) {
                  if (mounted && value != selectedTranslation2) {
                    // >>> INÍCIO DA MODIFICAÇÃO <<<
                    interstitialManager
                        .tryShowInterstitial(
                            fromScreen:
                                "BiblePage_ChangeTranslation1_To_$value")
                        .then((_) {
                      if (mounted) {
                        setState(() {
                          selectedTranslation1 = value;
                          if ((value == 'hebrew_original' &&
                                  selectedTranslation2 == 'hebrew_original') ||
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
                    // >>> FIM DA MODIFICAÇÃO <<<
                  }
                },
                currentSelectedBookAbbrev: selectedBook,
                booksMap: booksMap,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1),
          ),

          // Botão para selecionar a Tradução 2 (se estiver no modo de comparação)
          if (_isCompareModeActive)
            ElevatedButton.icon(
              icon: const Icon(Icons.translate, size: 18),
              label: Text(selectedTranslation2?.toUpperCase() ?? '...',
                  style: const TextStyle(fontSize: 12)),
              onPressed: () {
                // <<< MODIFICAR ESTE onPressed
                BiblePageWidgets.showTranslationSelection(
                  context: context,
                  selectedTranslation: selectedTranslation2 ?? 'acf',
                  onTranslationSelected: (value) {
                    if (mounted && value != selectedTranslation1) {
                      // >>> INÍCIO DA MODIFICAÇÃO <<<
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
                      // >>> FIM DA MODIFICAÇÃO <<<
                    }
                  },
                  currentSelectedBookAbbrev: selectedBook,
                  booksMap: booksMap,
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.cardColor,
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 1),
            ),

          // Botão de Estudos
          ElevatedButton.icon(
            icon: const Icon(Icons.school_outlined, size: 18),
            label: const Text("Estudos", style: TextStyle(fontSize: 12)),
            onPressed: () {
              if (mounted) {
                interstitialManager
                    .tryShowInterstitial(fromScreen: "BiblePage_To_StudyHub")
                    .then((_) {
                  // Certifique-se que o contexto ainda é válido se a operação for assíncrona
                  if (mounted) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StudyHubPage()));
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1),
          ),

          // Botão Modo Foco
          IconButton(
            icon: Icon(
                _isFocusModeActive ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 22),
            tooltip: _isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura",
            onPressed: () {
              if (mounted) {
                setState(() => _isFocusModeActive = !_isFocusModeActive);
                _updateFutureBuilderKey(); // Atualiza a chave para reconstruir a UI se necessário
              }
            },
            color: _isFocusModeActive
                ? theme.colorScheme.secondary
                : theme.iconTheme.color,
            splashRadius: 20,
          ),

          // Botão Modo Comparação
          IconButton(
            icon: Icon(
                _isCompareModeActive
                    ? Icons.compare_arrows // Ícone preenchido quando ativo
                    : Icons
                        .compare_arrows_outlined, // Ícone contornado quando inativo
                size: 22),
            tooltip: _isCompareModeActive
                ? "Desativar Comparação"
                : "Comparar Traduções",
            onPressed: () {
              if (mounted) {
                setState(() {
                  _isCompareModeActive = !_isCompareModeActive;
                  // Se ativou comparação e as duas traduções são iguais, muda a segunda
                  if (_isCompareModeActive &&
                      selectedTranslation1 == selectedTranslation2) {
                    selectedTranslation2 =
                        (selectedTranslation1 == 'nvi') ? 'acf' : 'nvi';
                  }
                  // Se desativou comparação, remove a segunda tradução
                  if (!_isCompareModeActive) {
                    selectedTranslation2 = null;
                  }
                  // Se o modo interlinear estava ativo e agora estamos comparando, desativa o interlinear
                  // (a menos que queira permitir interlinear em uma das colunas de comparação)
                  if (_isCompareModeActive) {
                    if (_showHebrewInterlinear &&
                        selectedTranslation1 == 'hebrew_original') {
                      // Não faz nada, pois o hebraico original já é uma das traduções principais
                    } else if (_showHebrewInterlinear) {
                      _showHebrewInterlinear = false;
                    }
                    if (_showGreekInterlinear &&
                        selectedTranslation1 == 'greek_interlinear') {
                      // Não faz nada
                    } else if (_showGreekInterlinear) {
                      _showGreekInterlinear = false;
                    }
                  }
                  _updateFutureBuilderKey();
                });
              }
            },
            color: _isCompareModeActive
                ? theme.colorScheme.secondary // Cor de destaque quando ativo
                : theme.iconTheme.color,
            splashRadius: 20,
          ),

          // Botão Toggle Hebraico Interlinear
          if (canShowHebrewToggle)
            IconButton(
              icon: Icon(
                  _showHebrewInterlinear
                      ? Icons.font_download_off_outlined // Ícone quando ativo
                      : Icons.font_download_outlined, // Ícone quando inativo
                  size: 22),
              tooltip: _showHebrewInterlinear
                  ? "Ocultar Hebraico Interlinear"
                  : "Mostrar Hebraico Interlinear",
              onPressed: () {
                if (!_showHebrewInterlinear) {
                  // Se está prestes a se tornar true
                  interstitialManager.tryShowInterstitial(
                      fromScreen: "BiblePage_ToggleHebrewInterlinear");
                }
                setState(() {
                  _showHebrewInterlinear = !_showHebrewInterlinear;
                  if (_showHebrewInterlinear) {
                    _showGreekInterlinear =
                        false; // Desativa o grego se o hebraico for ativado
                    _loadCurrentChapterHebrewDataIfNeeded();
                  } else {
                    _currentChapterHebrewData =
                        null; // Limpa os dados se desativado
                  }
                  _updateFutureBuilderKey();
                });
              },
              color: _showHebrewInterlinear
                  ? theme.colorScheme.secondary // Cor de destaque quando ativo
                  : theme.iconTheme.color,
              splashRadius: 20,
            ),

          // Botão Toggle Grego Interlinear
          if (canShowGreekToggle)
            IconButton(
              icon: Icon(
                  _showGreekInterlinear
                      ? Icons.font_download_off_outlined // Ícone quando ativo
                      : Icons.font_download_outlined, // Ícone quando inativo
                  size: 22),
              tooltip: _showGreekInterlinear
                  ? "Ocultar Grego Interlinear"
                  : "Mostrar Grego Interlinear",
              onPressed: () {
                if (!_showGreekInterlinear) {
                  // Se está prestes a se tornar true
                  interstitialManager.tryShowInterstitial(
                      fromScreen: "BiblePage_ToggleGreekInterlinear");
                }
                setState(() {
                  _showGreekInterlinear = !_showGreekInterlinear;
                  if (_showGreekInterlinear) {
                    _showHebrewInterlinear =
                        false; // Desativa o hebraico se o grego for ativado
                    _loadCurrentChapterGreekDataIfNeeded();
                  } else {
                    _currentChapterGreekData =
                        null; // Limpa os dados se desativado
                  }
                  _updateFutureBuilderKey();
                });
              },
              color: _showGreekInterlinear
                  ? theme.colorScheme.secondary // Cor de destaque quando ativo
                  : theme.iconTheme.color,
              splashRadius: 20,
            ),
          // --- NOVOS BOTÕES PARA TAMANHO DA FONTE ---
          IconButton(
            icon: Icon(Icons.text_decrease_outlined, size: 22),
            tooltip: "Diminuir Fonte",
            onPressed: _currentFontSizeMultiplier > MIN_FONT_MULTIPLIER
                ? _decreaseFontSize
                : null, // Desabilita se no mínimo
            color: _currentFontSizeMultiplier > MIN_FONT_MULTIPLIER
                ? theme.iconTheme.color
                : theme.disabledColor,
            splashRadius: 20,
          ),
          // Exibir o multiplicador atual (opcional, para feedback)
          // Text("${(_currentFontSizeMultiplier * 100).toInt()}%", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
          IconButton(
            icon: Icon(Icons.text_increase_outlined, size: 22),
            tooltip: "Aumentar Fonte",
            onPressed: _currentFontSizeMultiplier < MAX_FONT_MULTIPLIER
                ? _increaseFontSize
                : null, // Desabilita se no máximo
            color: _currentFontSizeMultiplier < MAX_FONT_MULTIPLIER
                ? theme.iconTheme.color
                : theme.disabledColor,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

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
                isContinuousPlayActive: _isContinuousPlayActive,
                onPlayRequest: _handlePlayRequest,
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
