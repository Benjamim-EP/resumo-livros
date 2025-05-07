// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart'; // Certifique-se que este widget aceita userHighlights e userNotes
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

  // <<< NOVO: Estados para Comparação >>>
  String selectedTranslation1 = 'nvi'; // Renomeado de selectedTranslation
  String? selectedTranslation2 = 'acf'; // Segunda tradução (padrão opcional)
  bool _isCompareModeActive = false;
  // <<< FIM NOVO >>>

  bool showBibleRoutes = false; // Mantido para a funcionalidade de Rotas

  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};

  // Chave para forçar o rebuild do FutureBuilder ao mudar modo/traduções
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

  // <<< NOVO: Atualiza a chave do FutureBuilder >>>
  void _updateFutureBuilderKey() {
    _futureBuilderKey = ValueKey(
        '$selectedBook-$selectedChapter-$selectedTranslation1-${_isCompareModeActive ? selectedTranslation2 : 'single'}');
  }
  // <<< FIM NOVO >>>

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkInitialNavigation();
  }

  void _checkInitialNavigation() {
    if (!_initialLocationSet && mounted) {
      // ... (lógica _checkInitialNavigation como antes) ...
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
              _updateFutureBuilderKey(); // Atualiza chave ao navegar
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
        _updateFutureBuilderKey(); // Atualiza chave
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
    _updateFutureBuilderKey(); // Atualiza chave
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
            _updateFutureBuilderKey(); // Atualiza chave
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
          _updateFutureBuilderKey(); // Atualiza chave
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
            _updateFutureBuilderKey(); // Atualiza chave
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
          _updateFutureBuilderKey(); // Atualiza chave
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
            _updateFutureBuilderKey(); // Atualiza chave
          });
        }
      }
    }
  }

  Future<void> _showGoToDialog() async {
    // ... (lógica _showGoToDialog como antes) ...
    final TextEditingController controller = TextEditingController();
    await showDialog(
        context: context,
        builder: (dialogContext) {
          /* ... AlertDialog ... */
          String? errorTextInDialog;
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(/* ... Conteúdo e Ações ... */);
          });
        });
  }

  void _parseAndNavigate(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    // ... (lógica _parseAndNavigate como antes) ...
    if (input.trim().isEmpty) {
      /* ... */ return;
    }
    String normalizedInput =
        input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    String? foundBookAbbrev;
    String remainingInputForChapter = normalizedInput;
    List<String> sortedVariationKeys = _bookVariationsMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String variationKey in sortedVariationKeys) {/* ... */}
    if (foundBookAbbrev == null) {
      /* ... */ return;
    }
    final RegExp chapVerseRegex = RegExp(r'^(\d+)(?:\s*:\s*\d+.*)?$');
    final Match? cvMatch = chapVerseRegex.firstMatch(remainingInputForChapter);
    if (cvMatch == null || cvMatch.group(1) == null) {
      /* ... */ return;
    }
    final int? chapter = int.tryParse(cvMatch.group(1)!);
    if (chapter == null) {
      /* ... */ return;
    }
    _finalizeNavigation(
        foundBookAbbrev, chapter, dialogContext, updateErrorText);
  }

  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
    // ... (lógica _finalizeNavigation como antes) ...
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      /* ... */
    } else {/* ... */}
  }

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCompareModeActive
            ? 'Comparar Traduções'
            : 'Bíblia'), // Título dinâmico
        backgroundColor: const Color(0xFF181A1A),
        actions: [
          // <<< NOVO: Botão Toggle para Comparação >>>
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
                _updateFutureBuilderKey(); // Atualiza chave ao mudar modo
                // Garante que a segunda tradução seja diferente da primeira ao ativar
                if (_isCompareModeActive &&
                    selectedTranslation1 == selectedTranslation2) {
                  selectedTranslation2 = (selectedTranslation1 == 'nvi')
                      ? 'acf'
                      : 'nvi'; // Exemplo simples
                }
              });
            },
          ),
          // <<< FIM NOVO >>>
          IconButton(
            icon: const Icon(Icons.manage_search_outlined),
            tooltip: "Ir para referência",
            onPressed: _showGoToDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Column(
                // Agrupa botões
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
                              if (mounted && value != selectedTranslation2) {
                                // Evita selecionar a mesma
                                setState(() {
                                  selectedTranslation1 = value;
                                  _updateFutureBuilderKey(); // Atualiza chave
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
                          elevation: 2,
                        ),
                      ),

                      // <<< NOVO: Botão Tradução 2 (visível em compare mode) >>>
                      if (_isCompareModeActive)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.translate, size: 18),
                          label: Text(
                              selectedTranslation2?.toUpperCase() ?? '...',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            BiblePageWidgets.showTranslationSelection(
                              context: context,
                              selectedTranslation: selectedTranslation2 ??
                                  'aa', // Passa um valor padrão se nulo
                              onTranslationSelected: (value) {
                                if (mounted && value != selectedTranslation1) {
                                  // Evita selecionar a mesma
                                  setState(() {
                                    selectedTranslation2 = value;
                                    _updateFutureBuilderKey(); // Atualiza chave
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
                            elevation: 2,
                          ),
                        ),
                      // <<< FIM NOVO >>>

                      // Botão Rotas (ajustado para caber)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.alt_route_outlined, size: 18),
                        label:
                            const Text("Rotas", style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          if (mounted) {
                            setState(() => showBibleRoutes = true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF272828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Linha de Navegação de Livro/Capítulo (mantida)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 32),
                        onPressed: _previousChapter,
                        tooltip: "Capítulo Anterior",
                        splashRadius: 24,
                      ),
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
                        ),
                      ),
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
                                  _updateFutureBuilderKey(); // Atualiza chave
                                });
                              }
                            },
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white, size: 32),
                        onPressed: _nextChapter,
                        tooltip: "Próximo Capítulo",
                        splashRadius: 24,
                      ),
                    ],
                  ),
                ],
              )),

          // <<< MODIFICAÇÃO: FutureBuilder e Renderização Condicional >>>
          if (selectedBook != null &&
              selectedChapter != null &&
              _selectedBookSlug != null)
            Expanded(
              child: StoreConnector<AppState, _ViewModel>(
                converter: (store) => _ViewModel.fromStore(store),
                // Não recria o widget se o ViewModel não mudar profundamente
                // Isso ajuda a performance quando só o highlight/note muda
                // distinct: true, // Habilite se tiver problemas de performance
                builder: (context, vm) {
                  return FutureBuilder<Map<String, dynamic>>(
                    key: _futureBuilderKey, // Usa a chave dinâmica
                    future: BiblePageHelper.loadChapterDataComparison(
                      // <<< CHAMA NOVA FUNÇÃO HELPER
                      selectedBook!,
                      selectedChapter!,
                      selectedTranslation1,
                      _isCompareModeActive
                          ? selectedTranslation2
                          : null, // Passa a segunda tradução se comparando
                    ),
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
                              'Erro ao carregar dados: ${snapshot.error ?? 'Dados não encontrados'}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                        ));
                      }

                      final chapterData = snapshot.data!;
                      final List<Map<String, dynamic>> sections =
                          chapterData['sectionStructure'] ?? [];
                      // <<< NOVO: Pega os textos das duas traduções >>>
                      final Map<String, List<String>> verseTextsMap =
                          chapterData['verseTexts'] ?? {};
                      final List<String> verses1 =
                          verseTextsMap[selectedTranslation1] ?? [];
                      final List<String> verses2 =
                          (_isCompareModeActive && selectedTranslation2 != null)
                              ? (verseTextsMap[selectedTranslation2!] ?? [])
                              : [];
                      // <<< FIM NOVO >>>

                      if (verses1.isEmpty) {
                        // Verifica se a tradução primária carregou
                        return const Center(
                            child: Text(
                                'Capítulo não encontrado ou vazio para a tradução principal.',
                                style: TextStyle(color: Colors.white70)));
                      }

                      // Renderiza uma ou duas colunas
                      if (!_isCompareModeActive) {
                        // --- Modo de Coluna Única (código anterior adaptado) ---
                        return ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
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
                                // Passa os dados da VM
                                sectionTitle: sectionTitle,
                                verseNumbersInSection: verseNumbers,
                                allVerseTextsInChapter: verses1, // Usa verses1
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
                                    // Passa os dados da VM
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
                        // --- Modo de Comparação (Duas Colunas) ---
                        if (verses2.isEmpty) {
                          // Verifica se a segunda tradução carregou
                          return const Center(
                              child: Text(
                                  'Tradução secundária não encontrada ou vazia.',
                                  style: TextStyle(color: Colors.white70)));
                        }
                        // Garante que ambas as listas tenham o mesmo tamanho (ou o máximo delas)
                        // Isso é crucial se uma tradução tiver um versículo a mais/menos (raro, mas possível)
                        final maxVerseCount = verses1.length > verses2.length
                            ? verses1.length
                            : verses2.length;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Coluna 1 (Tradução 1)
                            Expanded(
                              child: _buildComparisonColumn(
                                context,
                                sections,
                                verses1,
                                maxVerseCount, // Passa contagem máxima
                                vm.userHighlights,
                                vm.userNotes,
                                selectedTranslation1,
                              ),
                            ),
                            const VerticalDivider(
                                width: 1, color: Colors.white24), // Divisor
                            // Coluna 2 (Tradução 2)
                            Expanded(
                              child: _buildComparisonColumn(
                                context,
                                sections, // Usa a mesma estrutura de seções
                                verses2,
                                maxVerseCount, // Passa contagem máxima
                                vm.userHighlights,
                                vm.userNotes,
                                selectedTranslation2!, // Não será nulo aqui
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  );
                },
              ),
            ),
          // <<< FIM MODIFICAÇÃO >>>
        ],
      ),
    );
  }

  // <<< NOVO: Widget Helper para construir uma coluna de comparação >>>
  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List<String> verseTexts,
      int maxVerseCount, // Usado se não houver seções
      Map<String, String> userHighlights,
      Map<String, String> userNotes,
      String currentTranslation // Identificador da tradução para a coluna
      ) {
    return ListView.builder(
      padding: const EdgeInsets.only(
          left: 12.0, right: 12.0, bottom: 16.0, top: 8.0), // Padding ajustado
      itemCount: sections.isNotEmpty
          ? sections.length
          : 1, // Renderiza seções ou um bloco único
      itemBuilder: (context, sectionIndex) {
        if (sections.isNotEmpty) {
          // Renderiza por seção
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
                      fontWeight: FontWeight.bold), // Fonte menor
                ),
              ),
              ...verseNumbers.map((verseNumber) {
                final verseIndex = verseNumber - 1;
                // Pega o texto do verso, tratando se o índice for inválido para ESTA tradução
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
          // Renderiza todos os versos como um bloco único
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(maxVerseCount, (verseIndex) {
              // Usa maxVerseCount
              final verseNumber = verseIndex + 1;
              // Pega o texto do verso, tratando se o índice for inválido
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
  // <<< FIM NOVO >>>

  @override
  void dispose() {
    super.dispose();
  }
}

// <<< ViewModel para o StoreConnector (sem alterações) >>>
class _ViewModel {
  // ... (definição do _ViewModel como antes) ...
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
  // ... (definição de mapEquals como antes) ...
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}
