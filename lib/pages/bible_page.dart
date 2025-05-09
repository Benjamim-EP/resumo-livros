// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart'; // for mapEquals

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  Map<String, dynamic>? booksMap;
  String? selectedBook;
  int? selectedChapter;
  bool _initialLocationSet = false;

  String selectedTranslation1 = 'nvi';
  String? selectedTranslation2 = 'acf';
  bool _isCompareModeActive = false;
  bool _isFocusModeActive = false;
  String? _lastRecordedHistoryRef;
  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};
  ValueKey _futureBuilderKey = const ValueKey('initial');

  @override
  void initState() {
    super.initState();
    _loadInitialData().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Adicionado verificação de montado aqui também
          _checkInitialNavigation();
          _loadUserDataIfNeeded();
        }
      });
    });
  }

  void _updateFutureBuilderKey() {
    if (mounted) {
      setState(() {
        _futureBuilderKey = ValueKey(
            '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}-${DateTime.now().millisecondsSinceEpoch}'); // Adiciona timestamp para forçar reconstrução
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      // Adicionado verificação
      _checkInitialNavigation();
    }
  }

  void _checkInitialNavigation() {
    if (!_initialLocationSet && mounted && booksMap != null) {
      final store = StoreProvider.of<AppState>(context, listen: false);
      final initialBookNav = store.state.userState.initialBibleBook;
      final initialChapterNav = store.state.userState.initialBibleChapter;

      String targetBook =
          initialBookNav ?? store.state.userState.lastReadBookAbbrev ?? 'gn';
      int targetChapter =
          initialChapterNav ?? store.state.userState.lastReadChapter ?? 1;

      print(
          ">>> BiblePage _checkInitialNavigation: Tentando ir para $targetBook $targetChapter. initialNav: $initialBookNav/$initialChapterNav, lastRead: ${store.state.userState.lastReadBookAbbrev}/${store.state.userState.lastReadChapter}");

      if (initialBookNav != null || initialChapterNav != null) {
        store.dispatch(SetInitialBibleLocationAction(null, null));
      }

      String finalBookToNavigate = 'gn';
      int finalChapterToNavigate = 1;

      if (booksMap!.containsKey(targetBook)) {
        final bookData = booksMap![targetBook];
        if (targetChapter >= 1 &&
            targetChapter <= (bookData['capitulos'] as int)) {
          finalBookToNavigate = targetBook;
          finalChapterToNavigate = targetChapter;
        } else {
          print(
              ">>> BiblePage _checkInitialNavigation: Capítulo alvo ($targetChapter) inválido para $targetBook. Usando padrão.");
        }
      } else {
        print(
            ">>> BiblePage _checkInitialNavigation: Livro alvo ($targetBook) inválido. Usando padrão.");
      }

      print(
          ">>> BiblePage _checkInitialNavigation: Estado antes do setState: selectedBook=$selectedBook, selectedChapter=$selectedChapter");
      if (mounted) {
        setState(() {
          selectedBook = finalBookToNavigate;
          selectedChapter = finalChapterToNavigate;
          _updateSelectedBookSlug();
          _initialLocationSet = true;
          // _updateFutureBuilderKey(); // Será chamado após _recordHistory para garantir a ordem
        });
      }
      print(
          ">>> BiblePage _checkInitialNavigation: Estado APÓS setState: selectedBook=$selectedBook, selectedChapter=$selectedChapter. Gravando histórico...");
      _recordHistory(finalBookToNavigate, finalChapterToNavigate);
      _updateFutureBuilderKey(); // Chamar após o registro do histórico inicial
    } else if (booksMap == null && mounted) {
      print(">>> BiblePage: booksMap ainda nulo em _checkInitialNavigation.");
    }
  }

  void _loadUserDataIfNeeded() {
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
    if (mounted) {
      setState(() {
        booksMap = map;
      });
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
      if (mounted) {
        setState(() {
          _bookVariationsMap = {};
        });
      }
    }
  }

  void _updateSelectedBookSlug() {
    if (selectedBook != null &&
        booksMap != null &&
        booksMap![selectedBook] != null) {
      if (mounted) {
        setState(() {
          _selectedBookSlug = booksMap![selectedBook]?['slug'] as String?;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedBookSlug = null;
        });
      }
    }
  }

  void _recordHistory(String bookAbbrev, int chapter) {
    final currentRef = "${bookAbbrev}_$chapter";
    // Força o registro se for diferente do último gravado OU se _lastRecordedHistoryRef for null (primeira vez)
    if (_lastRecordedHistoryRef == null ||
        _lastRecordedHistoryRef != currentRef) {
      print(
          ">>> BiblePage _recordHistory: Gravando histórico para $currentRef. Último gravado: $_lastRecordedHistoryRef");
      if (context.mounted) {
        // Garante que o contexto é válido
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(RecordReadingHistoryAction(bookAbbrev, chapter));
      }
      _lastRecordedHistoryRef = currentRef; // Atualiza aqui
    } else {
      print(
          ">>> BiblePage _recordHistory: Histórico para $currentRef já gravado recentemente (Last: $_lastRecordedHistoryRef)");
    }
  }

  void _navigateToChapter(String bookAbbrev, int chapter) {
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        print(
            ">>> _navigateToChapter: Tentando navegar para $bookAbbrev $chapter. Estado anterior: $selectedBook $selectedChapter");
        if (mounted) {
          setState(() {
            selectedBook = bookAbbrev;
            selectedChapter = chapter;
            _updateSelectedBookSlug(); // Deve ser chamado dentro do setState ou se o estado realmente mudar
          });
          _recordHistory(bookAbbrev, chapter);
          _updateFutureBuilderKey(); // Chamar após registrar o histórico
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Capítulo $chapter inválido para ${bookData['nome']}.')));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Livro "$bookAbbrev" não encontrado.')));
      }
    }
  }

  void _previousChapter() {
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    print(">>> _previousChapter: Estado ATUAL: $selectedBook $selectedChapter");

    String newBookAbbrev = selectedBook!;
    int newChapter = selectedChapter!;
    bool bookChanged = false;

    if (selectedChapter! > 1) {
      newChapter = selectedChapter! - 1;
      print(
          ">>> _previousChapter: Capítulo anterior no MESMO livro: $newChapter");
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex > 0) {
        newBookAbbrev = bookKeys[currentBookIndex - 1];
        newChapter = booksMap![newBookAbbrev]['capitulos'] as int;
        bookChanged = true;
        print(
            ">>> _previousChapter: Indo para o ÚLTIMO capítulo do livro ANTERIOR: $newBookAbbrev $newChapter");
      } else {
        print(
            ">>> _previousChapter: Já está no primeiro capítulo do primeiro livro.");
        return;
      }
    }

    if (mounted) {
      setState(() {
        selectedBook = newBookAbbrev;
        selectedChapter = newChapter;
        if (bookChanged) _updateSelectedBookSlug();
      });
      _recordHistory(newBookAbbrev, newChapter);
      _updateFutureBuilderKey();
    }
  }

  void _nextChapter() {
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    print(">>> _nextChapter: Estado ATUAL: $selectedBook $selectedChapter");

    String newBookAbbrev = selectedBook!;
    int newChapter = selectedChapter!;
    bool bookChanged = false;
    int totalChaptersInCurrentBook =
        booksMap![selectedBook!]['capitulos'] as int;

    if (selectedChapter! < totalChaptersInCurrentBook) {
      newChapter = selectedChapter! + 1;
      print(">>> _nextChapter: Próximo capítulo no MESMO livro: $newChapter");
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex < bookKeys.length - 1) {
        newBookAbbrev = bookKeys[currentBookIndex + 1];
        newChapter = 1;
        bookChanged = true;
        print(
            ">>> _nextChapter: Indo para o PRIMEIRO capítulo do PRÓXIMO livro: $newBookAbbrev $newChapter");
      } else {
        print(">>> _nextChapter: Já está no último capítulo do último livro.");
        return;
      }
    }

    if (mounted) {
      setState(() {
        selectedBook = newBookAbbrev;
        selectedChapter = newChapter;
        if (bookChanged) _updateSelectedBookSlug();
      });
      _recordHistory(newBookAbbrev, newChapter);
      _updateFutureBuilderKey();
    }
  }

  Future<void> _showGoToDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
        context: context,
        builder: (dialogContext) {
          String? errorTextInDialog;
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
        _navigateToChapter(bookAbbrev, chapter);
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
    if (booksMap == null || selectedBook == null || selectedChapter == null) {
      return const Scaffold(
          appBar: null, // Ou um AppBar simples de "Carregando..."
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFCDE7BE))));
    }

    String appBarTitle = 'Bíblia';
    if (_isFocusModeActive) {
      appBarTitle = booksMap?[selectedBook]?['nome'] ?? 'Bíblia';
      appBarTitle += ' $selectedChapter';
    } else if (_isCompareModeActive) {
      appBarTitle = 'Comparar Traduções';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: const Color(0xFF181A1A),
        leading: _isFocusModeActive ? const SizedBox.shrink() : null,
        actions: [
          IconButton(
            icon: Icon(
              _isFocusModeActive ? Icons.fullscreen_exit : Icons.fullscreen,
              color: _isFocusModeActive ? Colors.blueAccent : Colors.white70,
            ),
            tooltip: _isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura",
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
                  color: _isCompareModeActive ? Colors.amber : Colors.white70,
                ),
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
                    });
                    _updateFutureBuilderKey();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.manage_search_outlined),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
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
                                    selectedTranslation: selectedTranslation1,
                                    onTranslationSelected: (value) {
                                      if (mounted &&
                                          value != selectedTranslation2) {
                                        setState(
                                            () => selectedTranslation1 = value);
                                        _updateFutureBuilderKey();
                                      }
                                    }),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF272828),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                elevation: 2)),
                        if (_isCompareModeActive)
                          ElevatedButton.icon(
                              icon: const Icon(Icons.translate, size: 18),
                              label: Text(
                                  selectedTranslation2?.toUpperCase() ?? '...',
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () =>
                                  BiblePageWidgets.showTranslationSelection(
                                      context: context,
                                      selectedTranslation:
                                          selectedTranslation2 ?? 'aa',
                                      onTranslationSelected: (value) {
                                        if (mounted &&
                                            value != selectedTranslation1) {
                                          setState(() =>
                                              selectedTranslation2 = value);
                                          _updateFutureBuilderKey();
                                        }
                                      }),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF272828),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  elevation: 2)),
                        ElevatedButton.icon(
                            icon:
                                const Icon(Icons.alt_route_outlined, size: 18),
                            label: const Text("Rotas",
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Navegação para Rotas (a implementar)")));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF272828),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
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
                child: StoreConnector<AppState, _ViewModel>(
                    converter: (store) => _ViewModel.fromStore(store),
                    // Otimização: só reconstruir se os highlights ou notas mudarem
                    // Isso pode ser complexo se a estrutura dos dados for profunda.
                    // Por enquanto, o rebuildOnChange: true é mais simples.
                    // Se houver problemas de performance, considere um `distinct`
                    // ou um `equals` mais granular no ViewModel.
                    rebuildOnChange: true, // Pode otimizar se necessário
                    builder: (context, vm) {
                      print(
                          ">>> BiblePage StoreConnector REBUILDING para $selectedBook $selectedChapter. Highlights: ${vm.userHighlights.length}, Notes: ${vm.userNotes.length}");
                      return FutureBuilder<Map<String, dynamic>>(
                        key: _futureBuilderKey,
                        future: BiblePageHelper.loadChapterDataComparison(
                            selectedBook!,
                            selectedChapter!,
                            selectedTranslation1,
                            _isCompareModeActive ? selectedTranslation2 : null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                                  'Erro ao carregar dados: ${snapshot.error ?? 'Dados não encontrados'}',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center),
                            ));
                          }
                          final chapterData = snapshot.data!;
                          final List<Map<String, dynamic>> sections =
                              chapterData['sectionStructure'] ?? [];
                          final Map<String, List<String>> verseTextsMap =
                              chapterData['verseTexts'] ?? {};
                          final List<String> verses1 =
                              verseTextsMap[selectedTranslation1] ?? [];
                          final List<String> verses2 = (_isCompareModeActive &&
                                  selectedTranslation2 != null)
                              ? (verseTextsMap[selectedTranslation2!] ?? [])
                              : [];
                          if (verses1.isEmpty) {
                            return const Center(
                                child: Text(
                                    'Capítulo não encontrado ou vazio para a tradução principal.',
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
                                  : (verses1.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, sectionIndex) {
                                if (sections.isNotEmpty) {
                                  final section = sections[sectionIndex];
                                  return SectionItemWidget(
                                    sectionTitle: section['title'] ?? 'Seção',
                                    verseNumbersInSection:
                                        (section['verses'] as List?)
                                                ?.cast<int>() ??
                                            [],
                                    allVerseTextsInChapter: verses1,
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
                                    userHighlights: vm.userHighlights,
                                    userNotes: vm.userNotes,
                                  );
                                } else if (verses1.isNotEmpty) {
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: List.generate(verses1.length,
                                          (verseIndex) {
                                        return BiblePageWidgets.buildVerseItem(
                                          verseNumber: verseIndex + 1,
                                          verseText: verses1[verseIndex],
                                          selectedBook: selectedBook,
                                          selectedChapter: selectedChapter,
                                          context: context,
                                          userHighlights: vm.userHighlights,
                                          userNotes: vm.userNotes,
                                        );
                                      }));
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          } else {
                            if (verses2.isEmpty) {
                              return const Center(
                                  child: Text(
                                      'Tradução secundária não encontrada ou vazia.',
                                      style: TextStyle(color: Colors.white70)));
                            }
                            final maxVerseCount =
                                verses1.length > verses2.length
                                    ? verses1.length
                                    : verses2.length;
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _buildComparisonColumn(
                                          context,
                                          sections,
                                          verses1,
                                          maxVerseCount,
                                          vm.userHighlights,
                                          vm.userNotes,
                                          selectedTranslation1)),
                                  const VerticalDivider(
                                      width: 1, color: Colors.white24),
                                  Expanded(
                                      child: _buildComparisonColumn(
                                          context,
                                          sections,
                                          verses2,
                                          maxVerseCount,
                                          vm.userHighlights,
                                          vm.userNotes,
                                          selectedTranslation2!)),
                                ]);
                          }
                        },
                      );
                    })),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List<String> verseTexts,
      int maxVerseCount,
      Map<String, String> userHighlights,
      Map<String, String> userNotes,
      String currentTranslation) {
    return ListView.builder(
      padding: EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          bottom: 16.0,
          top: _isFocusModeActive ? 8.0 : 0.0),
      itemCount: sections.isNotEmpty ? sections.length : 1,
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
                            fontWeight: FontWeight.bold))),
                ...verseNumbers.map((verseNumber) {
                  final verseIndex = verseNumber - 1;
                  final verseText =
                      (verseIndex >= 0 && verseIndex < verseTexts.length)
                          ? verseTexts[verseIndex]
                          : "[Texto indisponível nesta tradução]";
                  return BiblePageWidgets.buildVerseItem(
                    verseNumber: verseNumber,
                    verseText: verseText,
                    selectedBook: selectedBook,
                    selectedChapter: selectedChapter,
                    context: context,
                    userHighlights: userHighlights,
                    userNotes: userNotes,
                  );
                }).toList(),
              ]);
        } else {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(maxVerseCount, (verseIndex) {
                final verseNumber = verseIndex + 1;
                final verseText =
                    (verseIndex >= 0 && verseIndex < verseTexts.length)
                        ? verseTexts[verseIndex]
                        : "[Texto indisponível nesta tradução]";
                return BiblePageWidgets.buildVerseItem(
                  verseNumber: verseNumber,
                  verseText: verseText,
                  selectedBook: selectedBook,
                  selectedChapter: selectedChapter,
                  context: context,
                  userHighlights: userHighlights,
                  userNotes: userNotes,
                );
              }));
        }
      },
    );
  }

  @override
  void dispose() {
    // Não precisa cancelar _userDocSubscription aqui, pois ele não é mais usado
    // e as outras inicializações e listeners são gerenciados pelo ciclo de vida do widget.
    super.dispose();
  }
}

class _ViewModel {
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;

  _ViewModel({required this.userHighlights, required this.userNotes});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      userHighlights: store.state.userState.userHighlights,
      userNotes: store.state.userState.userNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userHighlights, other.userHighlights) &&
          mapEquals(userNotes, other.userNotes);

  @override
  int get hashCode => userHighlights.hashCode ^ userNotes.hashCode;
}

// bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
//   if (a == null) return b == null;
//   if (b == null || a.length != b.length) return false;
//   for (final key in a.keys) {
//     if (!b.containsKey(key) || a[key] != b[key]) {
//       return false;
//     }
//   }
//   return true;
// }