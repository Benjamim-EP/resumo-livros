import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/save_topic_dialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/sidebar_indicator.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/similar_topic_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/topic_cards.dart';

class ChapterViewPage extends StatefulWidget {
  final List<dynamic> chapters;
  final int index;
  final String bookId;

  const ChapterViewPage({
    super.key,
    required this.chapters,
    required this.index,
    required this.bookId,
  });

  @override
  _ChapterViewPageState createState() => _ChapterViewPageState();
}

class _ChapterViewPageState extends State<ChapterViewPage> {
  int _currentTopicIndex = 0; // Índice do tópico atual
  final Set<String> _readTopics = {}; // Tópicos já marcados como lidos
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[widget.index];
    final topics = chapter['topicos'] as List<dynamic>? ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter['titulo'] ?? 'Sem título'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (page) {
              setState(() => _currentTopicIndex = page);
            },
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topicId = topics[index]['topicoId'];
              return Column(
                children: [
                  Expanded(
                    child: TopicCard(
                      topicId: topicId,
                      bookId: widget.bookId,
                      chapterId: chapter['capituloId'], // Passando o capituloId
                      readTopics: _readTopics,
                      onShowSimilar: (topicId) =>
                          _showSimilarTopics(context, topicId),
                      onSaveTopic: _showSaveDialog,
                    ),
                  ),
                ],
              );
            },
          ),
          SidebarIndicator(
            currentIndex: _currentTopicIndex,
            totalItems: topics.length,
          ),
        ],
      ),
    );
  }

  void _showSimilarTopics(BuildContext context, String topicId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF313333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SimilarTopicsView(topicId: topicId),
    );
  }

  void _showSaveDialog(String topicId) {
    showDialog(
      context: context,
      builder: (_) => SaveTopicDialog(topicId: topicId),
    );
  }
}
