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
import 'package:flutter/foundation.dart'; // for mapEquals, listEquals, setEquals
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';

// ViewModel para o StoreConnector da BiblePage (PRINCIPAL)
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

// ViewModel para o StoreConnector INTERNO (mais específico para o conteúdo)
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
  bool _showHebrewInterlinear = false;
  Map<String, dynamic>? _currentChapterHebrewData;

  String? _lastRecordedHistoryRef;
  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};

  late ValueKey _futureBuilderKey;
  bool _hasProcessedInitialNavigation = false;

  bool _isSemanticSearchActive = false;
  final TextEditingController _semanticQueryController =
      TextEditingController();

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  bool _isSyncingScroll = false;

  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _futureBuilderKey = ValueKey(
        '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-initial');
    _loadInitialData();
    _scrollController1.addListener(_syncScrollFrom1To2);
    _scrollController2.addListener(_syncScrollFrom2To1);
  }

  @override
  void dispose() {
    _semanticQueryController.dispose();
    _scrollController1.removeListener(_syncScrollFrom1To2);
    _scrollController2.removeListener(_syncScrollFrom2To1);
    _scrollController1.dispose();
    _scrollController2.dispose();

    if (mounted &&
        StoreProvider.of<AppState>(context, listen: false)
            .state
            .userState
            .pendingFirestoreWrites
            .isNotEmpty) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ProcessPendingFirestoreWritesAction());
      print(
          "BiblePage dispose: Disparando ProcessPendingFirestoreWritesAction.");
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
        print("Erro ao carregar dados hebraicos para interlinear: $e");
        if (mounted) {
          setState(() {
            _currentChapterHebrewData = null;
          });
        }
      }
    } else if (!_showHebrewInterlinear && _currentChapterHebrewData != null) {
      if (mounted) {
        setState(() {
          _currentChapterHebrewData = null;
        });
      }
    }
  }

  void _syncScrollFrom1To2() {
    if (_isSyncingScroll) return;
    if (!_scrollController1.hasClients || !_scrollController2.hasClients)
      return;
    _isSyncingScroll = true;
    if (_scrollController2.offset != _scrollController1.offset) {
      _scrollController2.jumpTo(_scrollController1.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  void _syncScrollFrom2To1() {
    if (_isSyncingScroll) return;
    if (!_scrollController1.hasClients || !_scrollController2.hasClients)
      return;
    _isSyncingScroll = true;
    if (_scrollController1.offset != _scrollController2.offset) {
      _scrollController1.jumpTo(_scrollController2.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  String _normalizeSearchText(String text) {
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
    accentMap.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _loadInitialData() async {
    final generalBooksMap = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        booksMap = generalBooksMap;
      });
    }
    await _loadBookVariationsMapForGoTo();
    await BiblePageHelper.loadAndCacheStrongsLexicon();
  }

  Future<void> _loadBookVariationsMapForGoTo() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/Biblia/book_variations_map_search.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      final Map<String, String> normalizedMap = {};
      decodedJson.forEach((key, value) {
        normalizedMap[_normalizeSearchText(key)] = value.toString();
      });
      if (mounted) {
        setState(() {
          _bookVariationsMap = normalizedMap;
        });
      }
    } catch (e) {
      print("Erro ao carregar book_variations_map_search.json: $e");
      if (mounted) setState(() => _bookVariationsMap = {});
    }
  }

  void _updateFutureBuilderKey() {
    if (mounted) {
      setState(() {
        _futureBuilderKey = ValueKey(
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-${_selectedBookSlug ?? 'no_slug'}');
      });
    }
  }

  void _applyNavigationState(String book, int chapter,
      {bool forceKeyUpdate = false}) {
    if (!mounted) return;
    bool bookOrChapterChanged =
        selectedBook != book || selectedChapter != chapter;

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
          // Desativa interlinear se não for AT
          if (mounted) setState(() => _showHebrewInterlinear = false);
        }
      }
    }

    if (bookOrChapterChanged) {
      if (mounted) {
        setState(() {
          selectedBook = book;
          selectedChapter = chapter;
          _currentChapterHebrewData = null;
          _updateSelectedBookSlug();
          if (_showHebrewInterlinear) {
            _loadCurrentChapterHebrewDataIfNeeded();
          }
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
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (store.state.userState.userId != null) {
      if (store.state.userState.readSectionsByBook.isEmpty)
        store.dispatch(LoadAllBibleProgressAction());
    }
  }

  void _updateSelectedBookSlug() {
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
      if (mounted)
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(RecordReadingHistoryAction(bookAbbrev, chapter));
      _lastRecordedHistoryRef = currentRef;
    }
  }

  void _navigateToChapter(String bookAbbrev, int chapter) {
    _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
  }

  void _previousChapter() {
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
    // ... (como antes)
  }

  void _parseAndNavigateForGoTo(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    // ... (como antes)
  }

  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
    // ... (como antes)
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _BiblePageViewModel>(
      converter: (store) => _BiblePageViewModel.fromStore(store),
      onInit: (store) {
        if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasProcessedInitialNavigation) {
              _processIntentOrInitialLoad(
                  context, _BiblePageViewModel.fromStore(store));
            }
          });
        }
        _loadUserDataIfNeeded(context);
      },
      onDidChange: (previousViewModel, newViewModel) {
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
            if (newViewModel.initialBook != null &&
                newViewModel.initialBibleChapter != null) {
              _processIntentOrInitialLoad(context, newViewModel);
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

        String appBarTitle = _isSemanticSearchActive
            ? ''
            : (booksMap?[selectedBook]?['nome'] ?? 'Bíblia');
        if (!_isSemanticSearchActive) {
          if (_isFocusModeActive &&
              selectedBook != null &&
              booksMap != null &&
              booksMap!.containsKey(selectedBook)) {
            appBarTitle = booksMap![selectedBook]!['nome'] ?? 'Bíblia';
            if (selectedChapter != null) appBarTitle += ' $selectedChapter';
          } else if (_isCompareModeActive) {
            appBarTitle = 'Comparar Traduções';
          } else if (selectedBook != null &&
              booksMap != null &&
              booksMap!.containsKey(selectedBook)) {
            appBarTitle = booksMap![selectedBook]!['nome'] ?? 'Bíblia';
            if (selectedChapter != null) appBarTitle += ' $selectedChapter';
          }
        }

        bool isCurrentTranslation1PrimaryHebrew =
            selectedTranslation1 == 'hebrew_original';
        bool canShowHebrewToggle = booksMap?[selectedBook]?['testament'] ==
                'Antigo' &&
            !isCurrentTranslation1PrimaryHebrew && // Só mostra se a principal não for hebraico
            !_isCompareModeActive;

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
                      if (query.isNotEmpty && mounted) {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(SearchBibleSemanticAction(query));
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => BibleSearchResultsPage(
                                    initialQuery: query)));
                      }
                    },
                  )
                : Text(appBarTitle),
            leading: _isFocusModeActive || _isSemanticSearchActive
                ? const SizedBox.shrink()
                : null,
            actions: _isSemanticSearchActive
                ? [/* ... Ações de busca semântica ... */]
                : [
                    if (!_isFocusModeActive && viewModel.pendingWritesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 0.0),
                        child: Center(
                          child: Badge(
                            label: Text('${viewModel.pendingWritesCount}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onError)),
                            backgroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: IconButton(
                              icon: Icon(Icons.sync_problem_outlined,
                                  color: theme.colorScheme.error, size: 24),
                              tooltip:
                                  "Sincronizar Alterações (${viewModel.pendingWritesCount} pendentes)",
                              onPressed: () {
                                StoreProvider.of<AppState>(context,
                                        listen: false)
                                    .dispatch(
                                        ProcessPendingFirestoreWritesAction());
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Tentando sincronizar... Verifique o console.")),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    if (canShowHebrewToggle && !_isFocusModeActive)
                      IconButton(
                        icon: Icon(
                          _showHebrewInterlinear
                              ? Icons.font_download_off_outlined
                              : Icons.font_download_outlined,
                          color: _showHebrewInterlinear
                              ? theme.colorScheme.secondary
                              : theme.appBarTheme.actionsIconTheme?.color,
                        ),
                        tooltip: _showHebrewInterlinear
                            ? "Ocultar Hebraico Interlinear"
                            : "Mostrar Hebraico Interlinear",
                        onPressed: () {
                          setState(() {
                            _showHebrewInterlinear = !_showHebrewInterlinear;
                            _loadCurrentChapterHebrewDataIfNeeded(); // Carrega ou limpa dados
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(
                          _isFocusModeActive
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: _isFocusModeActive
                              ? theme.colorScheme.secondary
                              : theme.appBarTheme.actionsIconTheme?.color),
                      tooltip: _isFocusModeActive
                          ? "Sair do Modo Foco"
                          : "Modo Leitura",
                      onPressed: () {
                        if (mounted) {
                          setState(
                              () => _isFocusModeActive = !_isFocusModeActive);
                        }
                      },
                    ),
                    Visibility(
                      visible: !_isFocusModeActive,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: Icon(
                              _isCompareModeActive
                                  ? Icons.compare_arrows
                                  : Icons.compare_arrows_outlined,
                              color: _isCompareModeActive
                                  ? theme.colorScheme.secondary
                                  : theme.appBarTheme.actionsIconTheme?.color),
                          tooltip: _isCompareModeActive
                              ? "Desativar Comparação"
                              : "Comparar Traduções",
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _isCompareModeActive = !_isCompareModeActive;
                                if (_isCompareModeActive &&
                                    selectedTranslation1 ==
                                        selectedTranslation2) {
                                  selectedTranslation2 =
                                      (selectedTranslation1 == 'nvi')
                                          ? 'acf'
                                          : 'nvi';
                                }
                                // Se desativar comparação e estava mostrando interlinear, pode querer manter ou resetar _showHebrewInterlinear
                                if (!_isCompareModeActive &&
                                    _showHebrewInterlinear &&
                                    selectedTranslation1 == 'hebrew_original') {
                                  _showHebrewInterlinear =
                                      false; // Exemplo: desativa se a principal virou hebraico
                                }
                                _updateFutureBuilderKey();
                              });
                            }
                          },
                        ),
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
                            if (mounted)
                              setState(() => _isSemanticSearchActive = true);
                          },
                        ),
                      ]),
                    ),
                  ],
          ),
          body: PageStorage(
            bucket: _pageStorageBucket,
            child: Column(
              children: [
                Visibility(
                    visible: !_isFocusModeActive && !_isSemanticSearchActive,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 12.0),
                        child: Column(children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                    icon: const Icon(Icons.translate, size: 18),
                                    label: Text(
                                        selectedTranslation1.toUpperCase(),
                                        style: const TextStyle(fontSize: 12)),
                                    onPressed: () => BiblePageWidgets
                                            .showTranslationSelection(
                                          context: context,
                                          selectedTranslation:
                                              selectedTranslation1,
                                          onTranslationSelected: (value) {
                                            if (mounted &&
                                                value != selectedTranslation2) {
                                              setState(() {
                                                selectedTranslation1 = value;
                                                _updateFutureBuilderKey();
                                              });
                                            }
                                          },
                                          currentSelectedBookAbbrev:
                                              selectedBook,
                                          booksMap: booksMap,
                                        ),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.cardColor,
                                        foregroundColor:
                                            theme.textTheme.bodyLarge?.color,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        elevation: 2)),
                                if (_isCompareModeActive)
                                  ElevatedButton.icon(
                                      icon:
                                          const Icon(Icons.translate, size: 18),
                                      label: Text(
                                          selectedTranslation2?.toUpperCase() ??
                                              '...',
                                          style: const TextStyle(fontSize: 12)),
                                      onPressed: () => BiblePageWidgets
                                              .showTranslationSelection(
                                            context: context,
                                            selectedTranslation:
                                                selectedTranslation2 ?? 'aa',
                                            onTranslationSelected: (value) {
                                              if (mounted &&
                                                  value !=
                                                      selectedTranslation1) {
                                                setState(() {
                                                  selectedTranslation2 = value;
                                                  _updateFutureBuilderKey();
                                                });
                                              }
                                            },
                                            currentSelectedBookAbbrev:
                                                selectedBook,
                                            booksMap: booksMap,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.cardColor,
                                          foregroundColor:
                                              theme.textTheme.bodyLarge?.color,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          elevation: 2)),
                                ElevatedButton.icon(
                                    icon: const Icon(Icons.school_outlined,
                                        size: 18),
                                    label: const Text("Estudos",
                                        style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      if (mounted) {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const StudyHubPage()));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.cardColor,
                                        foregroundColor:
                                            theme.textTheme.bodyLarge?.color,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        elevation: 2)),
                              ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            IconButton(
                                icon: Icon(Icons.chevron_left,
                                    color: theme.iconTheme.color, size: 32),
                                onPressed: _previousChapter,
                                tooltip: "Capítulo Anterior",
                                splashRadius: 24),
                            Expanded(
                                flex: 3,
                                child: UtilsBiblePage.buildBookDropdown(
                                    selectedBook: selectedBook,
                                    booksMap: booksMap,
                                    onChanged: (value) {
                                      if (mounted && value != null)
                                        _navigateToChapter(value, 1);
                                    })),
                            const SizedBox(width: 8),
                            if (selectedBook != null)
                              Expanded(
                                  flex: 2,
                                  child: UtilsBiblePage.buildChapterDropdown(
                                      selectedChapter: selectedChapter,
                                      booksMap: booksMap,
                                      selectedBook: selectedBook,
                                      onChanged: (value) {
                                        if (mounted &&
                                            value != null &&
                                            selectedBook != null) {
                                          _navigateToChapter(
                                              selectedBook!, value);
                                        }
                                      })),
                            IconButton(
                                icon: Icon(Icons.chevron_right,
                                    color: theme.iconTheme.color, size: 32),
                                onPressed: _nextChapter,
                                tooltip: "Próximo Capítulo",
                                splashRadius: 24),
                          ]),
                        ]))),
                if (selectedBook != null &&
                    selectedChapter != null &&
                    _selectedBookSlug != null &&
                    !_isSemanticSearchActive)
                  Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                    key: _futureBuilderKey,
                    future: BiblePageHelper.loadChapterDataComparison(
                        selectedBook!,
                        selectedChapter!,
                        selectedTranslation1, // Sempre carrega a tradução principal
                        _isCompareModeActive ? selectedTranslation2 : null),
                    builder: (context, snapshot) {
                      return DelayedLoading(
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                        delay: const Duration(milliseconds: 200),
                        loadingIndicator: Center(
                            child: CircularProgressIndicator(
                                color: theme.colorScheme.primary)),
                        child: () {
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data == null) {
                            return Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                        'Erro: ${snapshot.error ?? 'Dados não encontrados'}',
                                        style: TextStyle(
                                            color: theme.colorScheme.error),
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

                          if ((isCurrentTranslation1PrimaryHebrew &&
                                  (primaryTranslationVerseData == null ||
                                      (primaryTranslationVerseData as List)
                                          .isEmpty)) ||
                              (!isCurrentTranslation1PrimaryHebrew &&
                                  (primaryTranslationVerseData == null ||
                                      (primaryTranslationVerseData
                                              as List<String>)
                                          .isEmpty))) {
                            return Center(
                                child: Text(
                                    'Capítulo não encontrado para $selectedTranslation1.',
                                    style: TextStyle(
                                        color: theme
                                            .textTheme.bodyMedium?.color)));
                          }

                          if (!_isCompareModeActive) {
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

                            return _buildSingleViewContent(
                              theme,
                              sections,
                              primaryTranslationVerseData,
                              isCurrentTranslation1PrimaryHebrew,
                              hebrewDataForInterlinearView,
                            );
                          } else {
                            // Modo de Comparação
                            if (comparisonTranslationVerseData == null ||
                                (comparisonTranslationVerseData as List)
                                        .isEmpty &&
                                    selectedTranslation2 != null) {
                              return Center(
                                  child: Text(
                                      'Tradução "$selectedTranslation2" não encontrada.',
                                      style: TextStyle(
                                          color: theme.colorScheme.error)));
                            }
                            final list1Data =
                                primaryTranslationVerseData as List;
                            final list2Data =
                                comparisonTranslationVerseData as List?;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _buildComparisonColumn(
                                  context, sections, list1Data,
                                  _scrollController1,
                                  selectedTranslation1,
                                  isHebrew:
                                      isCurrentTranslation1PrimaryHebrew, // Se a COLUNA 1 é hebraico puro
                                  // Não passaremos interlinear para o modo de comparação por simplicidade agora
                                  listViewKey: PageStorageKey<String>(
                                      '$selectedBook-$selectedChapter-$selectedTranslation1-compareView'),
                                )),
                                VerticalDivider(
                                    width: 1,
                                    color: theme.dividerColor.withOpacity(0.5),
                                    thickness: 0.5),
                                Expanded(
                                    child: _buildComparisonColumn(
                                  context, sections, list2Data ?? [],
                                  _scrollController2,
                                  selectedTranslation2!,
                                  isHebrew: selectedTranslation2 ==
                                      'hebrew_original', // Se a COLUNA 2 é hebraico puro
                                  listViewKey: PageStorageKey<String>(
                                      '$selectedBook-$selectedChapter-$selectedTranslation2-compareView'),
                                )),
                              ],
                            );
                          }
                        },
                      );
                    },
                  )),
                if (_isSemanticSearchActive)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Digite sua busca semântica na barra superior.",
                          style: TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleViewContent(
    ThemeData theme,
    List<Map<String, dynamic>> sections,
    dynamic
        primaryTranslationVerseData, // Dados da tradução principal (NVI, etc., ou hebraico se for a principal)
    bool
        isPrimaryTranslationHebrew, // True se primaryTranslationVerseData for hebraico
    dynamic
        hebrewInterlinearChapterData, // Dados hebraicos para todo o capítulo (List<List<Map<String,String>>>)
  ) {
    return StoreConnector<AppState, _BibleContentViewModel>(
      converter: (store) =>
          _BibleContentViewModel.fromStore(store, selectedBook),
      builder: (context, contentViewModel) {
        final listViewKey = PageStorageKey<String>(
            '$selectedBook-$selectedChapter-$selectedTranslation1-singleView-content');

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
                  ? 1 // Para renderizar todos os versos como uma única "seção" se não houver estrutura de seção
                  : 0),
          itemBuilder: (context, sectionIndex) {
            if (sections.isNotEmpty) {
              final section = sections[sectionIndex];
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

              List<List<Map<String, String>>>? hebrewDataForThisSection;
              if (_showHebrewInterlinear &&
                  hebrewInterlinearChapterData != null &&
                  hebrewInterlinearChapterData is List) {
                hebrewDataForThisSection = [];
                for (int verseNumInOriginalChapter
                    in (section['verses'] as List?)?.cast<int>() ?? []) {
                  // verseNumInOriginalChapter é 1-based
                  if (verseNumInOriginalChapter > 0 &&
                      verseNumInOriginalChapter <=
                          hebrewInterlinearChapterData.length) {
                    hebrewDataForThisSection.add(List<Map<String, String>>.from(
                        hebrewInterlinearChapterData[
                            verseNumInOriginalChapter - 1]));
                  } else {
                    hebrewDataForThisSection
                        .add([]); // Verso não encontrado nos dados hebraicos
                  }
                }
              }

              return SectionItemWidget(
                key: ValueKey(
                    '${_selectedBookSlug}_${selectedChapter}_${section['title']}_${versesRange}_${selectedTranslation1}_$isSectionRead' +
                        (_showHebrewInterlinear ? '_hebInt' : '')),
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
                isRead: isSectionRead,
                showHebrewInterlinear: _showHebrewInterlinear &&
                    !isPrimaryTranslationHebrew, // Só mostra se a principal NÃO for hebraico
                hebrewInterlinearSectionData: hebrewDataForThisSection,
              );
            } else if (primaryTranslationVerseData != null &&
                (primaryTranslationVerseData as List).isNotEmpty) {
              // Caso especial: sem seções, renderiza todos os versos do capítulo
              final List listData = primaryTranslationVerseData;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      List.generate(listData.length, (verseIndexInChapter) {
                    // 0-based
                    final verseNumber = verseIndexInChapter + 1; // 1-based
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

                    return BiblePageWidgets.buildVerseItem(
                      key: ValueKey<String>(
                          '${selectedBook}_${selectedChapter}_${verseNumber}_$selectedTranslation1' +
                              (_showHebrewInterlinear ? '_hebInt' : '')),
                      verseNumber: verseNumber,
                      verseData: listData[verseIndexInChapter],
                      selectedBook: selectedBook,
                      selectedChapter: selectedChapter,
                      context: context,
                      userHighlights: contentViewModel.userHighlights,
                      userNotes: contentViewModel.userNotes,
                      isHebrew: isPrimaryTranslationHebrew,
                      showHebrewInterlinear:
                          _showHebrewInterlinear && !isPrimaryTranslationHebrew,
                      hebrewVerseData: hebrewVerseForInterlinear,
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
      List verseColumnData, // Dados da tradução desta coluna
      ScrollController scrollController,
      String currentTranslation, // ID da tradução desta coluna
      {bool isHebrew = false, // True se esta coluna for 'hebrew_original'
      required PageStorageKey listViewKey}) {
    final theme = Theme.of(context);
    if (verseColumnData.isEmpty &&
        sections.isEmpty &&
        currentTranslation.isNotEmpty) {
      return Center(/* ... */);
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
                        'compare_section_${sectionTitle}_${currentTranslation}_$sectionKeyIdentifier' +
                            (isSectionRead ? '_read' : '_unread')),
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
                                        fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: Icon(
                                  isSectionRead
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color: isSectionRead
                                      ? theme.primaryColor
                                      : theme.iconTheme.color?.withOpacity(0.7),
                                  size: 20,
                                ),
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
                                      markAsRead: !isSectionRead,
                                    ),
                                  );
                                },
                              ),
                            ],
                          )),
                      ...verseNumbers.map((verseNumber) {
                        final verseIndex = verseNumber - 1; // 0-based
                        dynamic verseDataItemForColumn;
                        if (verseIndex >= 0 &&
                            verseIndex < verseColumnData.length) {
                          verseDataItemForColumn = verseColumnData[verseIndex];
                        } else {
                          verseDataItemForColumn =
                              isHebrew ? [] : "[Texto Indisponível]";
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
                          isHebrew:
                              isHebrew, // True se ESTA COLUNA for hebraico
                          // showHebrewInterlinear e hebrewVerseData não são usados aqui para manter simples
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
                      );
                    }));
              }
              return const SizedBox.shrink();
            },
          );
        });
  }
}

// Widget de DelayedLoading (permanece o mesmo)
class DelayedLoading extends StatefulWidget {
  final bool loading;
  final Widget Function() child;
  final Duration delay;
  final Widget loadingIndicator;

  const DelayedLoading({
    super.key,
    required this.loading,
    required this.child,
    this.delay = const Duration(milliseconds: 300),
    required this.loadingIndicator,
  });

  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  bool _showLoadingIndicator = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(DelayedLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _showLoadingIndicator = false;
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _cancelTimer();
      if (mounted) {
        setState(() => _showLoadingIndicator = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted && widget.loading) {
        setState(() => _showLoadingIndicator = true);
      }
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
    if (_showLoadingIndicator && widget.loading) {
      return widget.loadingIndicator;
    }
    return widget.child();
  }
}
