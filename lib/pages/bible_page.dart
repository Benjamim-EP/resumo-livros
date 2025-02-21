import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  Map<String, dynamic>? booksMap; // Mapeamento dos livros da Bíblia
  String? selectedBook; // Livro selecionado
  int? selectedChapter; // Capítulo selecionado
  String selectedTranslation = 'nvi'; // Tradução selecionada, padrão "nvi"

  List<Map<String, dynamic>> chapterComments = []; // Comentários carregados
  Map<int, List<Map<String, dynamic>>> verseComments =
      {}; // Comentários por versículo
  bool showBibleRoutes = false; // Variável para controlar a exibição
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);

    BiblePageHelper.loadBooksMap().then((map) {
      setState(() {
        booksMap = map;
        selectedBook = 'gn';
        selectedChapter = 1;
      });

      _updateChapterData();
    });
  }

  Future<void> _speakChapter(List<String> chapterContent) async {
    String textToSpeak =
        chapterContent.join(" "); // Junta os versículos em um único texto
    await _flutterTts.speak(textToSpeak); // Faz a leitura do capítulo
  }

  /// Atualiza o conteúdo e os comentários sempre que um novo livro ou capítulo for selecionado.
  void _updateChapterData() {
    if (selectedBook != null && selectedChapter != null) {
      setState(() {
        chapterComments.clear();
        verseComments.clear();
      });

      BiblePageHelper.loadChapterComments(
              booksMap![selectedBook!]['nome'], selectedChapter!)
          .then((data) {
        setState(() {
          chapterComments = data['chapterComments'];
          verseComments = data['verseComments'];
        });
      });
    }
  }

  Future<void> _loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    setState(() {
      booksMap = json.decode(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia'),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: booksMap == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFCDE7BE),
              ),
            )
          : showBibleRoutes
              ? BibleRoutesWidget(
                  onBack: () {
                    setState(() {
                      showBibleRoutes = false; // Volta para a tela principal
                    });
                  },
                )
              : Padding(
                  // Mantém o conteúdo original da tela principal
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              BiblePageWidgets.showTranslationSelection(
                                context: context,
                                selectedTranslation: selectedTranslation,
                                onTranslationSelected: (value) {
                                  setState(() {
                                    selectedTranslation = value;
                                  });
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF272828),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Escolher Tradução",
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                showBibleRoutes = !showBibleRoutes;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF272828),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              showBibleRoutes ? "Voltar" : "Rotas da Bíblia",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: UtilsBiblePage.buildBookDropdown(
                              selectedBook: selectedBook,
                              booksMap: booksMap,
                              onChanged: (value) {
                                setState(() {
                                  selectedBook = value;
                                  selectedChapter = 1;
                                });
                                _updateChapterData();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (selectedBook != null)
                            Expanded(
                              child: UtilsBiblePage.buildChapterDropdown(
                                selectedChapter: selectedChapter,
                                booksMap: booksMap,
                                selectedBook: selectedBook,
                                onChanged: (value) {
                                  setState(() {
                                    selectedChapter = value;
                                  });
                                  _updateChapterData();
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedBook != null && selectedChapter != null)
                        ElevatedButton(
                          onPressed: () {
                            UtilsBiblePage.showGeneralComments(
                              context: context,
                              comments: chapterComments,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCDE7BE),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            "Ver Comentários do Capítulo",
                            style: TextStyle(color: Color(0xFF181A1A)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (selectedBook != null && selectedChapter != null)
                        Expanded(
                          child: FutureBuilder<List<String>>(
                            future: BiblePageHelper.loadChapterContent(
                                selectedBook!,
                                selectedChapter!,
                                selectedTranslation),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFCDE7BE),
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'Erro ao carregar o capítulo.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final chapterContent = snapshot.data!;

                              return Column(
                                // 🔹 Retorna um Column para incluir o botão + a Lista
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (chapterContent.isNotEmpty) {
                                        _speakChapter(chapterContent);
                                      }
                                    },
                                    icon: const Icon(Icons.volume_up,
                                        color: Colors.white),
                                    label: const Text(
                                      "Ouvir Capítulo",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF129575),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    // 🔹 Para evitar erro de tamanho na tela
                                    child: ListView.builder(
                                      itemCount: chapterContent.length,
                                      itemBuilder: (context, index) {
                                        final verseNumber = index + 1;
                                        final verseText = chapterContent[index];

                                        return BiblePageWidgets.buildVerseItem(
                                          verseNumber: verseNumber,
                                          verseText: verseText,
                                          verseComments: verseComments,
                                          selectedBook: selectedBook,
                                          selectedChapter: selectedChapter,
                                          selectedTranslation:
                                              selectedTranslation,
                                          context: context,
                                          booksMap: booksMap,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
