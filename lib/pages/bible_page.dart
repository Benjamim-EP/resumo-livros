// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/study_hub_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart'; // for mapEquals

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
  Map<String, String> _bookVariationsMap = {};

  ValueKey _futureBuilderKey =
      const ValueKey('initial_bible_key_state_v4'); // Atualizado
  bool _hasProcessedInitialNavigation = false;

  @override
  void initState() {
    super.initState();
    print(">>> BiblePage initState: Iniciando...");
    _loadInitialData();
    // _loadUserDataIfNeeded e _processIntentOrInitialLoad agora são chamados pelo StoreConnector
  }

  void _updateFutureBuilderKey() {
    if (mounted) {
      setState(() {
        _futureBuilderKey = ValueKey(
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-${_selectedBookSlug ?? 'no_slug'}-${DateTime.now().millisecondsSinceEpoch}');
        print(
            ">>> BiblePage: _futureBuilderKey ATUALIZADA para: $_futureBuilderKey");
      });
    }
  }

  void _applyNavigationState(String book, int chapter,
      {bool forceKeyUpdate = false}) {
    if (!mounted) return;
    print(
        ">>> BiblePage _applyNavigationState: Aplicando $book $chapter. Atual: $selectedBook $selectedChapter. Forçar Key: $forceKeyUpdate");

    bool changed = selectedBook != book || selectedChapter != chapter;

    if (changed) {
      setState(() {
        selectedBook = book;
        selectedChapter = chapter;
        _updateSelectedBookSlug(); // Atualiza o slug se o livro mudou
      });
    }
    // Atualiza a chave do FutureBuilder e grava o histórico se houve mudança ou se forçado
    if (changed || forceKeyUpdate) {
      _updateFutureBuilderKey();
      _recordHistory(book, chapter);
    }
    print(
        ">>> BiblePage _applyNavigationState: Estado após setState: selectedBook: $selectedBook, selectedChapter: $selectedChapter, slug: $_selectedBookSlug");
  }

  void _processIntentOrInitialLoad(
      BuildContext context, _BiblePageViewModel vm) {
    if (!mounted || booksMap == null) {
      print(
          ">>> BiblePage _processIntentOrInitialLoad: Abortado (não montado ou booksMap nulo). Montado: $mounted, BooksMap: ${booksMap != null}");
      return;
    }

    final store = StoreProvider.of<AppState>(context, listen: false);
    String targetBook;
    int targetChapter;
    bool isFromIntent = false;

    if (vm.initialBook != null && vm.initialChapter != null) {
      print(
          ">>> BiblePage _processIntentOrInitialLoad: Usando intent do Redux: ${vm.initialBook} ${vm.initialChapter}");
      targetBook = vm.initialBook!;
      targetChapter = vm.initialChapter!;
      isFromIntent = true;
      // Limpa o intent no Redux APÓS usá-lo para evitar loop se a página for reconstruída rapidamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Verifica se ainda está montado antes de despachar
          store.dispatch(SetInitialBibleLocationAction(null, null));
          print(
              ">>> BiblePage _processIntentOrInitialLoad: Intent do Redux limpo (post-frame).");
        }
      });
    } else {
      targetBook = vm.lastReadBookAbbrev ?? selectedBook ?? 'gn';
      targetChapter = vm.lastReadChapter ?? selectedChapter ?? 1;
      print(
          ">>> BiblePage _processIntentOrInitialLoad: Sem intent. Usando lastRead/selecionado/padrão: $targetBook $targetChapter");
    }

    // Validação
    if (booksMap!.containsKey(targetBook)) {
      final bookData = booksMap![targetBook];
      if (targetChapter < 1 || targetChapter > (bookData['capitulos'] as int)) {
        print(
            ">>> BiblePage _processIntentOrInitialLoad: Capítulo alvo ($targetChapter) inválido para $targetBook. Revertendo para $targetBook 1 (ou gn 1 se livro também inválido).");
        targetChapter = 1; // Reverte para capítulo 1 do livro alvo
        if (!booksMap!.containsKey(targetBook)) {
          // Se o livro alvo também era inválido
          targetBook = 'gn';
        }
      }
    } else {
      print(
          ">>> BiblePage _processIntentOrInitialLoad: Livro alvo ($targetBook) inválido. Revertendo para gn 1.");
      targetBook = 'gn';
      targetChapter = 1;
    }

    print(
        ">>> BiblePage _processIntentOrInitialLoad: Navegando para $targetBook $targetChapter. Veio de intent: $isFromIntent");
    _applyNavigationState(targetBook, targetChapter,
        forceKeyUpdate: isFromIntent ||
            selectedBook ==
                null); // Força se for intent ou se selectedBook ainda não foi definido

    if (!_hasProcessedInitialNavigation &&
        selectedBook != null &&
        selectedChapter != null) {
      _hasProcessedInitialNavigation = true;
      _loadUserDataIfNeeded(context);
      print(
          ">>> BiblePage _processIntentOrInitialLoad: _hasProcessedInitialNavigation definido como true.");
    }
  }

  void _loadUserDataIfNeeded(BuildContext context) {
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (store.state.userState.userId != null) {
      if (store.state.userState.userHighlights.isEmpty) {
        store.dispatch(LoadUserHighlightsAction());
      }
      if (store.state.userState.userNotes.isEmpty) {
        store.dispatch(LoadUserNotesAction());
      }
    }
  }

  Future<void> _loadInitialData() async {
    await _loadBookVariationsMap();
    final map = await BiblePageHelper.loadBooksMap();
    await BiblePageHelper.getStrongsLexicon(); // Pré-carrega o léxico
    if (mounted) {
      setState(() {
        booksMap = map;
      });
      // A navegação inicial será acionada pelo StoreConnector.onDidChange
      // quando o _hasProcessedInitialNavigation for false e booksMap estiver carregado.
    }
  }

  Future<void> _loadBookVariationsMap() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Biblia/book_variations_map.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      if (mounted) {
        setState(() {
          _bookVariationsMap =
              decodedJson.map((key, value) => MapEntry(key, value.toString()));
        });
      }
    } catch (e) {
      print("Erro ao carregar book_variations_map.json: $e");
      if (mounted) setState(() => _bookVariationsMap = {});
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
      // Não grava se for o mesmo do último gravado
      print(
          ">>> BiblePage _recordHistory: Gravando histórico para $currentRef. Último gravado: $_lastRecordedHistoryRef");
      if (context.mounted) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(RecordReadingHistoryAction(bookAbbrev, chapter));
      }
      _lastRecordedHistoryRef = currentRef;
    } else {
      print(
          ">>> BiblePage _recordHistory: Histórico para $currentRef já é o último gravado. Não regravando.");
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
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2F33),
              title: const Text("Ir para Referência",
                  style: TextStyle(color: Colors.white)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Ex: Gn 1 ou João 3:16",
                    hintStyle: const TextStyle(color: Colors.white54),
                    errorText: errorTextInDialog,
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.green),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) =>
                      _parseAndNavigate(value, dialogContext, (newError) {
                    if (mounted)
                      setDialogState(() => errorTextInDialog = newError);
                  }),
                ),
                const SizedBox(height: 8),
                const Text(
                    "Formatos aceitos:\n- Livro Capítulo (Ex: Gênesis 1, Jo 3)\n- Livro Capítulo:Versículo (Ex: Ex 20:3)",
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => _parseAndNavigate(
                            controller.text, dialogContext, (newError) {
                          if (mounted)
                            setDialogState(() => errorTextInDialog = newError);
                        }),
                    child: const Text("Ir",
                        style: TextStyle(color: Colors.green))),
              ],
            );
          });
        });
  }

  void _parseAndNavigate(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    if (input.trim().isEmpty) {
      updateErrorText("Digite uma referência.");
      return;
    }
    String normalizedInput =
        input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    String? foundBookAbbrev;
    String remainingInputForChapter = normalizedInput;
    List<String> sortedVariationKeys = _bookVariationsMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String variationKey in sortedVariationKeys) {
      if (normalizedInput.startsWith(variationKey)) {
        foundBookAbbrev = _bookVariationsMap[variationKey];
        remainingInputForChapter =
            normalizedInput.substring(variationKey.length).trim();
        break;
      }
    }
    if (foundBookAbbrev == null) {
      updateErrorText("Livro não reconhecido.");
      return;
    }
    final RegExp chapVerseRegex = RegExp(r'^(\d+)(?:\s*:\s*\d+.*)?$');
    final Match? cvMatch = chapVerseRegex.firstMatch(remainingInputForChapter);
    final int? chapter;
    if (cvMatch == null || cvMatch.group(1) == null) {
      final RegExp chapOnlyRegex = RegExp(r'^(\d+)$');
      final Match? chapOnlyMatch =
          chapOnlyRegex.firstMatch(remainingInputForChapter);
      if (chapOnlyMatch == null || chapOnlyMatch.group(1) == null) {
        updateErrorText("Formato de capítulo inválido.");
        return;
      }
      chapter = int.tryParse(chapOnlyMatch.group(1)!);
    } else {
      chapter = int.tryParse(cvMatch.group(1)!);
    }
    if (chapter == null) {
      updateErrorText("Número do capítulo inválido.");
      return;
    }
    _finalizeNavigation(
        foundBookAbbrev, chapter, dialogContext, updateErrorText);
  }

  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
        if (Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext).pop();
        }
        updateErrorText(null);
      } else {
        updateErrorText('Capítulo $chapter inválido para ${bookData['nome']}.');
      }
    } else {
      updateErrorText('Livro "$bookAbbrev" não encontrado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _BiblePageViewModel>(
      converter: (store) => _BiblePageViewModel.fromStore(store),
      onInit: (store) {
        // A primeira chamada para _processIntentOrInitialLoad será feita no primeiro build
        // do StoreConnector se booksMap já estiver carregado.
        // Caso contrário, será chamada no onDidChange quando booksMap carregar.
        if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
          print(
              ">>> BiblePage StoreConnector onInit: booksMap já carregado. Chamando _processIntentOrInitialLoad.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Garante que o build inicial complete
            if (mounted && !_hasProcessedInitialNavigation)
              _processIntentOrInitialLoad(
                  context, _BiblePageViewModel.fromStore(store));
          });
        }
        _loadUserDataIfNeeded(context);
      },
      onDidChange: (previousViewModel, newViewModel) {
        print(
            ">>> BiblePage StoreConnector onDidChange: ViewModel mudou. InitialBook: ${newViewModel.initialBook}, LastRead: ${newViewModel.lastReadBookAbbrev}");
        if (mounted && booksMap != null) {
          // Se é a primeira vez que onDidChange roda E a navegação inicial ainda não foi processada
          // E booksMap já está disponível
          if (!_hasProcessedInitialNavigation) {
            print(
                ">>> BiblePage onDidChange: Processando navegação inicial (primeira vez ou após booksMap carregar).");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation)
                _processIntentOrInitialLoad(context, newViewModel);
            });
          }
          // Se houve uma mudança no intent de navegação do Redux
          else if (newViewModel.initialBook != previousViewModel?.initialBook ||
              newViewModel.initialChapter !=
                  previousViewModel?.initialChapter) {
            if (newViewModel.initialBook != null &&
                newViewModel.initialChapter != null) {
              print(
                  ">>> BiblePage onDidChange: Novo intent de navegação do Redux detectado: ${newViewModel.initialBook} ${newViewModel.initialChapter}.");
              _processIntentOrInitialLoad(context, newViewModel);
            }
          }

          // Reage a mudanças em highlights/notes
          if (previousViewModel != null &&
              (!mapEquals(previousViewModel.userHighlights,
                      newViewModel.userHighlights) ||
                  !mapEquals(
                      previousViewModel.userNotes, newViewModel.userNotes))) {
            print(
                ">>> BiblePage StoreConnector onDidChange: Highlights ou Notes mudaram no ViewModel. Atualizando _futureBuilderKey.");
            _updateFutureBuilderKey();
          }
        }
      },
      builder: (context, viewModel) {
        if (booksMap == null) {
          return Scaffold(
            appBar: AppBar(
                title: const Text('Bíblia'),
                backgroundColor: const Color(0xFF181A1A)),
            body: const Center(
                child: CircularProgressIndicator(color: Color(0xFFCDE7BE))),
          );
        }

        // Se selectedBook ou selectedChapter ainda não foram definidos (esperando _processIntentOrInitialLoad)
        if (selectedBook == null || selectedChapter == null) {
          // Tenta processar a navegação inicial se ainda não o fez e o booksMap está pronto
          if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                print(
                    ">>> BiblePage builder (postFrame - selectedBook/Chapter nulo): _hasProcessedInitialNavigation ainda é false. Tentando processar.");
                _processIntentOrInitialLoad(context, viewModel);
              }
            });
          }
          print(
              ">>> BiblePage builder: selectedBook ou selectedChapter NULO. Mostrando loader de localização...");
          return Scaffold(
            appBar: AppBar(
                title: const Text('Bíblia'),
                backgroundColor: const Color(0xFF181A1A)),
            body: const Center(
                child: Text("Carregando Bíblia...",
                    style: TextStyle(color: Colors.white70))),
          );
        }

        print(
            ">>> BiblePage builder: Renderizando UI para $selectedBook $selectedChapter. Chave: $_futureBuilderKey");
        String appBarTitle = 'Bíblia';
        if (_isFocusModeActive) {
          appBarTitle = booksMap?[selectedBook]?['nome'] ?? 'Bíblia';
          if (selectedChapter != null) appBarTitle += ' $selectedChapter';
        } else if (_isCompareModeActive) {
          appBarTitle = 'Comparar Traduções';
        }

        bool isCurrentTranslation1Hebrew =
            selectedTranslation1 == 'hebrew_original';
        bool isCurrentTranslation2Hebrew =
            selectedTranslation2 == 'hebrew_original';

        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitle),
            backgroundColor: const Color(0xFF181A1A),
            leading: _isFocusModeActive ? const SizedBox.shrink() : null,
            actions: [
              IconButton(
                icon: Icon(
                    _isFocusModeActive
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    color: _isFocusModeActive
                        ? Colors.blueAccent
                        : Colors.white70),
                tooltip:
                    _isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura",
                onPressed: () {
                  if (mounted)
                    setState(() => _isFocusModeActive = !_isFocusModeActive);
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
                            ? Colors.amber
                            : Colors.white70),
                    tooltip: _isCompareModeActive
                        ? "Desativar Comparação"
                        : "Comparar Traduções",
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _isCompareModeActive = !_isCompareModeActive;
                          if (_isCompareModeActive &&
                              selectedTranslation1 == selectedTranslation2) {
                            selectedTranslation2 =
                                (selectedTranslation1 == 'nvi') ? 'acf' : 'nvi';
                          }
                          _updateFutureBuilderKey();
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.manage_search_outlined,
                        color: Colors.white70),
                    tooltip: "Ir para referência",
                    onPressed: _showGoToDialog,
                  ),
                ]),
              ),
            ],
          ),
          body: Column(
            children: [
              Visibility(
                visible: !_isFocusModeActive,
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
                                              value != selectedTranslation2) {
                                            setState(() {
                                              selectedTranslation1 = value;
                                              _updateFutureBuilderKey();
                                            });
                                          }
                                        }),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF272828),
                                    foregroundColor: Colors.white,
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
                                                value != selectedTranslation1) {
                                              setState(() {
                                                selectedTranslation2 = value;
                                                _updateFutureBuilderKey();
                                              });
                                            }
                                          }),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF272828),
                                      foregroundColor: Colors.white,
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
                                    backgroundColor: const Color(0xFF272828),
                                    foregroundColor: Colors.white,
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
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.white, size: 32),
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
                                      _navigateToChapter(selectedBook!, value);
                                    }
                                  })),
                        IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.white, size: 32),
                            onPressed: _nextChapter,
                            tooltip: "Próximo Capítulo",
                            splashRadius: 24),
                      ]),
                    ])),
              ),
              if (selectedBook != null &&
                  selectedChapter != null &&
                  _selectedBookSlug != null)
                Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                  key: _futureBuilderKey,
                  future: BiblePageHelper.loadChapterDataComparison(
                      selectedBook!,
                      selectedChapter!,
                      selectedTranslation1,
                      _isCompareModeActive ? selectedTranslation2 : null),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFCDE7BE)));
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data == null) {
                      return Center(
                          child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Erro ao carregar dados do capítulo: ${snapshot.error ?? 'Dados não encontrados'}',
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center),
                      ));
                    }
                    final chapterData = snapshot.data!;
                    final List<Map<String, dynamic>> sections =
                        chapterData['sectionStructure'] ?? [];
                    final Map<String, dynamic> verseDataMap =
                        chapterData['verseData'] ?? {}; // Alterado
                    final dynamic verses1Data =
                        verseDataMap[selectedTranslation1]; // Alterado
                    final dynamic verses2Data =
                        (_isCompareModeActive && selectedTranslation2 != null)
                            ? verseDataMap[selectedTranslation2!] // Alterado
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
                              style: TextStyle(color: Colors.white70)));
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
                              allVerseDataInChapter:
                                  verses1Data, // Passa o dado dinâmico
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
                              isHebrew:
                                  isCurrentTranslation1Hebrew, // Passa a flag
                            );
                          } else if (verses1Data != null &&
                              (verses1Data as List).isNotEmpty) {
                            // Renderiza todos os versos se não houver seções
                            final List listData = verses1Data as List;
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(listData.length,
                                    (verseIndex) {
                                  return BiblePageWidgets.buildVerseItem(
                                    verseNumber: verseIndex + 1,
                                    verseData: listData[
                                        verseIndex], // Passa o item da lista (String ou List<Map>)
                                    selectedBook: selectedBook,
                                    selectedChapter: selectedChapter,
                                    context: context,
                                    userHighlights: viewModel.userHighlights,
                                    userNotes: viewModel.userNotes,
                                    isHebrew:
                                        isCurrentTranslation1Hebrew, // Passa a flag
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
                              selectedTranslation2 != null) {
                        return Center(
                            child: Text(
                                'Tradução "$selectedTranslation2" não encontrada para este capítulo.',
                                style: TextStyle(color: Colors.orangeAccent)));
                      }
                      final list1Data = verses1Data as List;
                      final list2Data = verses2Data as List?; // Pode ser nulo
                      final maxVerseCount =
                          list1Data.length > (list2Data?.length ?? 0)
                              ? list1Data.length
                              : (list2Data?.length ?? 0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _buildComparisonColumn(
                                  context,
                                  sections,
                                  list1Data,
                                  maxVerseCount,
                                  viewModel.userHighlights,
                                  viewModel.userNotes,
                                  selectedTranslation1,
                                  isHebrew: isCurrentTranslation1Hebrew)),
                          const VerticalDivider(
                              width: 1, color: Colors.white24, thickness: 0.5),
                          Expanded(
                              child: _buildComparisonColumn(
                                  context,
                                  sections,
                                  list2Data ?? [],
                                  maxVerseCount, // Passa lista vazia se nulo
                                  viewModel.userHighlights,
                                  viewModel.userNotes,
                                  selectedTranslation2!,
                                  isHebrew: isCurrentTranslation2Hebrew)),
                        ],
                      );
                    }
                  },
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List
          verseColumnData, // Agora é List (pode ser List<String> ou List<List<Map>>)
      int maxVerseCount,
      Map<String, String> userHighlights,
      Map<String, String> userNotes,
      String currentTranslation,
      {bool isHebrew = false}) {
    if (verseColumnData.isEmpty &&
        sections.isEmpty &&
        currentTranslation.isNotEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Tradução '$currentTranslation' indisponível para este capítulo.",
          style: TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ));
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
                    style: const TextStyle(
                        color: Color(0xFFCDE7BE),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              ...verseNumbers.map((verseNumber) {
                final verseIndex = verseNumber - 1;
                final dynamic verseDataItem =
                    (verseIndex >= 0 && verseIndex < verseColumnData.length)
                        ? verseColumnData[verseIndex]
                        : (isHebrew
                            ? []
                            : "[Texto Indisponível]"); // Fallback apropriado
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
              }).toList(),
            ],
          );
        } else if (verseColumnData.isNotEmpty) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(verseColumnData.length, (verseIndex) {
                // Usa verseColumnData.length
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

  @override
  void dispose() {
    super.dispose();
  }
}
