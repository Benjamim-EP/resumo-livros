import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class UtilsBiblePage {
  static Widget buildChapterDropdown({
    required int? selectedChapter,
    required Map<String, dynamic>? booksMap,
    required String? selectedBook,
    required Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedChapter,
          hint: const Text(
            'Capítulo',
            style: TextStyle(color: Colors.white),
          ),
          dropdownColor: const Color(0xFF272828),
          isExpanded: true,
          items: selectedBook != null && booksMap != null
              ? List.generate(
                  booksMap[selectedBook]['capitulos'] as int,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : [],
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }

  static Widget buildBookDropdown({
    required String? selectedBook,
    required Map<String, dynamic>? booksMap,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBook,
          hint: const Text(
            'Selecione um Livro',
            style: TextStyle(color: Colors.white),
          ),
          dropdownColor: const Color(0xFF272828),
          isExpanded: true,
          items: booksMap?.keys.map((abbrev) {
            final bookName = booksMap[abbrev]['nome'];
            return DropdownMenuItem<String>(
              value: abbrev,
              child: Text(
                bookName,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }

  /// Mostra os comentários de um versículo em um modal.
  static void showVerseComments({
    required BuildContext context,
    required Map<int, List<Map<String, dynamic>>> verseComments,
    required Map<String, dynamic>? booksMap,
    required String? selectedBook,
    required int? selectedChapter,
    required int verseNumber,
    required Future<List<String>> Function(String, int) loadChapterContent,
    required String Function(String, int) truncateString,
  }) async {
    final comments = verseComments[verseNumber] ?? [];
    final bookName = booksMap![selectedBook!]['nome'];
    final chapter = selectedChapter;

    // Carrega o conteúdo do capítulo para obter o texto do versículo
    List<String> chapterContent = [];
    try {
      chapterContent = await loadChapterContent(selectedBook, chapter!);
    } catch (e) {
      print("Erro ao carregar o capítulo para o versículo: $e");
    }

    // Obtém o texto do versículo com limite de 30 caracteres
    String verseSnippet = '';
    if (chapterContent.isNotEmpty && verseNumber - 1 < chapterContent.length) {
      final verseText = chapterContent[verseNumber - 1];
      verseSnippet = truncateString(verseText, 30);
    }

    final sortedComments = _sortCommentsByTags(comments, verseNumber);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF313333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return sortedComments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Nenhum comentário disponível.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalHeader(
                        bookName: bookName,
                        chapter: chapter,
                        verseNumber: verseNumber,
                        verseSnippet: verseSnippet,
                      ),
                      const Divider(height: 1, color: Colors.white24),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: _buildCommentsList(sortedComments),
                        ),
                      ),
                    ],
                  );
          },
        );
      },
    );
  }

  /// Mostra comentários gerais em um modal, exibindo o "topic" como título antes do conteúdo.
  static void showGeneralComments({
    required BuildContext context,
    required List<Map<String, dynamic>> comments,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF313333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.3,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return comments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Nenhum comentário disponível.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: comments.map((comment) {
                        final topic = comment['topico'] ?? 'Sem título';
                        final content = comment['content'] ?? '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: '## **$topic**\n\n$content',
                              styleSheet: MarkdownStyleSheet(
                                h2: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                p: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  );
          },
        );
      },
    );
  }

  /// Ordena comentários com base na relevância das tags.
  static List<Map<String, dynamic>> _sortCommentsByTags(
      List<Map<String, dynamic>> comments, int verseNumber) {
    final sortedComments = List<Map<String, dynamic>>.from(comments);
    sortedComments.sort((a, b) {
      final aTags = a['tags'] != null
          ? a['tags']
              .where(
                  (tag) => tag is Map<String, dynamic> && tag['verses'] != null)
              .expand((tag) => tag['verses'] as List)
              .cast<int>()
              .toList()
          : [];
      final bTags = b['tags'] != null
          ? b['tags']
              .where(
                  (tag) => tag is Map<String, dynamic> && tag['verses'] != null)
              .expand((tag) => tag['verses'] as List)
              .cast<int>()
              .toList()
          : [];

      final aStartsAtVerse = aTags.isNotEmpty && aTags.first == verseNumber;
      final bStartsAtVerse = bTags.isNotEmpty && bTags.first == verseNumber;

      if (aStartsAtVerse && !bStartsAtVerse) return -1;
      if (!aStartsAtVerse && bStartsAtVerse) return 1;
      return 0;
    });
    return sortedComments;
  }

  /// Constrói o cabeçalho do modal.
  static Widget _buildModalHeader({
    required String bookName,
    required int? chapter,
    required int verseNumber,
    required String verseSnippet,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFFCDE7BE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$bookName $chapter:$verseNumber',
            style: const TextStyle(
              color: Color(0xFF181A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            verseSnippet,
            style: const TextStyle(
              color: Color(0xFF181A1A),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de comentários, exibindo "topic" antes do conteúdo como um título Markdown.
  static Widget _buildCommentsList(List<Map<String, dynamic>> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: comments.asMap().entries.map((entry) {
        final index = entry.key;
        final comment = entry.value;
        final topic = comment['topico'] ??
            'Sem título'; // Se não houver "topic", usa um padrão.
        final content = comment['content'] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0)
              const Divider(color: Colors.white24, thickness: 1, height: 32),
            MarkdownBody(
              data:
                  '## **$topic**\n\n$content', // O topic agora é um título de nível 2 (h2)
              styleSheet: MarkdownStyleSheet(
                h2: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                p: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
