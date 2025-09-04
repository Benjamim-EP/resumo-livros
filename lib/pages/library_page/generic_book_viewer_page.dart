// lib/pages/library_page/generic_book_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';

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
  PageController? _pageController;
  int _currentPage = 0;
  bool _isLoadingLastPage = true;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _firestoreService.getBookChapters(widget.bookId);
    _loadLastReadPage();
  }

  Future<void> _loadLastReadPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page_${widget.bookId}') ?? 0;
    setState(() {
      _currentPage = lastPage;
      _pageController = PageController(initialPage: lastPage);
      _isLoadingLastPage = false;
    });
  }

  Future<void> _saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.bookId}', page);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _showChaptersIndex(
      BuildContext context, List<Map<String, dynamic>> chapters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Capítulos',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final title =
                            chapter['title'] ?? 'Capítulo ${index + 1}';
                        return ListTile(
                          title: Text(title),
                          trailing: _currentPage == index
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                          onTap: () {
                            _pageController?.jumpToPage(index);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingLastPage) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.bookTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      // ✅✅✅ A LÓGICA AGORA FICA DENTRO DE UMA COLUMN ✅✅✅
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("Não foi possível carregar os capítulos."));
          }

          final chapters = snapshot.data!;
          final totalChapters = chapters.length;
          final double progress =
              totalChapters > 1 ? (_currentPage + 1) / totalChapters : 1.0;

          return Column(
            children: [
              // 1. BARRA DE PROGRESSO (AGORA NO CORPO, NÃO NA BOTTOMBAR)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LinearPercentIndicator(
                  percent: progress,
                  lineHeight: 5.0,
                  barRadius: const Radius.circular(5),
                  padding: EdgeInsets.zero,
                  backgroundColor: theme.dividerColor.withOpacity(0.2),
                  progressColor: theme.colorScheme.primary,
                  animateFromLastPercent: true,
                  animation: true,
                ),
              ),
              // 2. PageView OCUPA O RESTANTE DO ESPAÇO
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalChapters,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _saveCurrentPage(index);
                  },
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final title = chapter['title'] ?? 'Capítulo';
                    final paragraphs =
                        List<String>.from(chapter['paragraphs'] ?? []);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...paragraphs.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  p,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              )),
                          const SizedBox(height: 80),
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
      // ✅✅✅ BOTTOM APP BAR SIMPLIFICADA ✅✅✅
      bottomNavigationBar: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final totalChapters = snapshot.data!.length;

          return BottomAppBar(
            elevation: 8,
            // Usamos um SizedBox para garantir uma altura fixa e evitar overflow
            child: SizedBox(
              height: 56.0, // Altura padrão de uma barra de navegação
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0
                        ? () => _pageController?.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.list_rounded, size: 20),
                    label:
                        Text('Capítulo ${_currentPage + 1} de $totalChapters'),
                    onPressed: () =>
                        _showChaptersIndex(context, snapshot.data!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < totalChapters - 1
                        ? () => _pageController?.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
