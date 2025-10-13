// lib/pages/biblie_page/study_card_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/utils/text_span_utils.dart'; // <<< IMPORTANTE
import 'package:percent_indicator/percent_indicator.dart';

class StudyCardWidget extends StatefulWidget {
  final String commentaryDocId;
  final VoidCallback onGenerateSummary;
  // --- NOVOS PARÂMETROS ---
  final bool isPremium;
  final List<String> allUserTags;
  final String bookAbbrev;
  final String bookName;
  final int chapterNumber;
  final String sectionIdForHighlights;
  final String sectionTitle;
  final String versesRangeStr;

  const StudyCardWidget({
    super.key,
    required this.commentaryDocId,
    required this.onGenerateSummary,
    required this.isPremium,
    required this.allUserTags,
    required this.bookAbbrev,
    required this.bookName,
    required this.chapterNumber,
    required this.sectionIdForHighlights,
    required this.sectionTitle,
    required this.versesRangeStr,
  });

  @override
  State<StudyCardWidget> createState() => _StudyCardWidgetState();
}

class _StudyCardWidgetState extends State<StudyCardWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<Map<String, dynamic>?> _commentaryFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _commentaryFuture =
        _firestoreService.getSectionCommentary(widget.commentaryDocId);
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() => _currentPage = _pageController.page!.round());
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- FUNÇÕES DE DESTAQUE E REFERÊNCIA (REINTRODUZIDAS AQUI) ---

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'A marcação de trechos na biblioteca é exclusiva para assinantes Premium.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  void _handleHighlight(
      String fullParagraph, EditableTextState editableTextState) async {
    editableTextState.hideToolbar();

    // A funcionalidade de destaque em si é gratuita, conforme solicitado.
    // A verificação `isPremium` pode ser usada para funcionalidades futuras se necessário.
    // if (!widget.isPremium) {
    //   _showPremiumRequiredDialog();
    //   return;
    // }

    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;

    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#FFA07A",
        initialTags: const [],
        allUserTags: widget.allUserTags,
      ),
    );

    if (result == null || result.shouldRemove || result.colorHex == null)
      return;

    final store = StoreProvider.of<AppState>(context, listen: false);
    final highlightData = {
      'selectedSnippet': selectedSnippet,
      'fullContext': fullParagraph,
      'bookAbbrev': widget.bookAbbrev,
      'bookName': widget.bookName,
      'chapterNumber': widget.chapterNumber,
      'sectionId': widget.sectionIdForHighlights,
      'sectionTitle': widget.sectionTitle,
      'verseReferenceText':
          "${widget.bookName} ${widget.chapterNumber}:${widget.versesRangeStr} (Comentário)",
      'sourceType': 'bible_commentary',
      'color': result.colorHex,
      'tags': result.tags,
    };

    store.dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Destaque salvo!")));
  }

  List<TextSpan> _buildHighlightedParagraph(
      String originalParagraph,
      List<TextSpan> spansWithLinks,
      List<Map<String, dynamic>> highlights,
      ThemeData theme) {
    if (highlights.isEmpty) return spansWithLinks;

    List<Map<String, dynamic>> snippetsInParagraph = [];
    for (var highlight in highlights) {
      String snippet = highlight['selectedSnippet'] ?? '';
      if (snippet.isEmpty) continue;
      int startIndex = 0;
      while (startIndex < originalParagraph.length) {
        int pos = originalParagraph.indexOf(snippet, startIndex);
        if (pos == -1) break;
        snippetsInParagraph.add({
          'start': pos,
          'end': pos + snippet.length,
          'color': highlight['color'] as String? ?? '#FFA07A'
        });
        startIndex = pos + snippet.length;
      }
    }
    if (snippetsInParagraph.isEmpty) return spansWithLinks;
    snippetsInParagraph.sort((a, b) => a['start'].compareTo(b['start']));

    final List<TextSpan> finalSpans = [];
    int charIndex = 0;
    for (final span in spansWithLinks) {
      final text = span.text;
      if (text == null || text.isEmpty) {
        finalSpans.add(span);
        continue;
      }
      final spanStart = charIndex;
      final spanEnd = charIndex + text.length;
      charIndex = spanEnd;
      Color? backgroundColor;
      for (final highlight in snippetsInParagraph) {
        if (spanStart < highlight['end'] && spanEnd > highlight['start']) {
          backgroundColor = Color(int.parse(
                  (highlight['color'] as String).replaceFirst('#', '0xff')))
              .withOpacity(0.35);
          break;
        }
      }
      finalSpans.add(TextSpan(
        text: text,
        style: span.style?.copyWith(backgroundColor: backgroundColor) ??
            TextStyle(backgroundColor: backgroundColor),
        recognizer: span.recognizer,
      ));
    }
    return finalSpans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, List<Map<String, dynamic>>>(
      converter: (store) => store.state.userState.userCommentHighlights
          .where((h) => h['sectionId'] == widget.sectionIdForHighlights)
          .toList(),
      builder: (context, highlights) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _commentaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: LinearProgressIndicator());
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
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Estudo da Seção",
                            style: theme.textTheme.titleMedium),
                        TextButton.icon(
                          onPressed: widget.onGenerateSummary,
                          icon: const Icon(Icons.bolt_outlined, size: 20),
                          label: const Text("Resumo"),
                          style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // <<< CORPO DO CARD ATUALIZADO >>>
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: paragraphs.length,
                      itemBuilder: (context, index) {
                        final paragraph = paragraphs[index];
                        final paragraphHighlights = highlights
                            .where((h) => h['fullContext'] == paragraph)
                            .toList();

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: SelectableText.rich(
                            TextSpan(
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(height: 1.5),
                              children: _buildHighlightedParagraph(
                                  paragraph,
                                  TextSpanUtils.buildTextSpansForSegment(
                                      paragraph, theme, context, 16.0),
                                  paragraphHighlights,
                                  theme),
                            ),
                            textAlign: TextAlign.justify,
                            contextMenuBuilder: (context, editableTextState) {
                              final buttonItems =
                                  editableTextState.contextMenuButtonItems;
                              buttonItems.insert(
                                  0,
                                  ContextMenuButtonItem(
                                    label: 'Destacar',
                                    onPressed: () => _handleHighlight(
                                        paragraph, editableTextState),
                                  ));
                              return AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: editableTextState.contextMenuAnchors,
                                buttonItems: buttonItems,
                              );
                            },
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
                                : null),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                  "${_currentPage + 1} de ${paragraphs.length}",
                                  style: theme.textTheme.bodySmall),
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
                                : null),
                      ],
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
}
