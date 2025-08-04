// lib/pages/library_page/turretin_elenctic_theology/turretin_topic_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/models/turretin_theology_model.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/utils/text_span_utils.dart';

class _TurretinViewModel {
  final List<Map<String, dynamic>> highlights;
  final bool isPremium;

  _TurretinViewModel({required this.highlights, required this.isPremium});

  // ✅ SUBSTITUA A SUA FUNÇÃO 'fromStore' POR ESTA
  static _TurretinViewModel fromStore(
      Store<AppState> store, String topicTitle) {
    // Pega os destaques (lógica inalterada)
    final relevantHighlights = store.state.userState.userCommentHighlights
        .where((h) => h['sourceParentTitle'] == topicTitle)
        .toList();

    // --- INÍCIO DA LÓGICA DE VERIFICAÇÃO PREMIUM (COPIADA E ADAPTADA) ---
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
    // --- FIM DA LÓGICA DE VERIFICAÇÃO PREMIUM ---

    return _TurretinViewModel(
        highlights: relevantHighlights,
        isPremium: premiumStatus // Usa o valor robusto
        );
  }
}

class TurretinTopicPage extends StatefulWidget {
  final ElencticTopic topic;
  const TurretinTopicPage({super.key, required this.topic});

  @override
  State<TurretinTopicPage> createState() => _TurretinTopicPageState();
}

class _TurretinTopicPageState extends State<TurretinTopicPage> {
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
      String questionTitle,
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
    _showHighlightEditor(
        context, selectedSnippet, fullParagraph, questionTitle);
  }

  // (O resto das suas funções permanece aqui)
  // ... (cole suas funções _showHighlightEditor, _buildHighlightedParagraph, _onTtsStateChanged, etc.)
  Future<void> _showHighlightEditor(BuildContext context, String snippet,
      String fullParagraph, String questionTitle) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final List<String> allUserTags = store.state.userState.allUserTags;

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#ADD8E6",
        initialTags: const [],
        allUserTags: allUserTags,
      ),
    );

    if (result == null || result.colorHex == null) return;

    final highlightData = {
      'selectedSnippet': snippet,
      'fullContext': fullParagraph,
      'sourceType': 'turretin',
      'sourceTitle': questionTitle,
      'sourceParentTitle': widget.topic.topicTitle,
      'sourceId': "${widget.topic.topicTitle}_$questionTitle"
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
      List<TextSpan> spansWithLinks, // A lista que já tem os links
      List<Map<String, dynamic>> highlights,
      ThemeData theme) {
    if (highlights.isEmpty) {
      return spansWithLinks; // Se não há destaques, retorna os spans com links como estão.
    }

    // O resto da sua lógica para encontrar os trechos destacados no parágrafo original
    // permanece a mesma.
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
          'color': highlight['color'] as String? ?? '#ADD8E6'
        });
        startIndex = pos + snippet.length;
      }
    }

    if (snippetsInParagraph.isEmpty) {
      return spansWithLinks;
    }

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

  void _startQuestionPlayback() {
    if (widget.topic.questions.isEmpty) return;
    final question = widget.topic.questions[_currentPage];
    final List<TtsQueueItem> queue = [];

    queue.add(TtsQueueItem(
        sectionId: 'q_title_${_currentPage}',
        textToSpeak: question.questionTitle));
    if (question.questionStatement.isNotEmpty) {
      queue.add(TtsQueueItem(
          sectionId: 'q_statement_${_currentPage}',
          textToSpeak: question.questionStatement));
    }
    for (int i = 0; i < question.content.length; i++) {
      if (question.content[i].trim().isNotEmpty) {
        queue.add(TtsQueueItem(
            sectionId: 'q_paragraph_${_currentPage}_$i',
            textToSpeak: question.content[i]));
      }
    }
    if (queue.isNotEmpty) {
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startQuestionPlayback();
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
        return "Ouvir Questão";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.topicTitle, overflow: TextOverflow.ellipsis),
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
        ],
      ),
      body: StoreConnector<AppState, _TurretinViewModel>(
        converter: (store) =>
            _TurretinViewModel.fromStore(store, widget.topic.topicTitle),
        builder: (context, viewModel) {
          return PageView.builder(
            controller: _pageController,
            itemCount: widget.topic.questions.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _ttsManager.stop();
              });
            },
            itemBuilder: (context, index) {
              final question = widget.topic.questions[index];
              final questionHighlights = viewModel.highlights
                  .where((h) => h['sourceTitle'] == question.questionTitle)
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.questionTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                    if (question.questionStatement.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          question.questionStatement,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withOpacity(0.9)),
                        ),
                      ),
                    ],
                    Divider(color: theme.dividerColor, height: 32),
                    ...question.content.map((paragraph) {
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
                            // A mágica acontece aqui:
                            // 1. Primeiro, criamos os spans com as referências clicáveis.
                            // 2. Depois, passamos essa lista de spans para a função que aplica os destaques.
                            children: _buildHighlightedParagraph(
                                paragraph,
                                // A função TextSpanUtils retorna uma List<TextSpan>
                                TextSpanUtils.buildTextSpansForSegment(
                                    paragraph,
                                    theme,
                                    context,
                                    16.0), // 16.0 é o fontSize base
                                questionHighlights,
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
                                      question.questionTitle,
                                      editableTextState,
                                      viewModel.isPremium);
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
                  'Questão ${_currentPage + 1} de ${widget.topic.questions.length}',
                  style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentPage < widget.topic.questions.length - 1
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
