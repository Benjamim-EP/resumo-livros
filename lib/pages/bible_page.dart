import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes_widget.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
// REMOVIDO: Importação de shared_preferences (se ainda existia para comentários do usuário)
// import 'package:shared_preferences/shared_preferences.dart';

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

  // REMOVIDO: Variáveis de estado dos comentários
  // List<Map<String, dynamic>> chapterComments = [];
  // Map<int, List<Map<String, dynamic>>> verseComments = {};

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
        selectedBook = 'gn'; // Livro inicial padrão
        selectedChapter = 1; // Capítulo inicial padrão
      });
      // REMOVIDO: Chamada para _updateChapterData()
    });
  }

  Future<void> _speakChapter(List<String> chapterContent) async {
    String textToSpeak = chapterContent.join(" ");
    await _flutterTts.speak(textToSpeak);
  }

  // REMOVIDO: Função _updateChapterData() inteira

  // REMOVIDO: Função _loadBooksMap() (já estava no helper)

  // REMOVIDO: Funções _saveUserComment, _loadUserComments, _showUserCommentDialog, _showUserComments

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
                                // REMOVIDO: Chamada para _updateChapterData()
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
                                  // REMOVIDO: Chamada para _updateChapterData()
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // REMOVIDO: Botão "Ver Comentários do Capítulo"
                      // const SizedBox(height: 16), // Removido espaçamento extra
                      if (selectedBook != null && selectedChapter != null)
                        Expanded(
                          child: FutureBuilder<List<String>>(
                            // Chave para forçar rebuild ao mudar livro/capítulo/tradução
                            key: ValueKey(
                                '$selectedBook-$selectedChapter-$selectedTranslation'),
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
                                return Center(
                                  child: Text(
                                    'Erro ao carregar capítulo: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Capítulo não encontrado ou vazio.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                );
                              }

                              final chapterContent = snapshot.data!;

                              return Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (chapterContent.isNotEmpty) {
                                        _speakChapter(chapterContent);
                                      }
                                    },
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
                                      itemCount: chapterContent.length,
                                      itemBuilder: (context, index) {
                                        final verseNumber = index + 1;
                                        final verseText = chapterContent[index];

                                        // Chamada simplificada para buildVerseItem
                                        return BiblePageWidgets.buildVerseItem(
                                          verseNumber: verseNumber,
                                          verseText: verseText,
                                          // REMOVIDO: verseComments
                                          selectedBook: selectedBook,
                                          selectedChapter: selectedChapter,
                                          context: context,
                                          // REMOVIDO: onAddUserComment
                                          // REMOVIDO: onViewUserComments
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
