// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart'; // Certifique-se que este widget aceita userHighlights e userNotes
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
// <<< REMOVIDO: Rotas não são mais diretamente usadas aqui se BibleRoutesWidget é uma página separada >>>
// import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
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

  // Estados para Comparação
  String selectedTranslation1 = 'nvi';
  String? selectedTranslation2 = 'acf';
  bool _isCompareModeActive = false;

  // Estado para Modo Foco
  bool _isFocusModeActive = false;

  bool showBibleRoutes = false;

  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};

  ValueKey _futureBuilderKey = const ValueKey('initial');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _updateFutureBuilderKey(); // Define a chave inicial

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialNavigation();
      _loadUserDataIfNeeded();
    });
  }

  void _updateFutureBuilderKey() {
    _futureBuilderKey = ValueKey(
        '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkInitialNavigation();
  }

  // --- Funções de Carregamento e Navegação (sem alterações do código anterior) ---
  void _checkInitialNavigation() {
    if (!_initialLocationSet && mounted) {
      final store = StoreProvider.of<AppState>(context, listen: false);
      final initialBook = store.state.userState.initialBibleBook;
      final initialChapter = store.state.userState.initialBibleChapter;

      if (initialBook != null && initialChapter != null) {
        print(
            ">>> BiblePage: Recebendo navegação inicial para $initialBook $initialChapter");
        if (booksMap != null && booksMap!.containsKey(initialBook)) {
          final bookData = booksMap![initialBook];
          if (initialChapter >= 1 &&
              initialChapter <= (bookData['capitulos'] as int)) {
            setState(() {
              selectedBook = initialBook;
              selectedChapter = initialChapter;
              _updateSelectedBookSlug();
              _initialLocationSet = true;
              _updateFutureBuilderKey();
            });
            store.dispatch(SetInitialBibleLocationAction(null, null));
          } else {
            print(
                ">>> BiblePage: Capítulo inicial inválido recebido: $initialChapter");
            store.dispatch(SetInitialBibleLocationAction(null, null));
          }
        } else {
          print(">>> BiblePage: Livro inicial inválido recebido: $initialBook");
          store.dispatch(SetInitialBibleLocationAction(null, null));
        }
      }
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
        selectedBook = 'gn';
        selectedChapter = 1;
        _updateSelectedBookSlug();
        _updateFutureBuilderKey();
      });
    }
  }

  Future<void> _loadBookVariationsMap() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Biblia/book_variations_map.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      _bookVariationsMap =
          decodedJson.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print("Erro ao carregar book_variations_map.json: $e");
      _bookVariationsMap = {};
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
    _updateFutureBuilderKey();
  }

  void _navigateToChapter(String bookAbbrev, int chapter) {
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        if (mounted) {
          setState(() {
            selectedBook = bookAbbrev;
            selectedChapter = chapter;
            _updateSelectedBookSlug();
            _updateFutureBuilderKey();
          });
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
    if (selectedChapter! > 1) {
      if (mounted) {
        setState(() {
          selectedChapter = selectedChapter! - 1;
          _updateFutureBuilderKey();
        });
      }
    } else {
      int currentBookIndex = booksMap!.keys.toList().indexOf(selectedBook!);
      if (currentBookIndex > 0) {
        String prevBookAbbrev = booksMap!.keys.toList()[currentBookIndex - 1];
        int lastChapterOfPrevBook =
            booksMap![prevBookAbbrev]['capitulos'] as int;
        if (mounted) {
          setState(() {
            selectedBook = prevBookAbbrev;
            selectedChapter = lastChapterOfPrevBook;
            _updateSelectedBookSlug();
            _updateFutureBuilderKey();
          });
        }
      }
    }
  }

  void _nextChapter() {
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    int totalChaptersInCurrentBook =
        booksMap![selectedBook!]['capitulos'] as int;
    if (selectedChapter! < totalChaptersInCurrentBook) {
      if (mounted) {
        setState(() {
          selectedChapter = selectedChapter! + 1;
          _updateFutureBuilderKey();
        });
      }
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex < bookKeys.length - 1) {
        String nextBookAbbrev = bookKeys[currentBookIndex + 1];
        if (mounted) {
          setState(() {
            selectedBook = nextBookAbbrev;
            selectedChapter = 1;
            _updateSelectedBookSlug();
            _updateFutureBuilderKey();
          });
        }
      }
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
                    if (mounted) {
                      setDialogState(() => errorTextInDialog = newError);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Formatos aceitos:\n- Livro Capítulo (Ex: Gênesis 1, Jo 3)\n- Livro Capítulo:Versículo (Ex: Ex 20:3)",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => _parseAndNavigate(
                            controller.text, dialogContext, (newError) {
                          if (mounted) {
                            setDialogState(() => errorTextInDialog = newError);
                          }
                        }),
                    child:
                        const Text("Ir", style: TextStyle(color: Colors.green)))
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
  // --- FIM Funções de Carregamento e Navegação ---

  @override
  Widget build(BuildContext context) {
    if (booksMap == null ||
        (_bookVariationsMap.isEmpty &&
            ModalRoute.of(context)?.isCurrent == true)) {
      return const Scaffold(
          appBar: null,
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFCDE7BE))));
    }

    // Define o título da AppBar dinamicamente
    String appBarTitle = 'Bíblia';
    if (_isFocusModeActive) {
      appBarTitle = booksMap?[selectedBook]?['nome'] ?? 'Bíblia';
      if (selectedChapter != null) appBarTitle += ' $selectedChapter';
    } else if (_isCompareModeActive) {
      appBarTitle = 'Comparar Traduções';
    }

    return Scaffold(
      // AppBar com ações condicionais
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: const Color(0xFF181A1A),
        leading: _isFocusModeActive
            ? const SizedBox.shrink()
            : null, // Esconde botão voltar padrão
        actions: [
          // Botão de Modo Foco sempre visível
          IconButton(
            icon: Icon(
              _isFocusModeActive ? Icons.fullscreen_exit : Icons.fullscreen,
              color: _isFocusModeActive ? Colors.blueAccent : Colors.white70,
            ),
            tooltip: _isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura",
            onPressed: () {
              setState(() {
                _isFocusModeActive = !_isFocusModeActive;
              });
            },
          ),
          // Outras ações só aparecem se NÃO estiver em modo foco
          Visibility(
            visible: !_isFocusModeActive,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    setState(() {
                      _isCompareModeActive = !_isCompareModeActive;
                      _updateFutureBuilderKey();
                      if (_isCompareModeActive &&
                          selectedTranslation1 == selectedTranslation2) {
                        selectedTranslation2 =
                            (selectedTranslation1 == 'nvi') ? 'acf' : 'nvi';
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.manage_search_outlined),
                  tooltip: "Ir para referência",
                  onPressed: _showGoToDialog,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Controles Superiores Condicionais
          Visibility(
            visible: !_isFocusModeActive,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botão Tradução 1
                        ElevatedButton.icon(
                            icon: const Icon(Icons.translate, size: 18),
                            label: Text(selectedTranslation1.toUpperCase(),
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              BiblePageWidgets.showTranslationSelection(
                                context: context,
                                selectedTranslation: selectedTranslation1,
                                onTranslationSelected: (value) {
                                  if (mounted &&
                                      value != selectedTranslation2) {
                                    setState(() {
                                      selectedTranslation1 = value;
                                      _updateFutureBuilderKey();
                                    });
                                  }
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF272828),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                elevation: 2)),

                        // Botão Tradução 2 (visível em compare mode)
                        if (_isCompareModeActive)
                          ElevatedButton.icon(
                              icon: const Icon(Icons.translate, size: 18),
                              label: Text(
                                  selectedTranslation2?.toUpperCase() ?? '...',
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () {
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
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF272828),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  elevation: 2)),

                        // Botão Rotas
                        ElevatedButton.icon(
                            icon:
                                const Icon(Icons.alt_route_outlined, size: 18),
                            label: const Text("Rotas",
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              if (mounted) {
                                // Navegar para a página de Rotas
                                // Ex: Navigator.push(context, MaterialPageRoute(builder: (_) => BibleRoutesPage()));
                                // Ou usar setState se for mostrar dentro desta página
                                // setState(() => showBibleRoutes = true); // Se for exibir aqui mesmo
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Linha de Navegação de Livro/Capítulo
                    Row(
                      children: [
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
                                if (mounted) {
                                  setState(() {
                                    selectedBook = value;
                                    selectedChapter = 1;
                                    _updateSelectedBookSlug();
                                  });
                                }
                              },
                            )),
                        const SizedBox(width: 8),
                        if (selectedBook != null)
                          Expanded(
                              flex: 2,
                              child: UtilsBiblePage.buildChapterDropdown(
                                selectedChapter: selectedChapter,
                                booksMap: booksMap,
                                selectedBook: selectedBook,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      selectedChapter = value;
                                      _updateFutureBuilderKey();
                                    });
                                  }
                                },
                              )),
                        IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.white, size: 32),
                            onPressed: _nextChapter,
                            tooltip: "Próximo Capítulo",
                            splashRadius: 24),
                      ],
                    ),
                  ],
                )),
          ),

          // Conteúdo Principal (FutureBuilder)
          if (selectedBook != null &&
              selectedChapter != null &&
              _selectedBookSlug != null)
            Expanded(
              child: StoreConnector<AppState, _ViewModel>(
                converter: (store) => _ViewModel.fromStore(store),
                builder: (context, vm) {
                  return FutureBuilder<Map<String, dynamic>>(
                    key: _futureBuilderKey,
                    future: BiblePageHelper.loadChapterDataComparison(
                      selectedBook!,
                      selectedChapter!,
                      selectedTranslation1,
                      _isCompareModeActive ? selectedTranslation2 : null,
                    ),
                    builder: (context, snapshot) {
                      // --- Lógica de Exibição (sem alterações) ---
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
                      final List<String> verses2 =
                          (_isCompareModeActive && selectedTranslation2 != null)
                              ? (verseTextsMap[selectedTranslation2!] ?? [])
                              : [];
                      if (verses1.isEmpty) {
                        return const Center(
                            child: Text(
                                'Capítulo não encontrado ou vazio para a tradução principal.',
                                style: TextStyle(color: Colors.white70)));
                      }

                      if (!_isCompareModeActive) {
                        // --- Modo de Coluna Única ---
                        return ListView.builder(
                          padding: EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              bottom: 16.0,
                              top: _isFocusModeActive
                                  ? 8.0
                                  : 0.0), // Ajusta padding top no modo foco
                          itemCount: sections.isNotEmpty
                              ? sections.length
                              : (verses1.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, sectionIndex) {
                            if (sections.isNotEmpty) {
                              final section = sections[sectionIndex];
                              final String sectionTitle =
                                  section['title'] ?? 'Seção';
                              final List<int> verseNumbers =
                                  (section['verses'] as List?)?.cast<int>() ??
                                      [];
                              String versesRangeStr = "";
                              if (verseNumbers.isNotEmpty) {
                                verseNumbers.sort();
                                versesRangeStr = verseNumbers.length == 1
                                    ? verseNumbers.first.toString()
                                    : "${verseNumbers.first}-${verseNumbers.last}";
                              }
                              return SectionItemWidget(
                                sectionTitle: sectionTitle,
                                verseNumbersInSection: verseNumbers,
                                allVerseTextsInChapter: verses1,
                                bookSlug: _selectedBookSlug!,
                                bookAbbrev: selectedBook!,
                                chapterNumber: selectedChapter!,
                                versesRangeStr: versesRangeStr,
                                userHighlights: vm.userHighlights,
                                userNotes: vm.userNotes,
                              );
                            } else if (verses1.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    List.generate(verses1.length, (verseIndex) {
                                  final verseNumber = verseIndex + 1;
                                  final verseText = verses1[verseIndex];
                                  return BiblePageWidgets.buildVerseItem(
                                    verseNumber: verseNumber,
                                    verseText: verseText,
                                    selectedBook: selectedBook,
                                    selectedChapter: selectedChapter,
                                    context: context,
                                    userHighlights: vm.userHighlights,
                                    userNotes: vm.userNotes,
                                  );
                                }),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      } else {
                        // --- Modo de Comparação ---
                        if (verses2.isEmpty) {
                          return const Center(
                              child: Text(
                                  'Tradução secundária não encontrada ou vazia.',
                                  style: TextStyle(color: Colors.white70)));
                        }
                        final maxVerseCount = verses1.length > verses2.length
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
                          ],
                        );
                      }
                      // --- FIM Lógica de Exibição ---
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Widget Helper para construir uma coluna de comparação (sem alterações)
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
          top: _isFocusModeActive ? 8.0 : 0.0), // Ajusta padding top
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
                child: Text(
                  sectionTitle,
                  style: const TextStyle(
                      color: Color(0xFFCDE7BE),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
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
            ],
          );
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
            }),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ViewModel para o StoreConnector (sem alterações)
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

// Função mapEquals (sem alterações)
bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}
