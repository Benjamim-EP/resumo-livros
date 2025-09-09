// lib/pages/biblie_page/study_card_widget.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:percent_indicator/percent_indicator.dart';

class StudyCardWidget extends StatefulWidget {
  final String commentaryDocId;
  final VoidCallback onGenerateSummary; // Função para chamar o resumo

  const StudyCardWidget({
    super.key,
    required this.commentaryDocId,
    required this.onGenerateSummary,
  });

  @override
  State<StudyCardWidget> createState() => _StudyCardWidgetState();
}

class _StudyCardWidgetState extends State<StudyCardWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  // O Future agora vive no estado deste widget
  late Future<Map<String, dynamic>?> _commentaryFuture;

  // Controladores para o PageView e o progresso
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _commentaryFuture =
        _firestoreService.getSectionCommentary(widget.commentaryDocId);
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _commentaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: LinearProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final commentaryItems = (snapshot.data!['commentary'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];

        if (commentaryItems.isEmpty) {
          return const SizedBox.shrink();
        }

        // Extrai apenas os parágrafos que têm texto traduzido
        final paragraphs = commentaryItems
            .map((item) => (item['traducao'] as String?)?.trim() ?? '')
            .where((text) => text.isNotEmpty)
            .toList();

        if (paragraphs.isEmpty) {
          return const SizedBox.shrink();
        }

        final double progress = (paragraphs.length > 1)
            ? (_currentPage) / (paragraphs.length - 1)
            : 1.0;

        return Card(
          margin: const EdgeInsets.only(top: 20.0),
          elevation: 0,
          color: theme.colorScheme.surface.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              // --- CABEÇALHO ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Estudo da Seção", style: theme.textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: widget.onGenerateSummary,
                      icon: const Icon(Icons.bolt_outlined, size: 20),
                      label: const Text("Resumo"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- CARROSSEL DE PARÁGRAFOS ---
              SizedBox(
                height: 250, // Altura fixa para o conteúdo
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: paragraphs.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        paragraphs[index],
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        textAlign: TextAlign.justify,
                      ),
                    );
                  },
                ),
              ),

              // --- BARRA DE PROGRESSO E NAVEGAÇÃO ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "${_currentPage + 1} de ${paragraphs.length}",
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          LinearPercentIndicator(
                            percent: progress,
                            lineHeight: 5.0,
                            barRadius: const Radius.circular(5),
                            padding: EdgeInsets.zero,
                            backgroundColor:
                                theme.dividerColor.withOpacity(0.2),
                            progressColor: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < paragraphs.length - 1
                          ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
