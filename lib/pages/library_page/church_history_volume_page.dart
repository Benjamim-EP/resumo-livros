// lib/pages/library_page/church_history_volume_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/church_history_model.dart'; // Importa o modelo

class ChurchHistoryVolumePage extends StatefulWidget {
  final ChurchHistoryVolume volume;

  const ChurchHistoryVolumePage({super.key, required this.volume});

  @override
  State<ChurchHistoryVolumePage> createState() =>
      _ChurchHistoryVolumePageState();
}

class _ChurchHistoryVolumePageState extends State<ChurchHistoryVolumePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapter = widget.volume.chapters[_currentPage];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.volume.title, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Índice de Capítulos",
            onPressed: () => _showChapterIndex(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.volume.chapters.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final currentChapter = widget.volume.chapters[index];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentChapter.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(color: theme.dividerColor, height: 24),
                ...currentChapter.content.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color:
                            theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: theme.scaffoldBackgroundColor,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _currentPage > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    : null,
              ),
              Text(
                'Capítulo ${_currentPage + 1} de ${widget.volume.chapters.length}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentPage < widget.volume.chapters.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterIndex(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return ListView.builder(
          itemCount: widget.volume.chapters.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                '${index + 1}. ${widget.volume.chapters[index].title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _pageController.jumpToPage(index);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
