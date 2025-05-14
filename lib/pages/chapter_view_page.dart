import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/save_topic_dialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/sidebar_indicator.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/similar_topic_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/topic_cards.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    _markAsReading();
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

  Future<void> _markAsReading() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'reading_${widget.bookId}';

    if (prefs.getBool(key) == true) {
      return; // 🔹 Evita acessar o Firestore se já está salvo
    }

    StoreProvider.of<AppState>(context)
        .dispatch(MarkBookAsReadingAction(widget.bookId));
    await prefs.setBool(key, true);

    final userId = StoreProvider.of<AppState>(context).state.userState.userId;
    if (userId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('week_recomendation')
        .doc(widget.bookId);

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        // 🔹 Atualiza lista e conta de usuários lendo
        await docRef.update({
          'lendo': FieldValue.arrayUnion([userId]),
          'lendo_count': FieldValue.increment(1),
        });
      } else {
        // 🔹 Cria o documento se não existir
        await docRef.set({
          'lendo': [userId],
          'lendo_count': 1,
        });
      }
    } catch (e) {
      print("Erro ao atualizar Firestore: $e");
    }
  }
}
