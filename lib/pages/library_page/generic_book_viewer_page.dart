// lib/pages/library_page/generic_book_viewer_page.dart

import 'dart:async'; // Para o Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';

// ViewModel para buscar destaques e status premium do Redux
class _BookViewerViewModel {
  final List<Map<String, dynamic>> highlights;
  final bool isPremium;
  final List<String> allUserTags;

  _BookViewerViewModel({
    required this.highlights,
    required this.isPremium,
    required this.allUserTags,
  });

  static _BookViewerViewModel fromStore(Store<AppState> store, String bookId) {
    // Filtra para pegar apenas os destaques deste livro específico
    final relevantHighlights = store.state.userState.userCommentHighlights
        .where((h) => h['sourceId'] == bookId)
        .toList();

    // Lógica robusta para verificar o status premium
    bool premiumStatus = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!premiumStatus) {
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final status = userDetails['subscriptionStatus'] as String?;
        final endDate =
            (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();
        if (status == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now())) {
          premiumStatus = true;
        }
      }
    }

    return _BookViewerViewModel(
      highlights: relevantHighlights,
      isPremium: premiumStatus,
      allUserTags: store.state.userState.allUserTags,
    );
  }
}

// Widget principal que agora é Stateful
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

  // Estado para controle da UI e do progresso
  PageController? _pageController;
  int _currentPage = 0;
  bool _isLoadingLastPage = true;

  // Controladores de scroll e debounce para salvar o progresso
  final Map<int, ScrollController> _scrollControllers = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _firestoreService.getBookChapters(widget.bookId);
    _loadLastReadPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(LoadUserTagsAction());
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _debounce?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Salva o progresso unificado no Firestore com debounce.
  void _saveUnifiedProgress(int chapterIndex, int totalChapters) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;

      final scrollController = _scrollControllers[chapterIndex];
      if (scrollController == null ||
          !scrollController.hasClients ||
          scrollController.position.maxScrollExtent <= 0) return;

      final double scrollProgress = (scrollController.position.pixels /
              scrollController.position.maxScrollExtent)
          .clamp(0.0, 1.0);
      final double overallProgress =
          (chapterIndex + scrollProgress) / totalChapters;

      final store = StoreProvider.of<AppState>(context, listen: false);
      final userId = store.state.userState.userId;

      if (userId != null) {
        print(
            "Salvando progresso para '${widget.bookId}': ${(overallProgress * 100).toStringAsFixed(1)}%");
        _firestoreService.updateUnifiedReadingProgress(
          userId,
          widget.bookId,
          overallProgress,
        );
      }
    });
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
    BuildContext context,
    String fullParagraph,
    String chapterTitle,
    EditableTextState editableTextState,
    _BookViewerViewModel viewModel,
  ) async {
    editableTextState.hideToolbar();
    if (!viewModel.isPremium) {
      _showPremiumRequiredDialog();
      return;
    }

    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;

    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#90EE90",
        initialTags: const [],
        allUserTags: viewModel.allUserTags,
      ),
    );

    if (result == null || result.colorHex == null) return;

    final highlightData = {
      'selectedSnippet': selectedSnippet,
      'fullContext': fullParagraph,
      'sourceType': 'book',
      'sourceTitle': chapterTitle,
      'sourceParentTitle': widget.bookTitle,
      'sourceId': widget.bookId,
      'color': result.colorHex,
      'tags': result.tags,
    };

    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Destaque salvo!")));
  }

  List<TextSpan> _buildHighlightedParagraph(String paragraph,
      List<Map<String, dynamic>> highlights, ThemeData theme) {
    if (highlights.isEmpty) {
      return [TextSpan(text: paragraph)];
    }

    List<TextSpan> spans = [];
    int lastEnd = 0;

    highlights.sort((a, b) {
      final int aStart = paragraph.indexOf(a['selectedSnippet']);
      final int bStart = paragraph.indexOf(b['selectedSnippet']);
      return aStart.compareTo(bStart);
    });

    for (var highlight in highlights) {
      String snippet = highlight['selectedSnippet'] ?? '';
      if (snippet.isEmpty) continue;

      int startIndex = paragraph.indexOf(snippet, lastEnd);
      if (startIndex == -1) continue;

      if (startIndex > lastEnd) {
        spans.add(TextSpan(text: paragraph.substring(lastEnd, startIndex)));
      }

      spans.add(TextSpan(
        text: snippet,
        style: TextStyle(
          backgroundColor: Color(int.parse(
                  (highlight['color'] as String).replaceFirst('#', '0xff')))
              .withOpacity(0.35),
        ),
      ));
      lastEnd = startIndex + snippet.length;
    }

    if (lastEnd < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(lastEnd)));
    }

    return spans.isEmpty ? [TextSpan(text: paragraph)] : spans;
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
      body: StoreConnector<AppState, _BookViewerViewModel>(
        converter: (store) =>
            _BookViewerViewModel.fromStore(store, widget.bookId),
        builder: (context, viewModel) {
          return FutureBuilder<List<Map<String, dynamic>>>(
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
                  totalChapters > 0 ? (_currentPage + 1) / totalChapters : 1.0;

              return Column(
                children: [
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
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: totalChapters,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                        _saveCurrentPage(index);
                        // Salva um progresso "inicial" ao virar a página
                        _saveUnifiedProgress(index, totalChapters);
                      },
                      itemBuilder: (context, index) {
                        if (!_scrollControllers.containsKey(index)) {
                          _scrollControllers[index] = ScrollController();
                          _scrollControllers[index]!.addListener(() {
                            _saveUnifiedProgress(index, totalChapters);
                          });
                        }

                        final chapter = chapters[index];
                        final title = chapter['title'] ?? 'Capítulo';
                        final paragraphs =
                            List<String>.from(chapter['paragraphs'] ?? []);
                        final chapterHighlights = viewModel.highlights
                            .where((h) => h['sourceTitle'] == title)
                            .toList();

                        return SingleChildScrollView(
                          controller: _scrollControllers[index],
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
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: SelectableText.rich(
                                      TextSpan(
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontSize: 17, height: 1.6),
                                        children: _buildHighlightedParagraph(
                                            p, chapterHighlights, theme),
                                      ),
                                      textAlign: TextAlign.justify,
                                      contextMenuBuilder:
                                          (context, editableTextState) {
                                        return AdaptiveTextSelectionToolbar
                                            .buttonItems(
                                          anchors: editableTextState
                                              .contextMenuAnchors,
                                          buttonItems: [
                                            ...editableTextState
                                                .contextMenuButtonItems,
                                            ContextMenuButtonItem(
                                              label: 'Destacar',
                                              onPressed: () {
                                                _handleHighlight(
                                                    context,
                                                    p,
                                                    title,
                                                    editableTextState,
                                                    viewModel);
                                              },
                                            ),
                                          ],
                                        );
                                      },
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
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final totalChapters = snapshot.data!.length;

          return BottomAppBar(
            elevation: 8,
            child: SizedBox(
              height: 56.0,
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
