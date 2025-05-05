// lib/pages/bible_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
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
        selectedBook = 'gn'; // Livro inicial padrão
        selectedChapter = 1; // Capítulo inicial padrão
      });
    });
  }

  // <<< MODIFICAÇÃO MVP: Função para falar o capítulo baseado na lista de versos >>>
  Future<void> _speakChapter(List<String> verses) async {
    if (verses.isEmpty) return; // Não tenta falar se não houver versos
    String textToSpeak = verses.join(" ");
    await _flutterTts.stop(); // Para qualquer fala anterior
    await _flutterTts.speak(textToSpeak);
  }
  // <<< FIM MODIFICAÇÃO MVP >>>

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
                      showBibleRoutes = false;
                    });
                  },
                )
              : Padding(
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
                                  _flutterTts
                                      .stop(); // Para a fala ao mudar tradução
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
                              _flutterTts
                                  .stop(); // Para a fala ao mudar para rotas
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF272828),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
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
                                  selectedChapter =
                                      1; // Reset chapter on book change
                                });
                                _flutterTts
                                    .stop(); // Para a fala ao mudar livro
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
                                  _flutterTts
                                      .stop(); // Para a fala ao mudar capítulo
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedBook != null && selectedChapter != null)
                        Expanded(
                          // <<< MODIFICAÇÃO MVP: FutureBuilder para carregar Map<String, dynamic> >>>
                          child: FutureBuilder<Map<String, dynamic>>(
                            key: ValueKey(
                                '$selectedBook-$selectedChapter-$selectedTranslation'),
                            future: BiblePageHelper.loadChapterData(
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
                                return Center(
                                  child: Text(
                                    'Erro ao carregar dados do capítulo: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              } else if (!snapshot.hasData ||
                                  (snapshot.data?['verses'] as List?)
                                          ?.isEmpty ==
                                      true) {
                                // Verifica se há versos
                                return const Center(
                                  child: Text(
                                    'Capítulo não encontrado ou vazio.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                );
                              }

                              // Extrai dados
                              final chapterData = snapshot.data!;
                              final List<Map<String, dynamic>> sections =
                                  chapterData['sections'] ?? [];
                              final List<String> allVerses =
                                  chapterData['verses'] ?? [];

                              // <<< FIM MODIFICAÇÃO MVP >>>

                              return Column(
                                children: [
                                  // <<< MODIFICAÇÃO MVP: Botão para ouvir o capítulo >>>
                                  ElevatedButton.icon(
                                    onPressed: () => _speakChapter(
                                        allVerses), // Passa a lista de versos
                                    icon: const Icon(Icons.volume_up,
                                        color: Colors.white),
                                    label: const Text("Ouvir Capítulo",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF129575),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  // <<< FIM MODIFICAÇÃO MVP >>>
                                  const SizedBox(height: 16),
                                  Expanded(
                                    // <<< MODIFICAÇÃO MVP: Renderiza seções ou versos diretamente >>>
                                    child: ListView.builder(
                                      // Se houver seções, itera por elas. Senão, trata como 1 seção contendo todos os versos.
                                      itemCount: sections.isNotEmpty
                                          ? sections.length
                                          : 1,
                                      itemBuilder: (context, sectionIndex) {
                                        Widget sectionWidget;

                                        if (sections.isNotEmpty) {
                                          // Renderiza uma seção específica
                                          final section =
                                              sections[sectionIndex];
                                          final String sectionTitle =
                                              section['title'];
                                          final List<int> verseNumbers =
                                              section['verses'] ?? [];

                                          sectionWidget = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Título da Seção
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 16.0, bottom: 8.0),
                                                child: Text(
                                                  sectionTitle,
                                                  style: const TextStyle(
                                                    color: Color(
                                                        0xFFCDE7BE), // Cor de destaque
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              // Versículos da Seção
                                              ...verseNumbers
                                                  .map((verseNumber) {
                                                // Validação básica do índice do verso
                                                if (verseNumber > 0 &&
                                                    verseNumber <=
                                                        allVerses.length) {
                                                  final verseIndex =
                                                      verseNumber - 1;
                                                  final verseText =
                                                      allVerses[verseIndex];
                                                  return BiblePageWidgets
                                                      .buildVerseItem(
                                                    verseNumber: verseNumber,
                                                    verseText: verseText,
                                                    selectedBook: selectedBook,
                                                    selectedChapter:
                                                        selectedChapter,
                                                    context: context,
                                                  );
                                                } else {
                                                  // Caso o número do verso seja inválido
                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4.0),
                                                    child: Text(
                                                        'Erro: Verso $verseNumber inválido.',
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .redAccent)),
                                                  );
                                                }
                                              }).toList(),
                                            ],
                                          );
                                        } else {
                                          // Não há seções, renderiza todos os versos diretamente
                                          sectionWidget = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: List.generate(
                                                allVerses.length, (verseIndex) {
                                              final verseNumber =
                                                  verseIndex + 1;
                                              final verseText =
                                                  allVerses[verseIndex];
                                              return BiblePageWidgets
                                                  .buildVerseItem(
                                                verseNumber: verseNumber,
                                                verseText: verseText,
                                                selectedBook: selectedBook,
                                                selectedChapter:
                                                    selectedChapter,
                                                context: context,
                                              );
                                            }),
                                          );
                                        }

                                        return sectionWidget;
                                      },
                                    ),
                                    // <<< FIM MODIFICAÇÃO MVP >>>
                                  ),
                                ],
                              );
                            },
                          ),
                          // <<< FIM MODIFICAÇÃO MVP >>>
                        ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop(); // Garante que a fala pare ao sair da página
    super.dispose();
  }
}
