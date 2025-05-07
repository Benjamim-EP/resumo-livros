// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  Map<String, dynamic>? booksMap;
  String? selectedBook;
  int? selectedChapter;
  String selectedTranslation = 'nvi';
  bool showBibleRoutes = false;

  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap =
      {}; // <<< Alterado para carregar do JSON

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Carrega o mapeamento de variações primeiro
    await _loadBookVariationsMap();

    // Depois carrega o booksMap principal (que depende das abreviações canônicas)
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      // Verifica se o widget ainda está montado
      setState(() {
        booksMap = map;
        selectedBook = 'gn'; // Livro inicial padrão
        selectedChapter = 1; // Capítulo inicial padrão
        _updateSelectedBookSlug();
        // _buildBookNameToAbbrevMap(); // <<< REMOVIDO: Não é mais necessário construir aqui
      });
    }
  }

  // <<< NOVO: Função para carregar o JSON de variações >>>
  Future<void> _loadBookVariationsMap() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Biblia/book_variations_map.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      // Converte para Map<String, String>
      _bookVariationsMap =
          decodedJson.map((key, value) => MapEntry(key, value.toString()));
      print(
          "Book variations map carregado: ${_bookVariationsMap.length} entradas.");
    } catch (e) {
      print("Erro ao carregar book_variations_map.json: $e");
      // Lidar com o erro, talvez usando um mapa padrão ou mostrando uma mensagem
      _bookVariationsMap = {}; // Define como vazio em caso de erro
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

  void _navigateToChapter(String bookAbbrev, int chapter) {
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        if (mounted) {
          setState(() {
            selectedBook = bookAbbrev;
            selectedChapter = chapter;
            _updateSelectedBookSlug();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Capítulo $chapter inválido para ${bookData['nome']}.')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Livro "$bookAbbrev" não encontrado.')),
        );
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

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2F33),
              title: const Text("Ir para Referência",
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        // Adicionado verificação
                        setDialogState(() {
                          errorTextInDialog = newError;
                        });
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Formatos aceitos:\n- Livro Capítulo (Ex: Gênesis 1, Jo 3)\n- Livro Capítulo:Versículo (Ex: Ex 20:3)",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => _parseAndNavigate(
                      controller.text, dialogContext, (newError) {
                    if (mounted) {
                      // Adicionado verificação
                      setDialogState(() {
                        errorTextInDialog = newError;
                      });
                    }
                  }),
                  child:
                      const Text("Ir", style: TextStyle(color: Colors.green)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // <<< MODIFICADO: _parseAndNavigate agora usa _bookVariationsMap >>>
  void _parseAndNavigate(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    if (input.trim().isEmpty) {
      updateErrorText("Digite uma referência.");
      return;
    }
    // Normaliza a entrada para minúsculas e remove espaços duplos
    String normalizedInput =
        input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    String? foundBookAbbrev;
    String remainingInputForChapter = normalizedInput;

    // Ordena as chaves do mapa de variações pela mais longa primeiro para evitar matches parciais errados
    List<String> sortedVariationKeys = _bookVariationsMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String variationKey in sortedVariationKeys) {
      if (normalizedInput.startsWith(variationKey)) {
        foundBookAbbrev =
            _bookVariationsMap[variationKey]; // Pega a abreviação canônica
        remainingInputForChapter =
            normalizedInput.substring(variationKey.length).trim();
        break;
      }
    }

    if (foundBookAbbrev == null) {
      updateErrorText("Livro não reconhecido.");
      return;
    }

    // Regex para "Capitulo" ou "Capitulo:Versiculo"
    // O versículo é opcional e será ignorado para a navegação de capítulo
    final RegExp chapVerseRegex = RegExp(r'^(\d+)(?:\s*:\s*\d+.*)?$');
    final Match? cvMatch = chapVerseRegex.firstMatch(remainingInputForChapter);

    if (cvMatch == null || cvMatch.group(1) == null) {
      // Se não encontrou capítulo após o nome do livro, tenta pegar apenas o número se houver
      final RegExp chapOnlyRegex = RegExp(r'^(\d+)$');
      final Match? chapOnlyMatch =
          chapOnlyRegex.firstMatch(remainingInputForChapter);
      if (chapOnlyMatch == null || chapOnlyMatch.group(1) == null) {
        updateErrorText("Formato de capítulo inválido.");
        return;
      }
      final int? chapter = int.tryParse(chapOnlyMatch.group(1)!);
      if (chapter == null) {
        updateErrorText("Número do capítulo inválido.");
        return;
      }
      _finalizeNavigation(
          foundBookAbbrev, chapter, dialogContext, updateErrorText);
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
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        _navigateToChapter(bookAbbrev, chapter);
        if (Navigator.canPop(dialogContext)) {
          // Verifica se o diálogo ainda está na árvore
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
    // A UI permanece a mesma da resposta anterior, apenas a lógica de _parseAndNavigate mudou.
    // Certifique-se de que o booksMap e _bookVariationsMap sejam carregados antes de construir a UI principal.
    if (booksMap == null ||
        _bookVariationsMap.isEmpty &&
            ModalRoute.of(context)?.isCurrent == true) {
      // Adicionado `ModalRoute.of(context)?.isCurrent == true`
      // Mostra um loader enquanto os mapas essenciais não são carregados
      return const Scaffold(
          appBar: null, // Pode remover o AppBar aqui ou deixar um simples
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFCDE7BE))));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia'),
        backgroundColor: const Color(0xFF181A1A),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_outlined),
            tooltip: "Ir para referência",
            onPressed: _showGoToDialog,
          ),
        ],
      ),
      body: Column(
        // Mantém a Column principal
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.translate, size: 20),
                  label: Text(selectedTranslation.toUpperCase(),
                      style: const TextStyle(fontSize: 13)),
                  onPressed: () {
                    BiblePageWidgets.showTranslationSelection(
                      context: context,
                      selectedTranslation: selectedTranslation,
                      onTranslationSelected: (value) {
                        if (mounted) {
                          setState(() => selectedTranslation = value);
                        }
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF272828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route_outlined, size: 20),
                  label: const Text("Rotas", style: TextStyle(fontSize: 13)),
                  onPressed: () {
                    if (mounted) {
                      setState(() => showBibleRoutes = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF272828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
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
                          setState(() => selectedChapter = value);
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
          ),
          if (selectedBook != null &&
              selectedChapter != null &&
              _selectedBookSlug != null)
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (DragEndDetails details) {
                  if (details.primaryVelocity! > 300) {
                    _previousChapter();
                  } else if (details.primaryVelocity! < -300) {
                    _nextChapter();
                  }
                },
                child: FutureBuilder<Map<String, dynamic>>(
                  key: ValueKey(
                      '$selectedBook-$selectedChapter-$selectedTranslation'),
                  future: BiblePageHelper.loadChapterData(
                      selectedBook!, selectedChapter!, selectedTranslation),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFCDE7BE)));
                    } else if (snapshot.hasError) {
                      return Center(
                          child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Erro ao carregar dados do capítulo: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center),
                      ));
                    } else if (!snapshot.hasData ||
                        (snapshot.data!['verses'] as List).isEmpty) {
                      return const Center(
                          child: Text('Capítulo não encontrado ou vazio.',
                              style: TextStyle(color: Colors.white70)));
                    }

                    final chapterData = snapshot.data!;
                    final List<Map<String, dynamic>> sections =
                        List<Map<String, dynamic>>.from(
                            chapterData['sections'] ?? []);
                    final List<String> allVerses =
                        List<String>.from(chapterData['verses'] ?? []);

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
                      itemCount: sections.isNotEmpty
                          ? sections.length
                          : (allVerses.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, sectionIndex) {
                        if (sections.isNotEmpty) {
                          final section = sections[sectionIndex];
                          final String sectionTitle =
                              section['title'] ?? 'Seção';
                          final List<int> verseNumbers =
                              (section['verses'] as List?)?.cast<int>() ?? [];
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
                            allVerseTextsInChapter: allVerses,
                            bookSlug: _selectedBookSlug!,
                            bookAbbrev: selectedBook!,
                            chapterNumber: selectedChapter!,
                            versesRangeStr: versesRangeStr,
                          );
                        } else if (allVerses.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                List.generate(allVerses.length, (verseIndex) {
                              final verseNumber = verseIndex + 1;
                              final verseText = allVerses[verseIndex];
                              return BiblePageWidgets.buildVerseItem(
                                verseNumber: verseNumber,
                                verseText: verseText,
                                selectedBook: selectedBook,
                                selectedChapter: selectedChapter,
                                context: context,
                              );
                            }),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
