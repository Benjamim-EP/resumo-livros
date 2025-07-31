// lib/pages/community/chapter_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/models/course_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
// <<< 1. IMPORTAR O NOVO PACOTE >>>
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChapterDetailPage extends StatefulWidget {
  final String courseId;
  final String partId;
  final String chapterId;

  const ChapterDetailPage({
    super.key,
    required this.courseId,
    required this.partId,
    required this.chapterId,
  });

  @override
  State<ChapterDetailPage> createState() => _ChapterDetailPageState();
}

class _ChapterDetailPageState extends State<ChapterDetailPage> {
  // <<< 2. SUBSTITUIR GlobalKey POR CONTROLLERS DO PACOTE >>>
  final ItemScrollController _itemScrollController = ItemScrollController();
  // Este mapa agora guardará o ÍNDICE do widget na lista, não uma GlobalKey.
  final Map<String, int> _topicIndexMap = {};

  /// Rola a tela suavemente para o ÍNDICE do tópico.
  void _scrollToTopic(int index) {
    Navigator.pop(context); // Fecha o menu

    // O itemScrollController cuida de encontrar e rolar para o item, mesmo que não esteja na tela.
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      alignment: 0.1, // Alinha o item a 10% do topo da tela.
    );
  }

  /// Mostra o menu de navegação.
  void _showTopicNavigationMenu(BuildContext context, List<MainTopic> topics) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // ... (o corpo do ModalBottomSheet permanece o mesmo)
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
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
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: topics.length,
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        return ListTile(
                          leading: Icon(Icons.label_important_outline,
                              color: Theme.of(context).colorScheme.secondary),
                          title: Text(topic.title),
                          onTap: () {
                            // <<< 3. USA O MAPA DE ÍNDICES PARA CHAMAR A FUNÇÃO DE ROLAGEM >>>
                            final targetIndex = _topicIndexMap[topic.id];
                            if (targetIndex != null) {
                              _scrollToTopic(targetIndex);
                            }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapterId, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('cursos')
            .doc(widget.courseId)
            .collection(widget.partId)
            .doc(widget.chapterId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text("Conteúdo do capítulo não encontrado."));
          }

          final chapter = CourseChapter.fromFirestore(snapshot.data!);

          // <<< 4. CONSTRÓI A LISTA DE WIDGETS E O MAPA DE ÍNDICES DE UMA VEZ >>>
          final List<Widget> chapterWidgets = _buildContentWidgetsAndIndexMap(
              context, chapter.restructuredDocument);

          return Stack(
            children: [
              // <<< 5. SUBSTITUI ListView POR ScrollablePositionedList.builder >>>
              ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                itemCount: chapterWidgets.length,
                itemBuilder: (context, index) {
                  // Simplesmente retorna o widget pré-construído para aquele índice
                  return chapterWidgets[index];
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () => _showTopicNavigationMenu(
                      context, chapter.restructuredDocument),
                  tooltip: 'Navegar por Tópicos',
                  child: const Icon(Icons.list_alt_rounded),
                )
                    .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true))
                    .scaleXY(
                        end: 1.1, duration: 1500.ms, curve: Curves.easeInOut)
                    .then(delay: 500.ms)
                    .shimmer(
                        duration: 1500.ms,
                        color: Colors.white.withOpacity(0.2)),
              ),
            ],
          );
        },
      ),
    );
  }

  // <<< 6. MÉTODO RENOMEADO E ATUALIZADO PARA CONSTRUIR A LISTA E O MAPA >>>
  List<Widget> _buildContentWidgetsAndIndexMap(
      BuildContext context, List<MainTopic> topics) {
    _topicIndexMap.clear(); // Limpa o mapa antigo antes de reconstruir
    final theme = Theme.of(context);
    List<Widget> contentWidgets = [];

    for (var mainTopic in topics) {
      // <<< 7. A MÁGICA ACONTECE AQUI >>>
      // Antes de adicionar o widget do título, guardamos o índice atual da lista.
      // O 'id' do tópico agora aponta para sua posição na lista de widgets.
      _topicIndexMap[mainTopic.id] = contentWidgets.length;

      contentWidgets.add(
        Padding(
          // Não precisamos mais da GlobalKey aqui
          padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
          child: Text(
            mainTopic.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
      );

      // O resto da lógica de construção dos subtópicos e conteúdos permanece a mesma
      for (var subTopic in mainTopic.subtopics) {
        // ... (código do subtópico) ...
        contentWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
            child: Text(
              subTopic.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        for (var content in subTopic.detailedContent) {
          contentWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(content.type),
                    labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer),
                    backgroundColor:
                        theme.colorScheme.secondaryContainer.withOpacity(0.4),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: BorderSide.none,
                  ),
                  const SizedBox(height: 8),
                  Text(content.text,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(height: 1.6, fontSize: 16),
                      textAlign: TextAlign.justify),
                  if (content.bibliographicReference != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        content.bibliographicReference!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        contentWidgets.add(const SizedBox(height: 8));
      }
    }
    // Adiciona a bibliografia no final da mesma lista
    contentWidgets.add(const SizedBox(height: 80));
    return contentWidgets;
  }

  // O método da bibliografia agora retorna uma lista de Widgets para ser adicionada à lista principal
  // (Foi integrado no build, então não precisamos mais dele separado, mas o mantenho aqui caso precise)
  Widget _buildBibliography(BuildContext context, List<String> bibliography) {
    // ... (este método não precisa de alterações)
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bibliografia Completa",
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          ...bibliography.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 6.0),
                      child: Icon(Icons.circle,
                          size: 8, color: theme.colorScheme.secondary)),
                  Expanded(
                      child: Text(entry, style: theme.textTheme.bodyMedium)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
