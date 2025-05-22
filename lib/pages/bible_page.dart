// lib/pages/bible_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _BiblePageViewModel {
  final String? initialBook;
  final int? initialBibleChapter;
  final String? lastReadBookAbbrev;
  final int? lastReadChapter;
  final String? userId;
  final int pendingWritesCount;

  _BiblePageViewModel({
    this.initialBook,
    this.initialBibleChapter,
    this.lastReadBookAbbrev,
    this.lastReadChapter,
    this.userId,
    required this.pendingWritesCount,
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    return _BiblePageViewModel(
      initialBook: store.state.userState.initialBibleBook,
      initialBibleChapter: store.state.userState.initialBibleChapter,
      lastReadBookAbbrev: store.state.userState.lastReadBookAbbrev,
      lastReadChapter: store.state.userState.lastReadChapter,
      userId: store.state.userState.userId,
      pendingWritesCount: store.state.userState.pendingFirestoreWrites.length,
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

  @override
  int get hashCode =>
      initialBook.hashCode ^
      initialBibleChapter.hashCode ^
      lastReadBookAbbrev.hashCode ^
      lastReadChapter.hashCode ^
      pendingWritesCount.hashCode ^
      userId.hashCode;
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

  @override
  void initState() {
    super.initState();
    _updateFutureBuilderKey(isInitial: true); // Chamar com isInitial
    _loadInitialData();
    _scrollController1.addListener(_syncScrollFrom1To2);
    _scrollController2.addListener(_syncScrollFrom2To1);
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
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-$_selectedBookSlug-${_showHebrewInterlinear}-${_showGreekInterlinear}$keySuffix'); // <<< ADICIONADO _showGreekInterlinear
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

  void _processIntentOrInitialLoad(
      BuildContext context, _BiblePageViewModel vm) {
    // ... (sem alterações significativas, _applyNavigationState já cuida da lógica de interlinear)
    if (!mounted || booksMap == null) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    String targetBook;
    int targetChapter;
    bool isFromIntent = false;

    if (vm.initialBook != null && vm.initialBibleChapter != null) {
      targetBook = vm.initialBook!;
      targetChapter = vm.initialBibleChapter!;
      isFromIntent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) store.dispatch(SetInitialBibleLocationAction(null, null));
      });
    } else {
      targetBook = vm.lastReadBookAbbrev ?? selectedBook ?? 'gn';
      targetChapter = vm.lastReadChapter ?? selectedChapter ?? 1;
    }

    if (booksMap!.containsKey(targetBook)) {
      final bookData = booksMap![targetBook];
      if (targetChapter < 1 || targetChapter > (bookData['capitulos'] as int)) {
        targetChapter = 1;
      }
    } else {
      targetBook = 'gn';
      targetChapter = 1;
    }
    _applyNavigationState(targetBook, targetChapter,
        forceKeyUpdate: isFromIntent || selectedBook == null);
    if (!_hasProcessedInitialNavigation &&
        selectedBook != null &&
        selectedChapter != null) {
      _hasProcessedInitialNavigation = true;
      _loadUserDataIfNeeded(context);
    }
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
    // ... (sem alterações)
    final currentRef = "${bookAbbrev}_$chapter";
    if (_lastRecordedHistoryRef != currentRef) {
      if (mounted) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(RecordReadingHistoryAction(bookAbbrev, chapter));
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
    // ... (sem alterações)
    if (_isSemanticSearchActive) {
      return [
        IconButton(
          icon: Icon(Icons.search,
              color: theme.appBarTheme.actionsIconTheme?.color),
          tooltip: "Buscar com filtros",
          onPressed: _applyFiltersToReduxAndSearch,
        ),
        IconButton(
          icon: Icon(Icons.close,
              color: theme.appBarTheme.actionsIconTheme?.color),
          tooltip: "Fechar Busca",
          onPressed: () {
            if (mounted) {
              setState(() {
                _isSemanticSearchActive = false;
                _showExtraOptions = false;
              });
            }
          },
        ),
      ];
    } else if (_isFocusModeActive) {
      return [
        IconButton(
          icon: Icon(Icons.fullscreen_exit,
              color: theme.appBarTheme.actionsIconTheme?.color ??
                  theme.colorScheme.onPrimary),
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
    } else {
      return [
        // if (viewModel.pendingWritesCount > 0)
        //   Padding(
        //     padding: const EdgeInsets.only(right: 0.0),
        //     child: Center(
        //       child: Badge(
        //         label: Text('${viewModel.pendingWritesCount}',
        //             style: TextStyle(
        //                 fontSize: 10, color: theme.colorScheme.onError)),
        //         backgroundColor: theme.colorScheme.error,
        //         padding: const EdgeInsets.symmetric(horizontal: 5),
        //         child: IconButton(
        //           icon: Icon(Icons.sync_problem_outlined,
        //               color: theme.colorScheme.error, size: 24),
        //           tooltip:
        //               "Sincronizar Alterações (${viewModel.pendingWritesCount} pendentes)",
        //           onPressed: () {
        //             StoreProvider.of<AppState>(context, listen: false)
        //                 .dispatch(ProcessPendingFirestoreWritesAction());
        //             if (mounted) {
        //               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        //                   content: Text(
        //                       "Tentando sincronizar... Verifique o console.")));
        //             }
        //           },
        //         ),
        //       ),
        //     ),
        //   ),
        IconButton(
          icon: Icon(Icons.manage_search_outlined,
              color: theme.appBarTheme.actionsIconTheme?.color),
          tooltip: "Ir para referência",
          onPressed: _showGoToDialog,
        ),
        IconButton(
          icon: Icon(Icons.search_sharp,
              color: theme.appBarTheme.actionsIconTheme?.color),
          tooltip: "Busca Semântica",
          onPressed: () {
            if (mounted) {
              setState(() {
                _isSemanticSearchActive = true;
                _showExtraOptions = false;
              });
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert,
              color: theme.appBarTheme.actionsIconTheme?.color),
          tooltip: "Mais Opções",
          onPressed: () {
            setState(() {
              _showExtraOptions = !_showExtraOptions;
            });
          },
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _BiblePageViewModel>(
      converter: (store) => _BiblePageViewModel.fromStore(store),
      onInit: (store) {
        _store = store; // Garante que _store é inicializado
        // Carrega dados iniciais se o booksMap já estiver pronto e a navegação inicial não ocorreu
        if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasProcessedInitialNavigation) {
              _processIntentOrInitialLoad(
                  context, _BiblePageViewModel.fromStore(store));
            }
          });
        }
        _loadUserDataIfNeeded(
            context); // Carrega dados do usuário (progresso, etc.)

        // Sincroniza filtros locais com o estado Redux na inicialização
        final initialFilters = store.state.bibleSearchState.activeFilters;
        if (_filterSelectedTestament != initialFilters['testamento'] ||
            _filterSelectedBookAbbrev != initialFilters['livro_curto'] ||
            _filterSelectedContentType != initialFilters['tipo']) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Adia para após o build
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
        // Lida com mudanças no ViewModel, como navegação por intent
        if (mounted && booksMap != null) {
          if (!_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                _processIntentOrInitialLoad(context, newViewModel);
              }
            });
          } else if (newViewModel.initialBook !=
                  previousViewModel?.initialBook ||
              newViewModel.initialBibleChapter !=
                  previousViewModel?.initialBibleChapter) {
            // Se houver uma nova intent de localização (ex: vindo de um link ou outra página)
            if (newViewModel.initialBook != null &&
                newViewModel.initialBibleChapter != null) {
              _processIntentOrInitialLoad(context, newViewModel);
            }
          }
        }
      },
      builder: (context, viewModel) {
        // Widget de carregamento se os dados básicos não estiverem prontos
        if (booksMap == null || _bookVariationsMap.isEmpty) {
          return Scaffold(
              appBar: AppBar(title: const Text('Bíblia')),
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary)));
        }
        // Widget de carregamento se o livro/capítulo inicial ainda não foi definido
        if (selectedBook == null || selectedChapter == null) {
          // Dispara o carregamento inicial se ainda não foi feito e o widget está montado
          if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                _processIntentOrInitialLoad(context, viewModel);
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
        String appBarTitle = (booksMap?[selectedBook]?['nome'] ?? 'Bíblia');
        if (!_isSemanticSearchActive) {
          if (_isFocusModeActive) {
            appBarTitle = booksMap![selectedBook]!['nome'] ?? 'Bíblia';
            if (selectedChapter != null) appBarTitle += ' $selectedChapter';
          } else if (_isCompareModeActive) {
            appBarTitle = 'Comparar Traduções';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: _isSemanticSearchActive
                ? TextField(
                    controller: _semanticQueryController,
                    autofocus: true,
                    style: TextStyle(
                        color: theme.appBarTheme.foregroundColor ??
                            theme.colorScheme.onPrimary),
                    decoration: InputDecoration(
                      hintText: 'Busca semântica na Bíblia...',
                      hintStyle: TextStyle(
                          color: (theme.appBarTheme.foregroundColor ??
                                  theme.colorScheme.onPrimary)
                              .withOpacity(0.7)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (query) {
                      _applyFiltersToReduxAndSearch();
                    },
                  )
                : Text(appBarTitle),
            leading: _isFocusModeActive || _isSemanticSearchActive
                ? const SizedBox
                    .shrink() // Remove o botão de voltar nesses modos
                : null, // Mantém o botão de voltar padrão caso contrário
            actions: _buildAppBarActions(context, theme, viewModel),
          ),
          body: PageStorage(
            // Preserva o estado de rolagem
            bucket: _pageStorageBucket,
            child: Column(
              children: [
                // Filtros para busca semântica (visível apenas se a busca estiver ativa e não em modo foco)
                if (_isSemanticSearchActive && !_isFocusModeActive)
                  _buildSemanticSearchFilterWidgets(theme),

                // Barra de opções extras (traduções, interlinear, etc.)
                if (_showExtraOptions &&
                    !_isSemanticSearchActive &&
                    !_isFocusModeActive)
                  _buildExtraOptionsBar(theme),

                // Conteúdo principal (versículos/seções)
                Expanded(
                  child: (selectedBook != null &&
                          selectedChapter != null &&
                          _selectedBookSlug !=
                              null && // Garante que o slug do livro foi carregado
                          !_isSemanticSearchActive) // Não mostra se a busca semântica está ativa
                      ? FutureBuilder<Map<String, dynamic>>(
                          key:
                              _futureBuilderKey, // Chave para reconstruir quando necessário
                          future: BiblePageHelper.loadChapterDataComparison(
                              selectedBook!,
                              selectedChapter!,
                              selectedTranslation1,
                              _isCompareModeActive
                                  ? selectedTranslation2
                                  : null),
                          builder: (context, snapshot) {
                            // Flags para determinar o tipo da tradução principal
                            bool isCurrentTranslation1PrimaryHebrew =
                                selectedTranslation1 == 'hebrew_original';
                            bool isCurrentTranslation1PrimaryGreek =
                                selectedTranslation1 == 'greek_interlinear';

                            return DelayedLoading(
                              // Melhora a UX do carregamento
                              loading: snapshot.connectionState ==
                                  ConnectionState.waiting,
                              delay: const Duration(milliseconds: 200),
                              loadingIndicator: Center(
                                  child: CircularProgressIndicator(
                                      color: theme.colorScheme.primary)),
                              child: () {
                                // Constrói o conteúdo quando os dados estão prontos ou erro
                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data == null) {
                                  return Center(
                                      child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                              'Erro: ${snapshot.error ?? 'Dados não encontrados para $selectedBook $selectedChapter em $selectedTranslation1.'}',
                                              style: TextStyle(
                                                  color:
                                                      theme.colorScheme.error),
                                              textAlign: TextAlign.center)));
                                }
                                final chapterData = snapshot.data!;
                                final List<Map<String, dynamic>> sections =
                                    chapterData['sectionStructure'] ?? [];
                                final Map<String, dynamic> verseDataMap =
                                    chapterData['verseData'] ?? {};
                                final dynamic primaryTranslationVerseData =
                                    verseDataMap[selectedTranslation1];
                                final dynamic comparisonTranslationVerseData =
                                    (_isCompareModeActive &&
                                            selectedTranslation2 != null)
                                        ? verseDataMap[selectedTranslation2!]
                                        : null;

                                // Verifica se os dados da tradução primária estão faltando
                                bool primaryDataMissing = false;
                                if (isCurrentTranslation1PrimaryHebrew ||
                                    isCurrentTranslation1PrimaryGreek) {
                                  primaryDataMissing =
                                      (primaryTranslationVerseData == null ||
                                          (primaryTranslationVerseData as List)
                                              .isEmpty);
                                } else {
                                  primaryDataMissing =
                                      (primaryTranslationVerseData == null ||
                                          (primaryTranslationVerseData
                                                  as List<String>)
                                              .isEmpty);
                                }
                                if (primaryDataMissing) {
                                  return Center(
                                      child: Text(
                                          'Capítulo não encontrado para $selectedTranslation1.',
                                          style: TextStyle(
                                              color: theme.textTheme.bodyMedium
                                                  ?.color)));
                                }

                                // Lógica para modo de visualização única ou comparativa
                                if (!_isCompareModeActive) {
                                  // Modo de visualização única
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

                                  return _buildSingleViewContent(
                                      theme,
                                      sections,
                                      primaryTranslationVerseData,
                                      isCurrentTranslation1PrimaryHebrew,
                                      isCurrentTranslation1PrimaryGreek,
                                      hebrewDataForInterlinearView,
                                      greekDataForInterlinearView);
                                } else {
                                  // Modo de comparação
                                  if (comparisonTranslationVerseData == null ||
                                      (comparisonTranslationVerseData as List)
                                              .isEmpty &&
                                          selectedTranslation2 != null) {
                                    return Center(
                                        child: Text(
                                            'Tradução "$selectedTranslation2" não encontrada.',
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.error)));
                                  }
                                  final list1Data =
                                      primaryTranslationVerseData as List;
                                  final list2Data =
                                      comparisonTranslationVerseData as List?;
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
                                              list2Data ?? [],
                                              _scrollController2,
                                              selectedTranslation2!,
                                              isHebrew: selectedTranslation2 ==
                                                  'hebrew_original',
                                              isGreek: selectedTranslation2 ==
                                                  'greek_interlinear',
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
                              !_isFocusModeActive) // Mensagem para busca semântica
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _semanticQueryController.text.isEmpty
                                      ? "Digite sua busca e aplique filtros se desejar."
                                      : "Pressione o botão de busca para ver os resultados.",
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: theme.textTheme.bodyMedium?.color),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : const SizedBox
                              .shrink(), // Para outros casos (ex: modo foco ou erro inicial)
                ),

                // Navegação de capítulo (visível apenas se não estiver em modo foco, busca ou opções extras)
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
                                color: theme.iconTheme.color, size: 32),
                            onPressed: _previousChapter,
                            tooltip: "Capítulo Anterior",
                            splashRadius: 24),
                        Expanded(
                            flex: 3, // Dá mais espaço para o nome do livro
                            child: UtilsBiblePage.buildBookDropdown(
                                selectedBook: selectedBook,
                                booksMap: booksMap,
                                onChanged: (value) {
                                  if (mounted && value != null)
                                    _navigateToChapter(value, 1);
                                })),
                        const SizedBox(width: 8),
                        if (selectedBook !=
                            null) // Só mostra o dropdown de capítulo se um livro estiver selecionado
                          Expanded(
                              flex: 2, // Menos espaço para o número do capítulo
                              child: UtilsBiblePage.buildChapterDropdown(
                                  selectedChapter: selectedChapter,
                                  booksMap: booksMap,
                                  selectedBook: selectedBook,
                                  onChanged: (value) {
                                    if (mounted &&
                                        value != null &&
                                        selectedBook != null) {
                                      _navigateToChapter(selectedBook!, value);
                                    }
                                  })),
                        IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: theme.iconTheme.color, size: 32),
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
        ],
      ),
    );
  }

  Widget _buildSemanticSearchFilterWidgets(ThemeData theme) {
    // Lista de testamentos disponíveis para o dropdown
    List<String> testamentosDisponiveis = ["Antigo", "Novo"];

    // Monta os itens do DropdownButton para os livros
    List<DropdownMenuItem<String>> bookItems = [
      DropdownMenuItem<String>(
          value: null, // Representa "Todos Livros"
          child: Text("Todos Livros",
              style: TextStyle(fontSize: 12, color: theme.hintColor))),
    ];
    if (booksMap != null && booksMap!.isNotEmpty) {
      // Ordena os livros pelo nome para exibição no dropdown
      List<MapEntry<String, dynamic>> sortedBooks = booksMap!.entries.toList()
        ..sort((a, b) =>
            (a.value['nome'] as String).compareTo(b.value['nome'] as String));
      for (var entry in sortedBooks) {
        bookItems.add(DropdownMenuItem<String>(
          value: entry.key, // A abreviação do livro como valor
          child: Text(
              entry.value['nome'] as String, // Nome completo para exibição
              style: TextStyle(
                  fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
        ));
      }
    }

    // Monta os itens do DropdownButton para os tipos de conteúdo
    List<DropdownMenuItem<String>> typeItems = [
      DropdownMenuItem<String>(
          value: null, // Representa "Todos Tipos"
          child: Text("Todos Tipos",
              style: TextStyle(fontSize: 12, color: theme.hintColor))),
    ];
    for (var tipoMap in _tiposDeConteudoDisponiveisParaFiltro) {
      typeItems.add(DropdownMenuItem<String>(
        value: tipoMap['value'], // O valor da chave 'value' do mapa
        child: Text(
            tipoMap['display']!, // O valor da chave 'display' para o texto
            style: TextStyle(
                fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.05), // Um fundo sutil
          border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5))),
      child: SingleChildScrollView(
        // Permite rolagem horizontal se os filtros não couberem
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            // Dropdown para Testamento
            SizedBox(
                width: 125, // Largura fixa para o dropdown de testamento
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text("Testamento",
                            style: TextStyle(
                                fontSize: 12, color: theme.hintColor)),
                        value: _filterSelectedTestament,
                        items: [
                          DropdownMenuItem<String>(
                              value: null, // Opção para limpar/selecionar todos
                              child: Text(
                                  "Todos Test.", // Abreviação para "Todos Testamentos"
                                  style: TextStyle(
                                      fontSize: 12, color: theme.hintColor))),
                          ...testamentosDisponiveis.map(
                              (String value) => // Mapeia a lista de testamentos
                                  DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme.textTheme.bodyLarge
                                                  ?.color))))
                        ],
                        onChanged: (String? newValue) {
                          setState(() => _filterSelectedTestament = newValue);
                          // A busca real com filtros é feita ao pressionar o botão "Buscar" ou "Aplicar Filtros"
                          // Opcionalmente, poderia chamar _store.dispatch(SetBibleSearchFilterAction) aqui
                          // se quisesse que o filtro fosse aplicado no Redux imediatamente.
                        },
                        style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 12),
                        dropdownColor: theme.dialogBackgroundColor,
                        iconEnabledColor: theme.iconTheme.color))),
            const SizedBox(width: 6),

            // Dropdown para Livro
            SizedBox(
                width: 140, // Largura fixa para o dropdown de livro
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text("Livro",
                            style: TextStyle(
                                fontSize: 12, color: theme.hintColor)),
                        value: _filterSelectedBookAbbrev,
                        items: bookItems, // Itens de livro montados acima
                        onChanged: (String? newValue) {
                          setState(() => _filterSelectedBookAbbrev = newValue);
                        },
                        style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 12),
                        dropdownColor: theme.dialogBackgroundColor,
                        iconEnabledColor: theme.iconTheme.color))),
            const SizedBox(width: 6),

            // Dropdown para Tipo de Conteúdo
            SizedBox(
                width: 155, // Largura para o dropdown de tipo
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text("Tipo",
                            style: TextStyle(
                                fontSize: 12, color: theme.hintColor)),
                        value: _filterSelectedContentType,
                        items: typeItems, // Itens de tipo montados acima
                        onChanged: (String? newValue) {
                          setState(() => _filterSelectedContentType = newValue);
                        },
                        style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 12),
                        dropdownColor: theme.dialogBackgroundColor,
                        iconEnabledColor: theme.iconTheme.color))),
            const SizedBox(width: 10),

            // Botão para limpar filtros
            IconButton(
                icon: Icon(Icons.clear_all,
                    size: 20, color: theme.iconTheme.color?.withOpacity(0.7)),
                tooltip: "Limpar Filtros",
                onPressed:
                    _clearFiltersInReduxAndResetLocal, // Chama a função de limpar
                padding: EdgeInsets.zero, // Remove padding extra
                constraints:
                    const BoxConstraints()), // Garante que o botão não seja muito grande
          ],
        ),
      ),
    );
  }

  Widget _buildSingleViewContent(
      ThemeData theme,
      List<Map<String, dynamic>> sections,
      dynamic primaryTranslationVerseData,
      bool isPrimaryTranslationHebrew,
      bool isPrimaryTranslationGreek, // <<< NOVO
      dynamic hebrewInterlinearChapterData,
      dynamic greekInterlinearChapterData // <<< NOVO
      ) {
    return StoreConnector<AppState, _BibleContentViewModel>(
      converter: (store) =>
          _BibleContentViewModel.fromStore(store, selectedBook),
      builder: (context, contentViewModel) {
        final listViewKey = PageStorageKey<String>(
            '$selectedBook-$selectedChapter-$selectedTranslation1-singleView-content-$_showHebrewInterlinear-$_showGreekInterlinear'); // <<< ADICIONADO AO KEY
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
                  ? 1
                  : 0),
          itemBuilder: (context, sectionIndex) {
            if (sections.isNotEmpty) {
              final section = sections[sectionIndex];
              // ... (lógica de sectionId, isSectionRead sem alterações) ...
              final String versesRange = (section['verses'] as List?)
                          ?.cast<int>()
                          .isNotEmpty ??
                      false
                  ? ((section['verses'] as List).cast<int>().length == 1
                      ? (section['verses'] as List).cast<int>().first.toString()
                      : "${(section['verses'] as List).cast<int>().first}-${(section['verses'] as List).cast<int>().last}")
                  : "all";
              final String currentSectionId =
                  "${selectedBook}_c${selectedChapter}_v$versesRange";
              final bool isSectionRead = contentViewModel
                  .readSectionsForCurrentBook
                  .contains(currentSectionId);

              // <<< LÓGICA PARA DADOS INTERLINEARES DA SEÇÃO (HEBRAICO E GREGO) >>>
              List<List<Map<String, String>>>? hebrewDataForThisSection;
              if (_showHebrewInterlinear &&
                  hebrewInterlinearChapterData != null &&
                  hebrewInterlinearChapterData is List) {
                hebrewDataForThisSection = [];
                for (int verseNumInOriginalChapter
                    in (section['verses'] as List?)?.cast<int>() ?? []) {
                  if (verseNumInOriginalChapter > 0 &&
                      verseNumInOriginalChapter <=
                          hebrewInterlinearChapterData.length) {
                    hebrewDataForThisSection.add(List<Map<String, String>>.from(
                        hebrewInterlinearChapterData[
                            verseNumInOriginalChapter - 1]));
                  } else {
                    hebrewDataForThisSection.add([]);
                  }
                }
              }

              List<List<Map<String, String>>>?
                  greekDataForThisSection; // <<< NOVO
              if (_showGreekInterlinear &&
                  greekInterlinearChapterData != null &&
                  greekInterlinearChapterData is List) {
                greekDataForThisSection = [];
                for (int verseNumInOriginalChapter
                    in (section['verses'] as List?)?.cast<int>() ?? []) {
                  if (verseNumInOriginalChapter > 0 &&
                      verseNumInOriginalChapter <=
                          greekInterlinearChapterData.length) {
                    greekDataForThisSection.add(List<Map<String, String>>.from(
                        greekInterlinearChapterData[
                            verseNumInOriginalChapter - 1]));
                  } else {
                    greekDataForThisSection.add([]);
                  }
                }
              }
              // <<< FIM LÓGICA DADOS INTERLINEARES >>>

              return SectionItemWidget(
                  key: ValueKey(
                      '${_selectedBookSlug}_${selectedChapter}_${section['title']}_${versesRange}_${selectedTranslation1}_$isSectionRead${_showHebrewInterlinear ? '_hebInt' : ''}${_showGreekInterlinear ? '_grkInt' : ''}'), // <<< ADICIONADO AO KEY
                  sectionTitle: section['title'] ?? 'Seção',
                  verseNumbersInSection:
                      (section['verses'] as List?)?.cast<int>() ?? [],
                  allVerseDataInChapter: primaryTranslationVerseData,
                  bookSlug: _selectedBookSlug!,
                  bookAbbrev: selectedBook!,
                  chapterNumber: selectedChapter!,
                  versesRangeStr: versesRange,
                  userHighlights: contentViewModel.userHighlights,
                  userNotes: contentViewModel.userNotes,
                  isHebrew: isPrimaryTranslationHebrew,
                  isGreekInterlinear: isPrimaryTranslationGreek, // <<< NOVO
                  isRead: isSectionRead,
                  showHebrewInterlinear:
                      _showHebrewInterlinear && !isPrimaryTranslationHebrew,
                  showGreekInterlinear: _showGreekInterlinear &&
                      !isPrimaryTranslationGreek, // <<< NOVO
                  hebrewInterlinearSectionData: hebrewDataForThisSection,
                  greekInterlinearSectionData:
                      greekDataForThisSection // <<< NOVO
                  );
            } else if (primaryTranslationVerseData != null &&
                (primaryTranslationVerseData as List).isNotEmpty) {
              // Renderiza todos os versos do capítulo se não houver seções
              final List listData = primaryTranslationVerseData;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      List.generate(listData.length, (verseIndexInChapter) {
                    final verseNumber = verseIndexInChapter + 1;

                    List<Map<String, String>>? hebrewVerseForInterlinear;
                    if (_showHebrewInterlinear &&
                        !isPrimaryTranslationHebrew &&
                        hebrewInterlinearChapterData != null &&
                        hebrewInterlinearChapterData is List &&
                        verseIndexInChapter <
                            hebrewInterlinearChapterData.length) {
                      hebrewVerseForInterlinear =
                          List<Map<String, String>>.from(
                              hebrewInterlinearChapterData[
                                  verseIndexInChapter]);
                    }

                    // <<< DADOS PARA INTERLINEAR GREGO COMPLEMENTAR (nível do verso) >>>
                    List<Map<String, String>>? greekVerseForInterlinear;
                    if (_showGreekInterlinear &&
                        !isPrimaryTranslationGreek &&
                        greekInterlinearChapterData != null &&
                        greekInterlinearChapterData is List &&
                        verseIndexInChapter <
                            greekInterlinearChapterData.length) {
                      greekVerseForInterlinear = List<Map<String, String>>.from(
                          greekInterlinearChapterData[verseIndexInChapter]);
                    }
                    // <<< FIM DADOS INTERLINEAR GREGO >>>

                    return BiblePageWidgets.buildVerseItem(
                        key: ValueKey<String>(
                            '${selectedBook}_${selectedChapter}_${verseNumber}_$selectedTranslation1${_showHebrewInterlinear ? '_hebInt' : ''}${_showGreekInterlinear ? '_grkInt' : ''}'), // <<< ADICIONADO AO KEY
                        verseNumber: verseNumber,
                        verseData: listData[verseIndexInChapter],
                        selectedBook: selectedBook,
                        selectedChapter: selectedChapter,
                        context: context,
                        userHighlights: contentViewModel.userHighlights,
                        userNotes: contentViewModel.userNotes,
                        isHebrew: isPrimaryTranslationHebrew,
                        isGreekInterlinear:
                            isPrimaryTranslationGreek, // <<< NOVO
                        showHebrewInterlinear: _showHebrewInterlinear &&
                            !isPrimaryTranslationHebrew,
                        showGreekInterlinear: _showGreekInterlinear &&
                            !isPrimaryTranslationGreek, // <<< NOVO
                        hebrewVerseData: hebrewVerseForInterlinear,
                        greekVerseData: greekVerseForInterlinear // <<< NOVO
                        );
                  }));
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List verseColumnData,
      ScrollController scrollController,
      String currentTranslation,
      {bool isHebrew = false,
      bool isGreek = false, // <<< NOVO para diferenciar no modo comparativo
      required PageStorageKey listViewKey}) {
    final theme = Theme.of(context);
    // ... (resto da lógica sem alterações significativas, apenas passa isGreek para buildVerseItem) ...
    if (verseColumnData.isEmpty &&
        sections.isEmpty &&
        currentTranslation.isNotEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Tradução '$currentTranslation' indisponível.",
                  style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color, fontSize: 13),
                  textAlign: TextAlign.center)));
    }
    return StoreConnector<AppState, _BibleContentViewModel>(
        converter: (store) =>
            _BibleContentViewModel.fromStore(store, selectedBook),
        builder: (context, contentViewModel) {
          return ListView.builder(
            key: listViewKey,
            controller: scrollController,
            padding: EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 16.0,
                top: _isFocusModeActive ? 8.0 : 0.0),
            itemCount: sections.isNotEmpty
                ? sections.length
                : (verseColumnData.isNotEmpty ? 1 : 0),
            itemBuilder: (context, sectionIndex) {
              if (sections.isNotEmpty) {
                // ... (renderização de seção no modo comparativo) ...
                // Ao chamar BiblePageWidgets.buildVerseItem aqui, passe isGreek: isGreek
                final section = sections[sectionIndex];
                final String sectionTitle = section['title'] ?? 'Seção';
                final List<int> verseNumbers =
                    (section['verses'] as List?)?.cast<int>() ?? [];
                final String versesRange = (section['verses'] as List?)
                            ?.cast<int>()
                            .isNotEmpty ??
                        false
                    ? ((section['verses'] as List).cast<int>().length == 1
                        ? (section['verses'] as List)
                            .cast<int>()
                            .first
                            .toString()
                        : "${(section['verses'] as List).cast<int>().first}-${(section['verses'] as List).cast<int>().last}")
                    : "all";
                final String currentSectionId =
                    "${selectedBook}_c${selectedChapter}_v$versesRange";
                final bool isSectionRead = contentViewModel
                    .readSectionsForCurrentBook
                    .contains(currentSectionId);
                final String sectionKeyIdentifier =
                    section['verses']?.join('-') ?? sectionTitle;

                return Column(
                    key: ValueKey(
                        'compare_section_${sectionTitle}_${currentTranslation}_$sectionKeyIdentifier${isSectionRead ? '_read' : '_unread'}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding:
                              const EdgeInsets.only(top: 16.0, bottom: 4.0),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(sectionTitle,
                                        style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold))),
                                IconButton(
                                    icon: Icon(
                                        isSectionRead
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        color: isSectionRead
                                            ? theme.primaryColor
                                            : theme.iconTheme.color
                                                ?.withOpacity(0.7),
                                        size: 20),
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
                      ...verseNumbers.map((verseNumber) {
                        final verseIndex = verseNumber - 1;
                        dynamic verseDataItemForColumn;
                        if (verseIndex >= 0 &&
                            verseIndex < verseColumnData.length) {
                          verseDataItemForColumn = verseColumnData[verseIndex];
                        } else {
                          verseDataItemForColumn = (isHebrew || isGreek)
                              ? []
                              : "[Texto Indisponível]"; // Ajusta para interlinear
                        }
                        return BiblePageWidgets.buildVerseItem(
                          key: ValueKey<String>(
                              '${selectedBook}_${selectedChapter}_${verseNumber}_$currentTranslation'),
                          verseNumber: verseNumber,
                          verseData: verseDataItemForColumn,
                          selectedBook: selectedBook,
                          selectedChapter: selectedChapter,
                          context: context,
                          userHighlights: contentViewModel.userHighlights,
                          userNotes: contentViewModel.userNotes,
                          isHebrew: isHebrew,
                          isGreekInterlinear: isGreek, // <<< Passa isGreek
                          // Não passamos showHebrew/GreekInterlinear ou dados complementares aqui
                          // pois o modo comparativo mostra as traduções principais lado a lado.
                        );
                      }),
                    ]);
              } else if (verseColumnData.isNotEmpty) {
                return Column(
                    key: ValueKey(
                        'all_verses_column_${currentTranslation}_${selectedBook}_${selectedChapter}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        List.generate(verseColumnData.length, (verseIndex) {
                      final verseNumber = verseIndex + 1;
                      final dynamic verseDataItem = verseColumnData[verseIndex];
                      return BiblePageWidgets.buildVerseItem(
                          key: ValueKey<String>(
                              '${selectedBook}_${selectedChapter}_${verseNumber}_$currentTranslation'),
                          verseNumber: verseNumber,
                          verseData: verseDataItem,
                          selectedBook: selectedBook,
                          selectedChapter: selectedChapter,
                          context: context,
                          userHighlights: contentViewModel.userHighlights,
                          userNotes: contentViewModel.userNotes,
                          isHebrew: isHebrew,
                          isGreekInterlinear: isGreek // <<< Passa isGreek
                          );
                    }));
              }
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
