// lib/pages/bible_page.dart
import 'dart:convert';
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
import 'package:flutter/foundation.dart'; // for mapEquals
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';

// ViewModel para o StoreConnector da BiblePage
class _BiblePageViewModel {
  final String? initialBook;
  final int? initialChapter;
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final String? lastReadBookAbbrev;
  final int? lastReadChapter;
  final String? userId;

  _BiblePageViewModel({
    this.initialBook,
    this.initialChapter,
    required this.userHighlights,
    required this.userNotes,
    this.lastReadBookAbbrev,
    this.lastReadChapter,
    this.userId,
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    return _BiblePageViewModel(
      initialBook: store.state.userState.initialBibleBook,
      initialChapter: store.state.userState.initialBibleChapter,
      userHighlights: store.state.userState.userHighlights,
      userNotes: store.state.userState.userNotes,
      lastReadBookAbbrev: store.state.userState.lastReadBookAbbrev,
      lastReadChapter: store.state.userState.lastReadChapter,
      userId: store.state.userState.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BiblePageViewModel &&
          runtimeType == other.runtimeType &&
          initialBook == other.initialBook &&
          initialChapter == other.initialChapter &&
          mapEquals(userHighlights, other.userHighlights) &&
          mapEquals(userNotes, other.userNotes) &&
          lastReadBookAbbrev == other.lastReadBookAbbrev &&
          lastReadChapter == other.lastReadChapter &&
          userId == other.userId;

  @override
  int get hashCode =>
      initialBook.hashCode ^
      initialChapter.hashCode ^
      userHighlights.hashCode ^
      userNotes.hashCode ^
      lastReadBookAbbrev.hashCode ^
      lastReadChapter.hashCode ^
      userId.hashCode;
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

  String? _lastRecordedHistoryRef;
  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {}; // Para o "Ir Para"

  ValueKey _futureBuilderKey = const ValueKey(
      'initial_bible_key_state_v6'); // Incrementar se a lógica do FutureBuilder mudar
  bool _hasProcessedInitialNavigation = false;

  bool _isSemanticSearchActive = false;
  final TextEditingController _semanticQueryController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    print(">>> BiblePage initState: Iniciando...");
    _loadInitialData(); // booksMap e _bookVariationsMap (para "Ir Para")
  }

  @override
  void dispose() {
    _semanticQueryController.dispose();
    super.dispose();
  }

  // Helper para normalizar texto (minúsculas e remover acentos)
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
    // Carrega o mapa de livros para os dropdowns de navegação
    final generalBooksMap = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        booksMap = generalBooksMap;
      });
    }
    // Carrega o mapa de variações para a funcionalidade "Ir Para"
    await _loadBookVariationsMapForGoTo(); // Renomeado para clareza
    // Pré-carrega o léxico (opcional, mas pode melhorar a performance se usado frequentemente)
    await BiblePageHelper.getStrongsLexicon();
  }

  Future<void> _loadBookVariationsMapForGoTo() async {
    // Renomeado para clareza
    try {
      // USA O NOVO ARQUIVO JSON PARA O "IR PARA"
      final String jsonString = await rootBundle
          .loadString('assets/Biblia/book_variations_map_search.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);

      final Map<String, String> normalizedMap = {};
      decodedJson.forEach((key, value) {
        // Normaliza a CHAVE (variação digitada pelo usuário)
        // O VALOR já é a abreviação canônica (ex: "gn", "job")
        normalizedMap[_normalizeSearchText(key)] = value.toString();
      });

      if (mounted) {
        setState(() {
          _bookVariationsMap = normalizedMap;
          print(
              ">>> _bookVariationsMap (para Ir Para) carregado e normalizado: ${_bookVariationsMap.length} entradas.");
        });
      }
    } catch (e) {
      print(
          "Erro ao carregar e normalizar book_variations_map_search.json: $e");
      if (mounted) setState(() => _bookVariationsMap = {});
    }
  }

  void _updateFutureBuilderKey() {
    if (mounted) {
      setState(() {
        _futureBuilderKey = ValueKey(
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-${_selectedBookSlug ?? 'no_slug'}-${DateTime.now().millisecondsSinceEpoch}');
      });
    }
  }

  void _applyNavigationState(String book, int chapter,
      {bool forceKeyUpdate = false}) {
    if (!mounted) return;
    bool changed = selectedBook != book || selectedChapter != chapter;
    if (changed) {
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
        _updateSelectedBookSlug();
      });
    }
    if (changed || forceKeyUpdate) {
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

    if (vm.initialBook != null && vm.initialChapter != null) {
      targetBook = vm.initialBook!;
      targetChapter = vm.initialChapter!;
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
      if (store.state.userState.userHighlights.isEmpty)
        store.dispatch(LoadUserHighlightsAction());
      if (store.state.userState.userNotes.isEmpty)
        store.dispatch(LoadUserNotesAction());
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
    final TextEditingController controller = TextEditingController();
    String? errorTextInDialog;
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(builder: (sfbContext, setDialogState) {
            // Renomeado context para sfbContext
            final theme =
                Theme.of(sfbContext); // Usa o contexto do StatefulBuilder
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
                    errorText: errorTextInDialog,
                  ),
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
    // Renomeado para clareza, esta função usa _normalizeSearchText
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
      // A chave do mapa já está normalizada pelo _loadBookVariationsMapForGoTo
      if (normalizedUserInput.startsWith(normalizedVariationKeyInMap)) {
        foundBookAbbrev = _bookVariationsMap[normalizedVariationKeyInMap];
        remainingInputForChapterAndVerse = normalizedUserInput
            .substring(normalizedVariationKeyInMap.length)
            .trim();

        // Lógica específica para Jó vs João (se "jo" normalizado for ambíguo)
        // Este é um exemplo, você pode precisar refinar com base no seu `book_variations_map_search.json`
        if (normalizedVariationKeyInMap == "jo") {
          // Se a *variação normalizada* que deu match foi "jo"
          if (userInput.toLowerCase().startsWith("jó") ||
              userInput.toLowerCase().startsWith("job")) {
            // Se o input original sugere Jó, e existe "job" como valor canônico no mapa de variações
            if (_bookVariationsMap.containsValue("job")) {
              // Tenta ver se alguma variação de Jó também deu match com "jo"
              // Ou, mais simples: se o usuário digitou algo que começa com jó/job, e "jo" deu match,
              // mas "job" também é um valor canônico, pode ser Jó.
              // Esta lógica pode ser complexa. A melhor forma é garantir que
              // "jó", "job" etc. no JSON mapeiem para "job" (a abreviação canônica).
              // Se "jo" (de Jó) e "jo" (de João) ambos normalizam para "jo",
              // a ordenação por tamanho de chave (se "joao" for mais longo que "jó") ajuda.
              // Para este caso, vamos assumir que se o input original era "jó" ou "job", é Jó.
              // AVISO: Esta é uma simplificação. O ideal é o `book_variations_map_search.json` ser muito claro.
              bool isPotentiallyJob = _bookVariationsMap.entries.any((e) =>
                  (e.key == "jó" ||
                      e.key == "job" ||
                      e.key == "jo com acento circunflexo" ||
                      e.key == "jô") &&
                  e.value == "job");
              if (isPotentiallyJob && foundBookAbbrev == "jo") {
                // Se "jo" (de João) foi pego, mas era Jó
                foundBookAbbrev = "job"; // Corrige para Jó
              }
            }
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

  // _finalizeNavigation não precisa de alterações, já usa a abreviação canônica
  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
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
              if (mounted && !_hasProcessedInitialNavigation)
                _processIntentOrInitialLoad(context, newViewModel);
            });
          } else if (newViewModel.initialBook !=
                  previousViewModel?.initialBook ||
              newViewModel.initialChapter !=
                  previousViewModel?.initialChapter) {
            if (newViewModel.initialBook != null &&
                newViewModel.initialChapter != null)
              _processIntentOrInitialLoad(context, newViewModel);
          }
          if (previousViewModel != null &&
              (!mapEquals(previousViewModel.userHighlights,
                      newViewModel.userHighlights) ||
                  !mapEquals(
                      previousViewModel.userNotes, newViewModel.userNotes))) {
            _updateFutureBuilderKey();
          }
        }
      },
      builder: (context, viewModel) {
        if (booksMap == null || _bookVariationsMap.isEmpty) {
          // Adicionado _bookVariationsMap.isEmpty
          return Scaffold(
            appBar: AppBar(title: const Text('Bíblia')),
            body: Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.primary)),
          );
        }
        if (selectedBook == null || selectedChapter == null) {
          if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation)
                _processIntentOrInitialLoad(context, viewModel);
            });
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Bíblia')),
            body: Center(
                child: Text("Carregando Bíblia...",
                    style:
                        TextStyle(color: theme.textTheme.bodyMedium?.color))),
          );
        }

        String appBarTitle = _isSemanticSearchActive ? '' : 'Bíblia';
        if (!_isSemanticSearchActive) {
          if (_isFocusModeActive) {
            appBarTitle = booksMap?[selectedBook]?['nome'] ?? 'Bíblia';
            if (selectedChapter != null) appBarTitle += ' $selectedChapter';
          } else if (_isCompareModeActive) {
            appBarTitle = 'Comparar Traduções';
          }
        }

        bool isCurrentTranslation1Hebrew =
            selectedTranslation1 == 'hebrew_original';
        bool isCurrentTranslation2Hebrew =
            selectedTranslation2 == 'hebrew_original';

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
                ? [
                    IconButton(
                      icon: Icon(Icons.search,
                          color: theme.appBarTheme.actionsIconTheme?.color),
                      onPressed: () {
                        if (_semanticQueryController.text.isNotEmpty &&
                            mounted) {
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(SearchBibleSemanticAction(
                                  _semanticQueryController.text));
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BibleSearchResultsPage(
                                      initialQuery:
                                          _semanticQueryController.text)));
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: theme.appBarTheme.actionsIconTheme?.color),
                      onPressed: () {
                        if (mounted)
                          setState(() {
                            _isSemanticSearchActive = false;
                            _semanticQueryController.clear();
                          });
                      },
                    )
                  ]
                : [
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
                        if (mounted)
                          setState(
                              () => _isFocusModeActive = !_isFocusModeActive);
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
          body: Column(
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
                                label: Text(selectedTranslation1.toUpperCase(),
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () =>
                                    BiblePageWidgets.showTranslationSelection(
                                        context: context,
                                        selectedTranslation:
                                            selectedTranslation1,
                                        onTranslationSelected: (value) {
                                          if (mounted &&
                                              value != selectedTranslation2)
                                            setState(() {
                                              selectedTranslation1 = value;
                                              _updateFutureBuilderKey();
                                            });
                                        }),
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
                                  icon: const Icon(Icons.translate, size: 18),
                                  label: Text(
                                      selectedTranslation2?.toUpperCase() ??
                                          '...',
                                      style: const TextStyle(fontSize: 12)),
                                  onPressed: () =>
                                      BiblePageWidgets.showTranslationSelection(
                                          context: context,
                                          selectedTranslation:
                                              selectedTranslation2 ?? 'aa',
                                          onTranslationSelected: (value) {
                                            if (mounted &&
                                                value != selectedTranslation1)
                                              setState(() {
                                                selectedTranslation2 = value;
                                                _updateFutureBuilderKey();
                                              });
                                          }),
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
                                icon:
                                    const Icon(Icons.school_outlined, size: 18),
                                label: const Text("Estudos",
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  if (mounted)
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const StudyHubPage()));
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
                                        selectedBook != null)
                                      _navigateToChapter(selectedBook!, value);
                                  })),
                        IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: theme.iconTheme.color, size: 32),
                            onPressed: _nextChapter,
                            tooltip: "Próximo Capítulo",
                            splashRadius: 24),
                      ]),
                    ])),
              ),
              // Conteúdo principal (versículos/seções)
              if (selectedBook != null &&
                  selectedChapter != null &&
                  _selectedBookSlug != null &&
                  !_isSemanticSearchActive) // Adicionado !_isSemanticSearchActive
                Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                  key: _futureBuilderKey,
                  future: BiblePageHelper.loadChapterDataComparison(
                      selectedBook!,
                      selectedChapter!,
                      selectedTranslation1,
                      _isCompareModeActive ? selectedTranslation2 : null),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Center(
                          child: CircularProgressIndicator(
                              color: theme.colorScheme.primary));
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data == null)
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                  'Erro: ${snapshot.error ?? 'Dados não encontrados'}',
                                  style:
                                      TextStyle(color: theme.colorScheme.error),
                                  textAlign: TextAlign.center)));

                    final chapterData = snapshot.data!;
                    final List<Map<String, dynamic>> sections =
                        chapterData['sectionStructure'] ?? [];
                    final Map<String, dynamic> verseDataMap =
                        chapterData['verseData'] ?? {};
                    final dynamic verses1Data =
                        verseDataMap[selectedTranslation1];
                    final dynamic verses2Data =
                        (_isCompareModeActive && selectedTranslation2 != null)
                            ? verseDataMap[selectedTranslation2!]
                            : null;

                    if ((isCurrentTranslation1Hebrew &&
                            (verses1Data == null ||
                                (verses1Data as List).isEmpty)) ||
                        (!isCurrentTranslation1Hebrew &&
                            (verses1Data == null ||
                                (verses1Data as List<String>).isEmpty))) {
                      return Center(
                          child: Text(
                              'Capítulo não encontrado para $selectedTranslation1.',
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color)));
                    }

                    if (!_isCompareModeActive) {
                      return ListView.builder(
                        padding: EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            bottom: 16.0,
                            top: _isFocusModeActive ? 8.0 : 0.0),
                        itemCount: sections.isNotEmpty
                            ? sections.length
                            : (verses1Data != null &&
                                    (verses1Data as List).isNotEmpty
                                ? 1
                                : 0),
                        itemBuilder: (context, sectionIndex) {
                          if (sections.isNotEmpty) {
                            final section = sections[sectionIndex];
                            return SectionItemWidget(
                              sectionTitle: section['title'] ?? 'Seção',
                              verseNumbersInSection:
                                  (section['verses'] as List?)?.cast<int>() ??
                                      [],
                              allVerseDataInChapter: verses1Data,
                              bookSlug: _selectedBookSlug!,
                              bookAbbrev: selectedBook!,
                              chapterNumber: selectedChapter!,
                              versesRangeStr: (section['verses'] as List?)
                                          ?.cast<int>()
                                          .isNotEmpty ??
                                      false
                                  ? ((section['verses'] as List)
                                              .cast<int>()
                                              .length ==
                                          1
                                      ? (section['verses'] as List)
                                          .cast<int>()
                                          .first
                                          .toString()
                                      : "${(section['verses'] as List).cast<int>().first}-${(section['verses'] as List).cast<int>().last}")
                                  : "",
                              userHighlights: viewModel.userHighlights,
                              userNotes: viewModel.userNotes,
                              isHebrew: isCurrentTranslation1Hebrew,
                            );
                          } else if (verses1Data != null &&
                              (verses1Data as List).isNotEmpty) {
                            final List listData = verses1Data;
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(listData.length,
                                    (verseIndex) {
                                  return BiblePageWidgets.buildVerseItem(
                                    verseNumber: verseIndex + 1,
                                    verseData: listData[verseIndex],
                                    selectedBook: selectedBook,
                                    selectedChapter: selectedChapter,
                                    context: context,
                                    userHighlights: viewModel.userHighlights,
                                    userNotes: viewModel.userNotes,
                                    isHebrew: isCurrentTranslation1Hebrew,
                                  );
                                }));
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    } else {
                      // Modo Comparação
                      if (verses2Data == null ||
                          (verses2Data as List).isEmpty &&
                              selectedTranslation2 != null)
                        return Center(
                            child: Text(
                                'Tradução "$selectedTranslation2" não encontrada.',
                                style:
                                    TextStyle(color: theme.colorScheme.error)));
                      final list1Data = verses1Data as List;
                      final list2Data = verses2Data as List?;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _buildComparisonColumn(
                                  context,
                                  sections,
                                  list1Data,
                                  list1Data.length > (list2Data?.length ?? 0)
                                      ? list1Data.length
                                      : (list2Data?.length ?? 0),
                                  viewModel.userHighlights,
                                  viewModel.userNotes,
                                  selectedTranslation1,
                                  isHebrew: isCurrentTranslation1Hebrew)),
                          VerticalDivider(
                              width: 1,
                              color: theme.dividerColor.withOpacity(0.5),
                              thickness: 0.5),
                          Expanded(
                              child: _buildComparisonColumn(
                                  context,
                                  sections,
                                  list2Data ?? [],
                                  list1Data.length > (list2Data?.length ?? 0)
                                      ? list1Data.length
                                      : (list2Data?.length ?? 0),
                                  viewModel.userHighlights,
                                  viewModel.userNotes,
                                  selectedTranslation2!,
                                  isHebrew: isCurrentTranslation2Hebrew)),
                        ],
                      );
                    }
                  },
                )),
              // Adicionado um placeholder se a busca semântica estiver ativa e o conteúdo principal oculto
              if (_isSemanticSearchActive)
                Expanded(
                  child: Center(
                    child: Text(
                      "Digite sua busca semântica na barra superior.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List verseColumnData,
      int maxVerseCount,
      Map<String, String> userHighlights,
      Map<String, String> userNotes,
      String currentTranslation,
      {bool isHebrew = false}) {
    final theme = Theme.of(context);
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
    return ListView.builder(
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
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(sectionTitle,
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                ...verseNumbers.map((verseNumber) {
                  final verseIndex = verseNumber - 1;
                  final dynamic verseDataItem =
                      (verseIndex >= 0 && verseIndex < verseColumnData.length)
                          ? verseColumnData[verseIndex]
                          : (isHebrew ? [] : "[Texto Indisponível]");
                  return BiblePageWidgets.buildVerseItem(
                    verseNumber: verseNumber,
                    verseData: verseDataItem,
                    selectedBook: selectedBook,
                    selectedChapter: selectedChapter,
                    context: context,
                    userHighlights: userHighlights,
                    userNotes: userNotes,
                    isHebrew: isHebrew,
                  );
                }),
              ]);
        } else if (verseColumnData.isNotEmpty) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(verseColumnData.length, (verseIndex) {
                final verseNumber = verseIndex + 1;
                final dynamic verseDataItem = verseColumnData[verseIndex];
                return BiblePageWidgets.buildVerseItem(
                  verseNumber: verseNumber,
                  verseData: verseDataItem,
                  selectedBook: selectedBook,
                  selectedChapter: selectedChapter,
                  context: context,
                  userHighlights: userHighlights,
                  userNotes: userNotes,
                  isHebrew: isHebrew,
                );
              }));
        }
        return const SizedBox.shrink();
      },
    );
  }
}
