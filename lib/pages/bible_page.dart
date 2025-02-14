import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

    _flutterTts.setLanguage("pt-BR"); // Define o idioma para português do Brasil
    _flutterTts.setSpeechRate(0.5);   // Define a velocidade da fala
    _flutterTts.setPitch(1.0);        // Define o tom da voz

    _loadBooksMap().then((_) {
      if (booksMap != null) {
        setState(() {
          selectedBook = 'gn'; 
          selectedChapter = 1;
        });

        _updateChapterData(); 
      }
    });
  }

  Future<void> _speakChapter(List<String> chapterContent) async {
    String textToSpeak = chapterContent.join(" "); // Junta os versículos em um único texto
    await _flutterTts.speak(textToSpeak); // Faz a leitura do capítulo
  }

  /// Atualiza o conteúdo e os comentários sempre que um novo livro ou capítulo for selecionado.
  void _updateChapterData() {
    if (selectedBook != null && selectedChapter != null) {
      setState(() {
        chapterComments.clear();
        verseComments.clear();
      });

      _loadChapterComments(booksMap![selectedBook!]['nome'], selectedChapter!);
    }
  }

  Future<void> _loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    setState(() {
      booksMap = json.decode(data);
    });
  }

  Future<List<String>> _loadChapterContent(
      String bookAbbrev, int chapter) async {
    try {
      final String data = await rootBundle.loadString(
        'assets/Biblia/completa_traducoes/$selectedTranslation/$bookAbbrev/$chapter.json',
      );
      return List<String>.from(json.decode(data));
    } catch (e) {
      print('Erro ao carregar o capítulo: $e');
      rethrow; // Para propagar o erro para o FutureBuilder
    }
  }

  Future<void> _loadChapterComments(String book, int chapter) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection("comentario")
        .where("livro", isEqualTo: book)
        .where("capitulo", isEqualTo: chapter.toString())
        .get();

    // Mapa de comentários por versículo
    Map<int, List<Map<String, dynamic>>> commentsMap = {};
    List<Map<String, dynamic>> chapterCommentsList = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      chapterCommentsList.add(data);

      // Verifica se 'tags' existe e é uma lista
      if (data['tags'] != null && data['tags'] is List) {
        for (var tag in data['tags']) {
          // Verifica se 'chapter' e 'verses' estão presentes
          if (tag is Map<String, dynamic> &&
              tag['chapter'] == chapter.toString() &&
              tag['verses'] != null &&
              tag['verses'] is List) {
            for (var verse in tag['verses']) {
              // Converte o número do versículo para inteiro
              final verseNumber = int.tryParse(verse.toString());
              if (verseNumber != null) {
                commentsMap.putIfAbsent(verseNumber, () => []).add(data);
              }
            }
          }
        }
      }
    }

    // Ordena os comentários pelo campo "topic_number" (convertido para inteiro)
    chapterCommentsList.sort((a, b) {
      final numA = int.tryParse(a['topic_number']?.toString() ?? '0') ?? 0;
      final numB = int.tryParse(b['topic_number']?.toString() ?? '0') ?? 0;
      return numA.compareTo(numB);
    });
    

    setState(() {
      chapterComments = chapterCommentsList;
      verseComments = commentsMap;
    });
  } catch (e) {
    print("Erro ao carregar comentários: $e");
  }
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
                        _showTranslationSelection();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF272828),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Escolher Tradução",
                        style: TextStyle(color: Colors.white),
                      ),
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
                        future: _loadChapterContent(selectedBook!, selectedChapter!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
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
                          
                          return Column(  // 🔹 Retorna um Column para incluir o botão + a Lista
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (chapterContent.isNotEmpty) {
                                    _speakChapter(chapterContent);
                                  }
                                },
                                icon: const Icon(Icons.volume_up, color: Colors.white),
                                label: const Text(
                                  "Ouvir Capítulo",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF129575),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded( // 🔹 Para evitar erro de tamanho na tela
                                child: ListView.builder(
                                  itemCount: chapterContent.length,
                                  itemBuilder: (context, index) {
                                    final verseNumber = index + 1;
                                    final verseText = chapterContent[index];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$verseNumber ',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              verseText,
                                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                                            ),
                                          ),
                                          if (verseComments.containsKey(verseNumber))
                                            IconButton(
                                              icon: const Icon(
                                                Icons.notes_rounded,
                                                color: Color(0xFFCDE7BE),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                UtilsBiblePage.showVerseComments(
                                                  context: context,
                                                  verseComments: verseComments,
                                                  booksMap: booksMap,
                                                  selectedBook: selectedBook,
                                                  selectedChapter: selectedChapter,
                                                  verseNumber: verseNumber,
                                                  loadChapterContent: _loadChapterContent,
                                                  truncateString: _truncateString,
                                                );
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.bookmark_border,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => SaveVerseDialog(
                                                  bookAbbrev: selectedBook!,
                                                  chapter: selectedChapter!,
                                                  verseNumber: verseNumber,
                                                ),
                                              );
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
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

  Widget _buildTranslationButton(
      String translationKey, String translationLabel) {
    final isSelected = selectedTranslation == translationKey;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedTranslation = translationKey;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFCDE7BE) : const Color(0xFF272828),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        translationLabel,
        style: TextStyle(
          color: isSelected ? const Color(0xFF181A1A) : Colors.white,
        ),
      ),
    );
  }

  String _truncateString(String text, int maxLength) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength)}...'
        : text;
  }

  void _showTranslationSelection() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF181A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Escolha a Tradução",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _buildTranslationButton('nvi', 'NVI'),
            _buildTranslationButton('aa', 'AA'),
            _buildTranslationButton('acf', 'ACF'),
          ],
        ),
      );
    },
  );
}
}
