// lib/pages/bible_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_item_widget.dart'; // <<< NOVO IMPORT

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
  String? _selectedBookSlug;

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
        _updateSelectedBookSlug();
      });
    });
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
                    _flutterTts.stop();
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
                                  _flutterTts.stop();
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
                              _flutterTts.stop();
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
                                style: const TextStyle(color: Colors.white)),
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
                                  _updateSelectedBookSlug(); // <<< NOVO: Atualiza o slug >>>
                                });
                                _flutterTts.stop();
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
                                  _flutterTts.stop();
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedBook != null &&
                          selectedChapter != null &&
                          _selectedBookSlug !=
                              null) // <<< Verifique _selectedBookSlug
                        Expanded(
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
                                        color: Color(0xFFCDE7BE)));
                              } else if (snapshot.hasError) {
                                return Center(
                                    child: Text(
                                        'Erro ao carregar dados do capítulo: ${snapshot.error}',
                                        style: const TextStyle(
                                            color: Colors.red)));
                              } else if (!snapshot.hasData ||
                                  (snapshot.data?['verses'] as List?)
                                          ?.isEmpty ==
                                      true) {
                                return const Center(
                                    child: Text(
                                        'Capítulo não encontrado ou vazio.',
                                        style:
                                            TextStyle(color: Colors.white70)));
                              }

                              final chapterData = snapshot.data!;
                              final List<Map<String, dynamic>> sections =
                                  chapterData['sections'] ?? [];
                              final List<String> allVerses =
                                  chapterData['verses'] ?? [];

                              return Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _speakChapter(allVerses),
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
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: sections.isNotEmpty
                                          ? sections.length
                                          : (allVerses.isNotEmpty
                                              ? 1
                                              : 0), // Se não há seções mas há versos, renderiza 1 item
                                      itemBuilder: (context, sectionIndex) {
                                        if (sections.isNotEmpty) {
                                          final section =
                                              sections[sectionIndex];
                                          final String sectionTitle =
                                              section['title'] ?? 'Seção';
                                          final List<int> verseNumbers =
                                              section['verses']?.cast<int>() ??
                                                  [];

                                          // <<< NOVO: Gerar verses_range_str para o ID do Firestore >>>
                                          String versesRangeStr = "";
                                          if (verseNumbers.isNotEmpty) {
                                            verseNumbers
                                                .sort(); // Garante que estão em ordem
                                            if (verseNumbers.length == 1) {
                                              versesRangeStr =
                                                  verseNumbers.first.toString();
                                            } else {
                                              // Verifica se são sequenciais para formar "inicio-fim"
                                              bool sequential = true;
                                              for (int i = 0;
                                                  i < verseNumbers.length - 1;
                                                  i++) {
                                                if (verseNumbers[i + 1] !=
                                                    verseNumbers[i] + 1) {
                                                  sequential = false;
                                                  break;
                                                }
                                              }
                                              if (sequential) {
                                                versesRangeStr =
                                                    "${verseNumbers.first}-${verseNumbers.last}";
                                              } else {
                                                // Se não sequencial, junta com vírgula (ou outra lógica se preferir)
                                                // Para o ID do Firestore, "1-5" é mais comum que "1,2,3,4,5"
                                                // Você pode precisar ajustar isso se o ID do Firestore não seguir um padrão simples para não sequenciais.
                                                // Por ora, vamos assumir que o JSON de blocos sempre terá um range contínuo para simplificar.
                                                // Se não, você precisará de uma lógica mais robusta aqui para gerar o verses_range_str
                                                // que corresponda ao seu ID no Firestore.
                                                // Para o exemplo "genesis_c5_v1-5", o JSON de blocos DEVE ter [1,2,3,4,5]
                                                // e não, por exemplo, [1,3,5] se o ID for "1-5".
                                                // Se o JSON de blocos tem [1,3,5] e o ID no Firestore é "1,3,5",
                                                // então versesRangeStr = verseNumbers.join(',');
                                                versesRangeStr =
                                                    "${verseNumbers.first}-${verseNumbers.last}"; // Simplificando por ora
                                              }
                                            }
                                          }
                                          // <<< FIM NOVO >>>

                                          return SectionItemWidget(
                                            sectionTitle: sectionTitle,
                                            verseNumbersInSection: verseNumbers,
                                            allVerseTextsInChapter: allVerses,
                                            bookSlug:
                                                _selectedBookSlug!, // Passa o slug
                                            bookAbbrev:
                                                selectedBook!, // Passa o abbrev
                                            chapterNumber: selectedChapter!,
                                            versesRangeStr:
                                                versesRangeStr, // Passa o range
                                          );
                                        } else if (allVerses.isNotEmpty) {
                                          // Não há seções definidas localmente, renderiza todos os versos como uma única seção "implícita"
                                          // Neste caso, não teremos um comentário de "seção" do Firestore,
                                          // a menos que você tenha um comentário para o capítulo inteiro.
                                          return Column(
                                            // Apenas para agrupar os versos se não houver seções
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
                                        return const SizedBox
                                            .shrink(); // Caso não haja seções nem versos
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

  @override
  void dispose() {
    _flutterTts.stop(); // Garante que a fala pare ao sair da página
    super.dispose();
  }
}
