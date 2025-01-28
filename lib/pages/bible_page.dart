import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBooksMap().then((_) {
      if (booksMap != null) {
        // Define Gênesis e capítulo 1 como padrão
        setState(() {
          selectedBook =
              'gn'; // Abreviação de Gênesis (ajuste de acordo com seu JSON)
          selectedChapter = 1;
        });
        // Carrega o conteúdo do primeiro capítulo
        _loadChapterContent(selectedBook!, selectedChapter!).catchError((e) {
          print("Erro ao carregar o capítulo inicial: $e");
        });
        // Carrega os comentários do primeiro capítulo
        _loadChapterComments(
            booksMap![selectedBook!]['nome'], selectedChapter!);
      }
    });
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

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

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
      setState(() {
        chapterComments = querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botões de Tradução
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTranslationButton('nvi', 'NVI'),
                      _buildTranslationButton('aa', 'AA'),
                      _buildTranslationButton('acf', 'ACF'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dropdowns para seleção de livro e capítulo
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
                                  1; // Define o capítulo padrão como 1
                            });
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
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botão para abrir os comentários gerais do capítulo
                  if (selectedBook != null && selectedChapter != null)
                    ElevatedButton(
                      onPressed: () {
                        _loadChapterComments(
                          booksMap![selectedBook!]['nome'],
                          selectedChapter!,
                        );
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

                  // Carrega o conteúdo do capítulo selecionado
                  if (selectedBook != null && selectedChapter != null)
                    Expanded(
                      child: FutureBuilder<List<String>>(
                        future: _loadChapterContent(
                          selectedBook!,
                          selectedChapter!,
                        ),
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
                          return ListView.builder(
                            itemCount: chapterContent.length,
                            itemBuilder: (context, index) {
                              final verseNumber = index + 1;
                              final verseText = chapterContent[index];

                              // Mostra o botão apenas se houver comentários associados ao versículo
                              return ListTile(
                                leading: Text(
                                  '$verseNumber',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                title: Text(
                                  verseText,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: verseComments.containsKey(verseNumber)
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.notes_rounded,
                                          color: Color(0xFFCDE7BE),
                                        ),
                                        onPressed: () {
                                          UtilsBiblePage.showVerseComments(
                                            context: context,
                                            verseComments: verseComments,
                                            booksMap: booksMap,
                                            selectedBook: selectedBook,
                                            selectedChapter: selectedChapter,
                                            verseNumber: verseNumber,
                                            loadChapterContent:
                                                _loadChapterContent,
                                            truncateString: _truncateString,
                                          );
                                        },
                                      )
                                    : null,
                              );
                            },
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
}
