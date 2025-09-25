// lib/pages/library_page/book_study_guide_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

// Modelo para os dados do guia de estudo
class ChapterGuide {
  final String title;
  final List<dynamic> topics;
  ChapterGuide({required this.title, required this.topics});
}

class BookStudyGuidePage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const BookStudyGuidePage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<BookStudyGuidePage> createState() => _BookStudyGuidePageState();
}

class _BookStudyGuidePageState extends State<BookStudyGuidePage> {
  late Future<List<ChapterGuide>> _guideFuture;
  String? _amazonLink;

  @override
  void initState() {
    super.initState();
    _guideFuture = _fetchStudyGuide();
  }

  Future<List<ChapterGuide>> _fetchStudyGuide() async {
    final firestore = FirebaseFirestore.instance;

    final bookDoc =
        await firestore.collection('bookStudyGuides').doc(widget.bookId).get();
    if (bookDoc.exists && mounted) {
      setState(() {
        _amazonLink = bookDoc.data()?['amazonLink'];
      });
    }

    final snapshot = await firestore
        .collection('bookStudyGuides')
        .doc(widget.bookId)
        .collection('chapters')
        .orderBy(FieldPath.documentId)
        .get();

    return snapshot.docs.map((doc) {
      return ChapterGuide(
        title: doc.data()['chapterTitle'] ?? 'Capítulo Desconhecido',
        topics: doc.data()['topics'] ?? [],
      );
    }).toList();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Tratar erro se necessário
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (_amazonLink != null && _amazonLink!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text("Comprar"),
                onPressed: () => _launchURL(_amazonLink!),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            )
        ],
      ),
      body: FutureBuilder<List<ChapterGuide>>(
        future: _guideFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Guia de estudo não encontrado."));
          }

          final chapters = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: chapters.length + 1, // +1 para o disclaimer
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildDisclaimer(context);
              }
              final chapter = chapters[index - 1];
              // ✅ O CARD EXTERNO É O ExpansionTile, como antes
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: PageStorageKey(chapter.title),
                  title: Text(chapter.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.fromLTRB(
                      8, 0, 8, 16), // Padding interno do ExpansionTile
                  // ✅ CADA TÓPICO DENTRO DO ExpansionTile AGORA É UM CARD
                  children: chapter.topics.asMap().entries.map<Widget>((entry) {
                    int idx = entry.key;
                    var topic = entry.value;

                    final topicTitle = topic['title'] ?? '';
                    final keyPoints =
                        List<String>.from(topic['keyPoints'] ?? []);

                    return Card(
                      elevation: 2,
                      color: theme.cardColor
                          .withOpacity(0.5), // Cor sutil para diferenciar
                      margin: const EdgeInsets.only(top: 12.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topicTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            ...keyPoints.map((point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 2.0, right: 12.0),
                                        child: Icon(Icons.lightbulb_outline,
                                            size: 18,
                                            color: theme.colorScheme.secondary),
                                      ),
                                      Expanded(
                                        child: Text(point,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(height: 1.5)),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: (100 * idx).ms);
                  }).toList(),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (100 * (index - 1)).ms)
                  .slideY(begin: 0.2);
            },
          );
        },
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor)),
      child: Text(
        "Este é um guia de estudo e resumo. Para uma experiência completa, recomendamos a leitura da obra original.",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
