// lib/pages/library_page/generic_book_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/services/firestore_service.dart';

class GenericBookViewerPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const GenericBookViewerPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<GenericBookViewerPage> createState() => _GenericBookViewerPageState();
}

class _GenericBookViewerPageState extends State<GenericBookViewerPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Map<String, dynamic>>> _chaptersFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Inicia a busca pelos capítulos no Firestore
    _chaptersFuture = _firestoreService.getBookChapters(widget.bookId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
                child: Text("Não foi possível carregar os capítulos."));
          }

          final chapters = snapshot.data!;
          return PageView.builder(
            controller: _pageController,
            itemCount: chapters.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final title = chapter['title'] ?? 'Capítulo';
              final paragraphs = List<String>.from(chapter['paragraphs'] ?? []);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineSmall),
                    const Divider(height: 24),
                    ...paragraphs.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(p,
                              style: theme.textTheme.bodyLarge,
                              textAlign: TextAlign.justify),
                        )),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<Map<String, dynamic>>>(
          future: _chaptersFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const SizedBox.shrink();
            final totalChapters = snapshot.data!.length;
            return BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn)
                        : null,
                  ),
                  Text('Capítulo ${_currentPage + 1} de $totalChapters'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < totalChapters - 1
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn)
                        : null,
                  ),
                ],
              ),
            );
          }),
    );
  }
}
