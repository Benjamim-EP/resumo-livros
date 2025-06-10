// lib/pages/bible_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resumo_dos_deuses_flutter/components/login_required.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_search_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/study_hub_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
// ignore: unused_import
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_search_results_page.dart'
    show StringExtension;
import 'package:shared_preferences/shared_preferences.dart';

class _BiblePageViewModel {
  final String? initialBook;
  final int? initialBibleChapter;
  final String? lastReadBookAbbrev;
  final int? lastReadChapter;
  final String? userId;
  final int pendingWritesCount;
  //final String? initialSectionIdToScrollTo; // NOVO

  _BiblePageViewModel({
    this.initialBook,
    this.initialBibleChapter,
    this.lastReadBookAbbrev,
    this.lastReadChapter,
    this.userId,
    required this.pendingWritesCount,
    //this.initialSectionIdToScrollTo, // NOVO
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    return _BiblePageViewModel(
      initialBook: store.state.userState.initialBibleBook,
      initialBibleChapter: store.state.userState.initialBibleChapter,
      lastReadBookAbbrev: store.state.userState.lastReadBookAbbrev,
      lastReadChapter: store.state.userState.lastReadChapter,
      userId: store.state.userState.userId,
      pendingWritesCount: store.state.userState.pendingFirestoreWrites.length,
      //initialSectionIdToScrollTo:
      //  store.state.userState.initialBibleSectionIdToScrollTo, // NOVO
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BiblePageViewModel &&
          runtimeType == other.runtimeType &&
          initialBook == other.initialBook &&
          initialBibleChapter == other.initialBibleChapter &&
          lastReadBookAbbrev == other.lastReadBookAbbrev &&
          lastReadChapter == other.lastReadChapter &&
          pendingWritesCount == other.pendingWritesCount &&
          userId == other.userId;
  //initialSectionIdToScrollTo ==
  //    (other as _BiblePageViewModel).initialSectionIdToScrollTo;

  @override
  int get hashCode =>
      initialBook.hashCode ^
      initialBibleChapter.hashCode ^
      lastReadBookAbbrev.hashCode ^
      lastReadChapter.hashCode ^
      pendingWritesCount.hashCode ^
      userId.hashCode;
  //initialSectionIdToScrollTo.hashCode;
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

  String selectedTranslation1 = 'nvi';
  String? selectedTranslation2 = 'acf';
  bool _isCompareModeActive = false;
  bool _isFocusModeActive = false;

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
  String? _filterSelectedTestament;
  String? _filterSelectedBookAbbrev;
  String? _filterSelectedContentType;
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
    bool bookOrChapterChanged =
        selectedBook != book || selectedChapter != chapter;

    // <<< LÓGICA PARA GREGO INTERLINEAR (similar ao hebraico) >>>
    if (selectedBook != book) {
      // Se o livro mudou
      final newBookData = booksMap?[book] as Map<String, dynamic>?;

      // Se o novo livro NÃO for do Antigo Testamento, desabilita opções hebraicas
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

      // Se o novo livro NÃO for do Novo Testamento, desabilita opções gregas
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
    // <<< FIM LÓGICA PARA GREGO INTERLINEAR >>>

    if (bookOrChapterChanged) {
      if (mounted) {
        setState(() {
          selectedBook = book;
          selectedChapter = chapter;
          _currentChapterHebrewData = null; // Limpa dados anteriores
          _currentChapterGreekData = null; // <<< LIMPA DADOS GREGOS
          _updateSelectedBookSlug();
          if (_showHebrewInterlinear) _loadCurrentChapterHebrewDataIfNeeded();
          if (_showGreekInterlinear)
            _loadCurrentChapterGreekDataIfNeeded(); // <<< CARREGA GREGO SE NECESSÁRIO
        });
      }
    }
    if (bookOrChapterChanged || forceKeyUpdate) {
      _updateFutureBuilderKey();
      _recordHistory(book, chapter);
    }
  }

  void _processIntentOrInitialLoad(_BiblePageViewModel vm) {
    if (!mounted || booksMap == null) {
      print(
          "BiblePage: _processIntentOrInitialLoad - Abortando: widget não montado ou booksMap nulo.");
      return;
    }

    // NÃO LIMPE A INTENT DO REDUX AQUI.
    // A limpeza será feita DENTRO do itemBuilder, após o scroll.

    String targetBook;
    int targetChapter;
    String?
        targetSectionIdFromVM; // Usar uma variável local para o ID da seção do ViewModel
    bool isFromIntent = false;

    //print(
    //    "BiblePage: _processIntentOrInitialLoad - Iniciando. ViewModel: initialBook=${vm.initialBook}, initialChapter=${vm.initialBibleChapter}, initialSectionId=${vm.initialSectionIdToScrollTo}");

    if (vm.initialBook != null && vm.initialBibleChapter != null) {
      targetBook = vm.initialBook!;
      targetChapter = vm.initialBibleChapter!;
      //targetSectionIdFromVM =
      //    vm.initialSectionIdToScrollTo; // Captura o ID da seção da intent
      isFromIntent = true;
      print(
          "BiblePage: _processIntentOrInitialLoad - Navegação via intent: Livro: $targetBook, Cap: $targetChapter, Seção: $targetSectionIdFromVM");
    } else {
      // Carregamento inicial ou retorno à aba sem intent específica
      targetBook = vm.lastReadBookAbbrev ?? selectedBook ?? 'gn';
      targetChapter = vm.lastReadChapter ?? selectedChapter ?? 1;
      targetSectionIdFromVM =
          null; // Sem scroll se não for de uma intent com sectionId
      print(
          "BiblePage: _processIntentOrInitialLoad - Carregamento normal/última leitura: Livro: $targetBook, Cap: $targetChapter");
    }

    // Validação do livro e capítulo
    if (booksMap!.containsKey(targetBook)) {
      final bookData = booksMap![targetBook];
      final int totalChaptersInBook = (bookData['capitulos'] as int?) ?? 0;
      if (targetChapter < 1 ||
          (totalChaptersInBook > 0 && targetChapter > totalChaptersInBook)) {
        print(
            "BiblePage: _processIntentOrInitialLoad - Capítulo $targetChapter inválido para $targetBook (total: $totalChaptersInBook). Resetando para 1.");
        targetChapter = 1;
        targetSectionIdFromVM =
            null; // Se o capítulo for inválido, o ID da seção também não faz sentido
      }
    } else {
      print(
          "BiblePage: _processIntentOrInitialLoad - Livro $targetBook não encontrado. Resetando para Gênesis 1.");
      targetBook = 'gn';
      targetChapter = 1;
      targetSectionIdFromVM = null;
    }

    // Aplica o estado de navegação (livro e capítulo)
    // O 'forceKeyUpdate' é importante se a intent for para o mesmo livro/capítulo que já está selecionado,
    // mas queremos forçar uma reconstrução (ex: para o scroll).
    _applyNavigationState(targetBook, targetChapter,
        forceKeyUpdate: isFromIntent);

    // Armazena o ID da seção para o qual rolar, se houver.
    // O setState aqui irá disparar uma reconstrução, e o itemBuilder no _buildSingleViewContent
    // usará _sectionIdToScrollAfterLoad para tentar o scroll.
    if (mounted) {
      setState(() {
        _sectionIdToScrollAfterLoad = targetSectionIdFromVM;
        if (targetSectionIdFromVM != null) {
          print(
              "BiblePage: _processIntentOrInitialLoad - _sectionIdToScrollAfterLoad definido para: $_sectionIdToScrollAfterLoad");
        }
      });
    }

    // Marca que o processamento inicial foi feito e carrega dados do usuário se necessário
    if (!_hasProcessedInitialNavigation &&
        selectedBook != null &&
        selectedChapter != null) {
      _hasProcessedInitialNavigation = true;
      print(
          "BiblePage: _processIntentOrInitialLoad - _hasProcessedInitialNavigation = true. Carregando dados do usuário.");
      _loadUserDataIfNeeded(context); // context da BiblePage é usado aqui
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
    // ... (sem alterações)
    if (!mounted || _store == null) return;
    if (_store!.state.userState.isGuestUser) {
      // NOVO CHECK
      showLoginRequiredDialog(context,
          featureName: "a busca avançada na Bíblia");
      return;
    }
    _store!.dispatch(
        SetBibleSearchFilterAction('testamento', _filterSelectedTestament));
    _store!.dispatch(
        SetBibleSearchFilterAction('livro_curto', _filterSelectedBookAbbrev));
    _store!.dispatch(
        SetBibleSearchFilterAction('tipo', _filterSelectedContentType));
    final queryToSearch = _semanticQueryController.text.trim();
    if (queryToSearch.isNotEmpty) {
      _store!.dispatch(SearchBibleSemanticAction(queryToSearch));
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  BibleSearchResultsPage(initialQuery: queryToSearch)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite um termo para buscar.')));
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
      // Ações quando a busca semântica está INATIVA
      if (viewModel.pendingWritesCount > 0) {
        actions.add(Padding(
          padding: const EdgeInsets.only(right: 0.0),
          child: Center(
            child: Badge(
              label: Text('${viewModel.pendingWritesCount}',
                  style: TextStyle(
                      fontSize: 10, color: theme.colorScheme.onError)),
              backgroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: IconButton(
                icon: Icon(Icons.sync_problem_outlined,
                    color: theme.colorScheme.error, size: 24),
                tooltip:
                    "Sincronizar Alterações (${viewModel.pendingWritesCount} pendentes)",
                onPressed: () {
                  StoreProvider.of<AppState>(context, listen: false)
                      .dispatch(ProcessPendingFirestoreWritesAction());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Tentando sincronizar... Verifique o console.")));
                  }
                },
              ),
            ),
          ),
        ));
      }
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
          final store = StoreProvider.of<AppState>(context, listen: false);
          if (store.state.userState.isGuestUser) {
            showLoginRequiredDialog(context,
                featureName: "a busca avançada na Bíblia");
          } else {
            setState(() {
              _isSemanticSearchActive = true;
              _showExtraOptions = false;
            });
          }
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
      onDidChange: (previousViewModel, newViewModel) {
        if (mounted && booksMap != null) {
          if (!_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                _processIntentOrInitialLoad(newViewModel);
              }
            });
          } else if (newViewModel.initialBook !=
                  previousViewModel?.initialBook ||
              newViewModel.initialBibleChapter !=
                  previousViewModel?.initialBibleChapter) {
            if (newViewModel.initialBook != null &&
                newViewModel.initialBibleChapter != null) {
              _processIntentOrInitialLoad(newViewModel);
            }
          }
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
            actions: _buildAppBarActions(context, theme, viewModel),
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
                      : (_isSemanticSearchActive && !_isFocusModeActive)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _semanticQueryController.text.isEmpty &&
                                          (_store?.state.bibleSearchState
                                                  .results.isEmpty ??
                                              true)
                                      ? "Digite sua busca acima e pressione o ícone de lupa para pesquisar."
                                      : ((_store?.state.bibleSearchState
                                                  .isLoading ??
                                              false)
                                          ? "Buscando..."
                                          : ((_store?.state.bibleSearchState
                                                          .results.isEmpty ??
                                                      true) &&
                                                  _semanticQueryController
                                                      .text.isNotEmpty
                                              ? "Nenhum resultado encontrado para '${_semanticQueryController.text}'."
                                              : "Resultados da busca são exibidos em uma nova página (verifique se a navegação ocorreu). Se não, ajuste o fluxo.")),
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: theme.textTheme.bodyMedium?.color),
                                  textAlign: TextAlign.center,
                                ),
                              ),
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
            onPressed: () => BiblePageWidgets.showTranslationSelection(
              context: context,
              selectedTranslation: selectedTranslation1,
              onTranslationSelected: (value) {
                if (mounted && value != selectedTranslation2) {
                  // Evita selecionar a mesma tradução da segunda coluna
                  setState(() {
                    selectedTranslation1 = value;
                    // Se a nova tradução for hebraica/grega e a segunda também, ajusta a segunda
                    if ((value == 'hebrew_original' &&
                            selectedTranslation2 == 'hebrew_original') ||
                        (value == 'greek_interlinear' &&
                            selectedTranslation2 == 'greek_interlinear')) {
                      selectedTranslation2 = (value == 'nvi' || value == 'acf')
                          ? 'aa'
                          : 'nvi'; // Escolhe uma diferente
                    }
                    _updateFutureBuilderKey();
                    // Se a nova tradução principal for interlinear, desativa o interlinear complementar
                    if (value == 'hebrew_original' && _showHebrewInterlinear)
                      _showHebrewInterlinear = false;
                    if (value == 'greek_interlinear' && _showGreekInterlinear)
                      _showGreekInterlinear = false;
                  });
                }
              },
              currentSelectedBookAbbrev: selectedBook,
              booksMap: booksMap,
            ),
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
              label: Text(
                  selectedTranslation2?.toUpperCase() ??
                      '...', // Mostra '...' se nulo
                  style: const TextStyle(fontSize: 12)),
              onPressed: () => BiblePageWidgets.showTranslationSelection(
                context: context,
                selectedTranslation:
                    selectedTranslation2 ?? 'acf', // Padrão se nulo
                onTranslationSelected: (value) {
                  if (mounted && value != selectedTranslation1) {
                    // Evita selecionar a mesma tradução da primeira coluna
                    setState(() {
                      selectedTranslation2 = value;
                      _updateFutureBuilderKey();
                    });
                  }
                },
                currentSelectedBookAbbrev: selectedBook,
                booksMap: booksMap,
              ),
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StudyHubPage()));
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

  Widget _buildFilterChipButton({
    required BuildContext context,
    required String label, // O que está selecionado ou o placeholder
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false, // Para indicar se um filtro está ativo
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isActive
            ? theme.colorScheme
                .onPrimaryContainer // Cor do ícone quando filtro está ativo
            : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive
              ? theme.colorScheme
                  .onPrimaryContainer // Cor do texto quando filtro está ativo
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: isActive
          ? theme.colorScheme.primaryContainer
              .withOpacity(0.8) // Cor de fundo quando ativo
          : theme.inputDecorationTheme.fillColor ??
              theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? theme.colorScheme.primaryContainer
              : theme.dividerColor.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      elevation: isActive ? 1 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    );
  }

  Widget _buildSemanticSearchFilterWidgets(ThemeData theme) {
    // Lista de testamentos disponíveis
    List<String> testamentosDisponiveis = ["Antigo", "Novo"];

    // Monta os itens do Dropdown para os livros (para o BottomSheet)
    List<DropdownMenuItem<String>> bookDropdownItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos os Livros",
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)))),
    ];
    if (booksMap != null && booksMap!.isNotEmpty) {
      List<MapEntry<String, dynamic>> sortedBooks = booksMap!.entries.toList()
        ..sort((a, b) =>
            (a.value['nome'] as String).compareTo(b.value['nome'] as String));
      for (var entry in sortedBooks) {
        bookDropdownItems.add(DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value['nome'] as String,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        ));
      }
    }

    // Monta os itens do Dropdown para os tipos de conteúdo (para o BottomSheet)
    List<DropdownMenuItem<String>> typeDropdownItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos os Tipos",
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)))),
    ];
    for (var tipoMap in _tiposDeConteudoDisponiveisParaFiltro) {
      typeDropdownItems.add(DropdownMenuItem<String>(
        value: tipoMap['value'],
        child: Text(tipoMap['display']!,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
      ));
    }

    // Função para mostrar o BottomSheet de seleção
    Future<T?> _showFilterSelectionSheet<T>({
      required BuildContext context, // O contexto do builder da BiblePage
      required String title,
      required List<DropdownMenuItem<T>> items,
      required T? currentValue,
      required ValueChanged<T?> onChanged,
    }) {
      return showModalBottomSheet<T>(
        context: context, // Usa o contexto passado
        backgroundColor: theme.dialogBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext modalContext) {
          // modalContext é o contexto do BottomSheet
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<T>(
                  value: currentValue,
                  items: items,
                  onChanged: (T? newValue) {
                    onChanged(newValue);
                    Navigator.pop(
                        modalContext); // Fecha o BottomSheet após a seleção
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ??
                        theme.cardColor.withOpacity(0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10), // Ajustado
                  ),
                  dropdownColor: theme.dialogBackgroundColor,
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                  iconEnabledColor: theme.iconTheme.color,
                  isExpanded: true, // Garante que o dropdown ocupe a largura
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
              bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3), width: 0.5))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _buildFilterChipButton(
              context: context, // Passa o contexto da BiblePage
              icon: Icons.menu_book_outlined,
              label: _filterSelectedTestament ?? "Testamento",
              isActive: _filterSelectedTestament != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context, // Passa o contexto da BiblePage
                  title: "Selecionar Testamento",
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text("Todos os Testamentos",
                            style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7)))),
                    ...testamentosDisponiveis.map((String value) =>
                        DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color)))),
                  ],
                  currentValue: _filterSelectedTestament,
                  onChanged: (String? newValue) {
                    setState(() => _filterSelectedTestament = newValue);
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChipButton(
              context: context, // Passa o contexto da BiblePage
              icon: Icons.auto_stories_outlined,
              label: _filterSelectedBookAbbrev != null
                  ? (booksMap?[_filterSelectedBookAbbrev]?['nome'] ?? "Livro")
                  : "Livro",
              isActive: _filterSelectedBookAbbrev != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context, // Passa o contexto da BiblePage
                  title: "Selecionar Livro",
                  items: bookDropdownItems,
                  currentValue: _filterSelectedBookAbbrev,
                  onChanged: (String? newValue) {
                    setState(() => _filterSelectedBookAbbrev = newValue);
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChipButton(
              context: context, // Passa o contexto da BiblePage
              icon: Icons.category_outlined,
              label: _filterSelectedContentType != null
                  ? (_tiposDeConteudoDisponiveisParaFiltro.firstWhere(
                      (t) => t['value'] == _filterSelectedContentType,
                      orElse: () => {'display': "Tipo"})['display']!)
                  : "Tipo",
              isActive: _filterSelectedContentType != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context, // Passa o contexto da BiblePage
                  title: "Selecionar Tipo de Conteúdo",
                  items: typeDropdownItems,
                  currentValue: _filterSelectedContentType,
                  onChanged: (String? newValue) {
                    setState(() => _filterSelectedContentType = newValue);
                  },
                );
              },
            ),
            if (_filterSelectedTestament != null ||
                _filterSelectedBookAbbrev != null ||
                _filterSelectedContentType != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.clear_all_rounded,
                    size: 22, color: theme.colorScheme.error.withOpacity(0.8)),
                tooltip: "Limpar Filtros",
                onPressed: () {
                  _clearFiltersInReduxAndResetLocal();
                },
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
              ),
            ]
          ],
        ),
      ),
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
