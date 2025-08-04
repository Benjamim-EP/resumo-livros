// lib/pages/library_page/church_history_volume_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/models/church_history_model.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/utils/text_span_utils.dart';

class _ChurchHistoryViewModel {
  final List<Map<String, dynamic>> highlights;
  final bool isPremium;

  _ChurchHistoryViewModel({required this.highlights, required this.isPremium});

  // ✅ SUBSTITUA A SUA FUNÇÃO 'fromStore' POR ESTA
  static _ChurchHistoryViewModel fromStore(
      Store<AppState> store, String volumeTitle) {
    // Pega os destaques (lógica inalterada)
    final relevantHighlights = store.state.userState.userCommentHighlights
        .where((h) => h['sourceParentTitle'] == volumeTitle)
        .toList();

    // --- INÍCIO DA NOVA LÓGICA DE VERIFICAÇÃO PREMIUM ---
    bool premiumStatus = false;
    final userDetails = store.state.userState.userDetails ?? {};

    // 1. Verifica os dados do Firestore primeiro
    final status = userDetails['subscriptionStatus'] as String?;
    final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;

    if (status == 'active') {
      if (endDateTimestamp != null) {
        premiumStatus = endDateTimestamp.toDate().isAfter(DateTime.now());
      } else {
        premiumStatus = true;
      }
    }

    // 2. Fallback para o estado do Redux
    if (!premiumStatus) {
      premiumStatus = store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive;
    }
    // --- FIM DA NOVA LÓGICA DE VERIFICAÇÃO PREMIUM ---

    return _ChurchHistoryViewModel(
      highlights: relevantHighlights,
      isPremium: premiumStatus, // Usa o valor robusto
    );
  }
}

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
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _playerState = TtsPlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _ttsManager.playerState.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    super.dispose();
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'A marcação de trechos em sermões, livros e outros recursos da biblioteca é exclusiva para assinantes Premium.'),
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
      bool isPremium) {
    editableTextState.hideToolbar();
    if (!isPremium) {
      _showPremiumRequiredDialog(context);
      return;
    }
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;
    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);
    _showHighlightEditor(context, selectedSnippet, fullParagraph, chapterTitle);
  }

  // (O resto das suas funções permanece aqui)
  // ... (cole suas funções _showHighlightEditor, _buildHighlightedParagraph, _onTtsStateChanged, etc.)

  Future<void> _showHighlightEditor(BuildContext context, String snippet,
      String fullParagraph, String chapterTitle) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final List<String> allUserTags = store.state.userState.allUserTags;

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#90EE90",
        initialTags: const [],
        allUserTags: allUserTags,
      ),
    );

    if (result == null || result.colorHex == null) return;

    final highlightData = {
      'selectedSnippet': snippet,
      'fullContext': fullParagraph,
      'sourceType': 'church_history',
      'sourceTitle': chapterTitle,
      'sourceParentTitle': widget.volume.title,
      'sourceId': "${widget.volume.title}_$chapterTitle"
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), ''),
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
    if (highlights.isEmpty) {
      return spansWithLinks;
    }

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
          'color': highlight['color'] as String? ?? '#90EE90'
        });
        startIndex = pos + snippet.length;
      }
    }

    if (snippetsInParagraph.isEmpty) {
      return spansWithLinks;
    }

    snippetsInParagraph.sort((a, b) => a['start'].compareTo(b['start']));

    // Nova lógica para aplicar a cor de fundo aos spans existentes
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
      // Verifica se este span está dentro de algum trecho destacado
      for (final highlight in snippetsInParagraph) {
        if (spanStart < highlight['end'] && spanEnd > highlight['start']) {
          backgroundColor = Color(int.parse(
                  (highlight['color'] as String).replaceFirst('#', '0xff')))
              .withOpacity(0.35);
          break;
        }
      }

      // Cria um novo TextSpan com o mesmo estilo, mas com a cor de fundo adicionada
      finalSpans.add(TextSpan(
        text: text,
        style: span.style?.copyWith(backgroundColor: backgroundColor) ??
            TextStyle(backgroundColor: backgroundColor),
        recognizer: span.recognizer,
      ));
    }

    return finalSpans;
  }

  void _onTtsStateChanged() {
    if (mounted && _playerState != _ttsManager.playerState.value) {
      setState(() => _playerState = _ttsManager.playerState.value);
    }
  }

  void _startChapterPlayback() {
    if (widget.volume.chapters.isEmpty) return;
    final chapter = widget.volume.chapters[_currentPage];
    final List<TtsQueueItem> queue = [];
    queue.add(TtsQueueItem(
        sectionId: 'title_$_currentPage',
        textToSpeak: "Capítulo. ${chapter.title}"));
    for (int i = 0; i < chapter.content.length; i++) {
      if (chapter.content[i].trim().isNotEmpty) {
        queue.add(TtsQueueItem(
            sectionId: 'paragraph_${_currentPage}_$i',
            textToSpeak: chapter.content[i]));
      }
    }
    if (queue.isNotEmpty) {
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startChapterPlayback();
        break;
      case TtsPlayerState.playing:
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        _ttsManager.restartCurrentItem();
        break;
    }
  }

  IconData _getAudioIcon() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return Icons.pause_circle_outline;
      case TtsPlayerState.paused:
        return Icons.play_circle_outline;
      default:
        return Icons.play_circle_outline;
    }
  }

  String _getAudioTooltip() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar Leitura";
      default:
        return "Ouvir Capítulo";
    }
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
                  overflow: TextOverflow.ellipsis),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.volume.title, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(_getAudioIcon(),
                color: _playerState == TtsPlayerState.playing
                    ? theme.colorScheme.secondary
                    : theme.iconTheme.color,
                size: 28),
            tooltip: _getAudioTooltip(),
            onPressed: _handleAudioControl,
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Índice de Capítulos",
            onPressed: () => _showChapterIndex(context),
          ),
        ],
      ),
      body: StoreConnector<AppState, _ChurchHistoryViewModel>(
        converter: (store) =>
            _ChurchHistoryViewModel.fromStore(store, widget.volume.title),
        builder: (context, viewModel) {
          return PageView.builder(
            controller: _pageController,
            itemCount: widget.volume.chapters.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _ttsManager.stop();
              });
            },
            itemBuilder: (context, index) {
              final currentChapter = widget.volume.chapters[index];
              final chapterHighlights = viewModel.highlights
                  .where((h) => h['sourceTitle'] == currentChapter.title)
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentChapter.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                    Divider(color: theme.dividerColor, height: 24),
                    ...currentChapter.content.map((paragraph) {
                      // Ignora parágrafos vazios
                      if (paragraph.trim().isEmpty)
                        return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SelectableText.rich(
                          TextSpan(
                            style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withOpacity(0.9)),
                            // 1. Gera os spans com links primeiro
                            // 2. Passa o resultado para a função de destacar
                            children: _buildHighlightedParagraph(
                                paragraph,
                                TextSpanUtils.buildTextSpansForSegment(
                                    paragraph,
                                    theme,
                                    context,
                                    16.0), // fontSize base de 16.0
                                chapterHighlights,
                                theme),
                          ),
                          contextMenuBuilder: (context, editableTextState) {
                            // ... (seu contextMenuBuilder existente permanece o mesmo)
                            final buttonItems =
                                editableTextState.contextMenuButtonItems;
                            buttonItems.insert(
                              0,
                              ContextMenuButtonItem(
                                label: 'Destacar',
                                onPressed: () {
                                  _handleHighlight(
                                    context,
                                    paragraph,
                                    currentChapter.title,
                                    editableTextState,
                                    viewModel.isPremium,
                                  );
                                },
                              ),
                            );
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: editableTextState.contextMenuAnchors,
                              buttonItems: buttonItems,
                            );
                          },
                          textAlign: TextAlign.justify,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
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
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn)
                    : null,
              ),
              Text(
                  'Capítulo ${_currentPage + 1} de ${widget.volume.chapters.length}',
                  style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentPage < widget.volume.chapters.length - 1
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
