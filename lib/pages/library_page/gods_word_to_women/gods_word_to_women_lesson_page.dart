// lib/pages/library_page/gods_word_to_women/gods_word_to_women_lesson_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/models/gods_word_to_women_model.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:redux/redux.dart';

class _ViewModel {
  final List<Map<String, dynamic>> highlights;
  final bool isPremium;

  _ViewModel({required this.highlights, required this.isPremium});

  static _ViewModel fromStore(Store<AppState> store, String lessonTitle) {
    final relevantHighlights = store.state.userState.userCommentHighlights
        .where((h) =>
            h['sourceTitle'] == lessonTitle &&
            h['sourceType'] == 'gods_word_to_women')
        .toList();
    bool premiumStatus = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    return _ViewModel(highlights: relevantHighlights, isPremium: premiumStatus);
  }
}

class GodsWordToWomenLessonPage extends StatefulWidget {
  final GodsWordToWomenLesson lesson;
  const GodsWordToWomenLessonPage({super.key, required this.lesson});

  @override
  State<GodsWordToWomenLessonPage> createState() =>
      _GodsWordToWomenLessonPageState();
}

class _GodsWordToWomenLessonPageState extends State<GodsWordToWomenLessonPage> {
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _playerState = TtsPlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _ttsManager.playerState.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (mounted && _playerState != _ttsManager.playerState.value) {
      setState(() => _playerState = _ttsManager.playerState.value);
    }
  }

  // >>>>>>>>>>>>>>>> FUNÇÕES DE ÁUDIO TTS <<<<<<<<<<<<<<<<<<

  void _startLessonPlayback() {
    if (widget.lesson.content.isEmpty) return;

    final List<TtsQueueItem> queue = [];
    final lessonId = "GWtW_${widget.lesson.lessonTitle.hashCode}";

    // Adiciona o título da lição à fila
    queue.add(TtsQueueItem(
        sectionId: '${lessonId}_title',
        textToSpeak: widget.lesson.lessonTitle));

    // Adiciona cada parágrafo do conteúdo à fila
    for (int i = 0; i < widget.lesson.content.length; i++) {
      if (widget.lesson.content[i].trim().isNotEmpty) {
        queue.add(TtsQueueItem(
            sectionId: '${lessonId}_p$i',
            textToSpeak: widget.lesson.content[i]));
      }
    }

    if (queue.isNotEmpty) {
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startLessonPlayback();
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
        return "Ouvir Lição";
    }
  }
  // >>>>>>>>>>>>>>>> FIM DAS FUNÇÕES DE ÁUDIO TTS <<<<<<<<<<<<<<<<<<

  void _showPremiumRequiredDialog() {
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

  void _handleHighlight(BuildContext context, String fullParagraph,
      EditableTextState editableTextState, bool isPremium) {
    editableTextState.hideToolbar();
    if (!isPremium) {
      _showPremiumRequiredDialog();
      return;
    }
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;
    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);
    _showHighlightEditor(context, selectedSnippet, fullParagraph);
  }

  Future<void> _showHighlightEditor(
      BuildContext context, String snippet, String fullParagraph) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final List<String> allUserTags = store.state.userState.allUserTags;

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
          initialColor: "#FFB6C1",
          initialTags: const [],
          allUserTags: allUserTags),
    );

    if (result == null || result.colorHex == null) return;

    final highlightData = {
      'selectedSnippet': snippet,
      'fullContext': fullParagraph,
      'sourceType': 'gods_word_to_women',
      'sourceTitle': widget.lesson.lessonTitle,
      'sourceParentTitle': "A Palavra de Deus às Mulheres",
      'sourceId': "GWtW_${widget.lesson.lessonTitle.replaceAll(' ', '_')}",
      'color': result.colorHex,
      'tags': result.tags,
    };

    store.dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Destaque salvo!")));
  }

  List<TextSpan> _buildHighlightedParagraph(String paragraph,
      List<Map<String, dynamic>> highlights, ThemeData theme) {
    if (highlights.isEmpty) return [TextSpan(text: paragraph)];
    List<TextSpan> spans = [];
    int lastEnd = 0;
    List<Map<String, dynamic>> snippetsInParagraph = [];
    for (var highlight in highlights) {
      String snippet = highlight['selectedSnippet'] ?? '';
      if (snippet.isEmpty) continue;
      int startIndex = 0;
      while (startIndex < paragraph.length) {
        int pos = paragraph.indexOf(snippet, startIndex);
        if (pos == -1) break;
        snippetsInParagraph.add({
          'start': pos,
          'end': pos + snippet.length,
          'color': highlight['color'] as String? ?? '#FFB6C1'
        });
        startIndex = pos + snippet.length;
      }
    }
    if (snippetsInParagraph.isEmpty) return [TextSpan(text: paragraph)];
    snippetsInParagraph.sort((a, b) => a['start'].compareTo(b['start']));
    for (var snippetInfo in snippetsInParagraph) {
      if (snippetInfo['start'] > lastEnd) {
        spans.add(
            TextSpan(text: paragraph.substring(lastEnd, snippetInfo['start'])));
      }
      spans.add(TextSpan(
        text: paragraph.substring(snippetInfo['start'], snippetInfo['end']),
        style: TextStyle(
            backgroundColor: Color(int.parse(
                    (snippetInfo['color'] as String).replaceFirst('#', '0xff')))
                .withOpacity(0.35)),
      ));
      lastEnd = snippetInfo['end'];
    }
    if (lastEnd < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(lastEnd)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.lesson.lessonNumber, overflow: TextOverflow.ellipsis),
        actions: [
          // >>>>>>>>>>>>>>>> BOTÃO DE ÁUDIO ADICIONADO AQUI <<<<<<<<<<<<<<<<<<
          IconButton(
            icon: Icon(_getAudioIcon(),
                color: _playerState == TtsPlayerState.playing
                    ? theme.colorScheme.secondary
                    : theme.iconTheme.color,
                size: 28),
            tooltip: _getAudioTooltip(),
            onPressed: _handleAudioControl,
          ),
        ],
      ),
      body: StoreConnector<AppState, _ViewModel>(
        converter: (store) =>
            _ViewModel.fromStore(store, widget.lesson.lessonTitle),
        builder: (context, viewModel) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lesson.lessonTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                Divider(color: theme.dividerColor, height: 24),
                ...widget.lesson.content
                    .map((paragraph) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SelectableText.rich(
                            TextSpan(
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(height: 1.6),
                              children: _buildHighlightedParagraph(
                                  paragraph, viewModel.highlights, theme),
                            ),
                            contextMenuBuilder: (context, editableTextState) {
                              final buttonItems =
                                  editableTextState.contextMenuButtonItems;
                              buttonItems.insert(
                                0,
                                ContextMenuButtonItem(
                                  label: 'Destacar',
                                  onPressed: () {
                                    _handleHighlight(context, paragraph,
                                        editableTextState, viewModel.isPremium);
                                  },
                                ),
                              );
                              return AdaptiveTextSelectionToolbar.buttonItems(
                                  anchors: editableTextState.contextMenuAnchors,
                                  buttonItems: buttonItems);
                            },
                            textAlign: TextAlign.justify,
                          ),
                        ))
                    .toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
