// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';

// ViewModel para o StoreConnector
class _CommentaryModalViewModel {
  final List<Map<String, dynamic>> userCommentHighlights;

  _CommentaryModalViewModel({
    required this.userCommentHighlights,
  });

  static _CommentaryModalViewModel fromStore(Store<AppState> store) {
    return _CommentaryModalViewModel(
      userCommentHighlights: store.state.userState.userCommentHighlights,
    );
  }
}

class SectionCommentaryModal extends StatefulWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> commentaryItems;
  final String bookAbbrev;
  final String bookSlug;
  final String bookName;
  final int chapterNumber;
  final String versesRangeStr;
  final double initialFontSizeMultiplier;

  const SectionCommentaryModal({
    super.key,
    required this.sectionTitle,
    required this.commentaryItems,
    required this.bookAbbrev,
    required this.bookSlug,
    required this.bookName,
    required this.chapterNumber,
    required this.versesRangeStr,
    this.initialFontSizeMultiplier = 1.0,
  });

  @override
  State<SectionCommentaryModal> createState() => _SectionCommentaryModalState();
}

class _SectionCommentaryModalState extends State<SectionCommentaryModal> {
  bool _showOriginalText = false;
  // >>> INÍCIO DA MUDANÇA 1/3: Adicionar estado e instância do TTS <<<
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
    _ttsManager.stop(); // Garante que o áudio pare ao fechar o modal
    super.dispose();
  }

  // --- Funções de Controle de Áudio ---
  void _onTtsStateChanged() {
    if (mounted && _playerState != _ttsManager.playerState.value) {
      setState(() => _playerState = _ttsManager.playerState.value);
    }
  }

  void _startCommentaryPlayback() {
    final List<TtsQueueItem> queue = [];
    final String sectionId =
        "commentary_${widget.bookSlug}_${widget.chapterNumber}_${widget.versesRangeStr}";

    // Adiciona o título
    queue.add(TtsQueueItem(
        sectionId: sectionId,
        textToSpeak: "Comentário sobre: ${widget.sectionTitle}"));

    // Adiciona os parágrafos
    final commentaryText = _getCombinedCommentaryText();
    // Divide o texto em parágrafos (assumindo que são separados por duas quebras de linha)
    final paragraphs = commentaryText.split(RegExp(r'\n\n+'));
    for (var paragraph in paragraphs) {
      if (paragraph.trim().isNotEmpty) {
        queue.add(TtsQueueItem(sectionId: sectionId, textToSpeak: paragraph));
      }
    }

    if (queue.isNotEmpty) {
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startCommentaryPlayback();
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
        return "Ouvir Comentário";
    }
  }

  String get currentSectionIdForHighlights {
    return "${widget.bookSlug}_c${widget.chapterNumber}_v${widget.versesRangeStr}";
  }

  String _getCombinedCommentaryText() {
    if (widget.commentaryItems.isEmpty) {
      return "Nenhum comentário disponível para esta seção.";
    }
    return widget.commentaryItems
        .map((item) {
          final String textToShow = _showOriginalText
              ? (item['original'] as String? ?? "").trim()
              : (item['traducao'] as String? ??
                      item['original'] as String? ??
                      "")
                  .trim();
          return textToShow;
        })
        .where((text) => text.isNotEmpty)
        .join("\n\n");
  }

  void _markSelectedCommentSnippet(
    BuildContext passedContext,
    String fullCommentText,
    TextSelection selection,
  ) async {
    if (selection.isCollapsed) {
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(passedContext);
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text("Nenhum texto selecionado."),
              duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    final selectedSnippet =
        fullCommentText.substring(selection.start, selection.end);
    final store = StoreProvider.of<AppState>(passedContext, listen: false);

    const String commentHighlightColor =
        "#FFA07A"; // Cor fixa para destaques de comentários

    final result = await showDialog<HighlightResult?>(
      context: passedContext,
      builder: (_) => HighlightEditorDialog(
        initialColor: commentHighlightColor, // Passa a cor fixa
        initialTags: const [], // Sempre começa sem tags para um novo destaque
      ),
    );

    if (result == null) return; // Usuário cancelou

    if (result.shouldRemove) {
      // A lógica de remoção para destaques de comentários é diferente, pois eles têm IDs únicos.
      // Por enquanto, não implementaremos a remoção a partir daqui para simplificar.
      // O usuário removerá pela UserPage.
      return;
    }

    if (result.colorHex != null) {
      // Confirma que o usuário não cancelou a cor
      final highlightData = {
        'selectedSnippet': selectedSnippet,
        'fullCommentText': fullCommentText,
        'bookAbbrev': widget.bookAbbrev,
        'bookName': widget.bookName,
        'chapterNumber': widget.chapterNumber,
        'sectionId': currentSectionIdForHighlights,
        'sectionTitle': widget.sectionTitle,
        'verseReferenceText':
            "${widget.bookName} ${widget.chapterNumber} (Seção: ${widget.sectionTitle})",
        'language': _showOriginalText ? 'en' : 'pt',
        'color':
            result.colorHex, // Usa a cor do resultado (que é a nossa cor fixa)
        'tags': result.tags,
      };

      store.dispatch(AddCommentHighlightAction(highlightData));

      final scaffoldMessenger = ScaffoldMessenger.maybeOf(passedContext);
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text("Trecho do comentário marcado!"),
              duration: Duration(seconds: 2)),
        );
      }
    }
  }

  static void _showVerseTextDialog(
      BuildContext context, String reference, String verseText) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Referência: $reference",
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SingleChildScrollView(
              child: Text(verseText,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.85)))),
          actions: <Widget>[
            TextButton(
              child: Text("Fechar",
                  style: TextStyle(color: theme.colorScheme.primary)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  static List<TextSpan> _buildTextSpansForSegment(String textSegment,
      ThemeData theme, BuildContext pageContext, double fontSize) {
    final List<TextSpan> spans = [];
    final RegExp bibleRefRegex = RegExp(
      r'\b([1-3]?[a-zA-Z]{1,5})\s*(\d+)\s*[:.]\s*(\d+(?:\s*-\s*\d+)?)\b',
      caseSensitive: false,
    );

    int currentPosition = 0;
    for (final Match match in bibleRefRegex.allMatches(textSegment)) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
            text: textSegment.substring(currentPosition, match.start)));
      }
      final String matchedReference = match.group(0)!;
      spans.add(
        TextSpan(
          text: matchedReference,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary.withOpacity(0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              showDialog(
                context: pageContext,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) => const AlertDialog(
                  content: Row(children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text("Carregando...")
                  ]),
                ),
              );
              try {
                final List<String> verseTexts =
                    await BiblePageHelper.loadVersesFromReference(
                        matchedReference, 'nvi');
                if (pageContext.mounted)
                  Navigator.of(pageContext, rootNavigator: true)
                      .pop(); // Fecha loading
                if (verseTexts.isNotEmpty &&
                    !verseTexts.first.contains("Erro") &&
                    !verseTexts.first.contains("inválid")) {
                  if (pageContext.mounted)
                    _showVerseTextDialog(
                        pageContext, matchedReference, verseTexts.join("\n\n"));
                } else {
                  if (pageContext.mounted)
                    _showVerseTextDialog(pageContext, matchedReference,
                        "Não foi possível carregar: ${verseTexts.join("\n")}");
                }
              } catch (e) {
                if (pageContext.mounted)
                  Navigator.of(pageContext, rootNavigator: true).pop();
                if (pageContext.mounted)
                  _showVerseTextDialog(
                      pageContext, matchedReference, "Erro ao carregar: $e");
              }
            },
        ),
      );
      currentPosition = match.end;
    }
    if (currentPosition < textSegment.length) {
      spans.add(TextSpan(text: textSegment.substring(currentPosition)));
    }
    return spans.isEmpty && textSegment.isNotEmpty
        ? [TextSpan(text: textSegment)]
        : spans;
  }

  List<TextSpan> _buildCombinedTextSpans(
      String fullText,
      List<Map<String, dynamic>> userHighlights,
      String sectionIdForHighlights,
      ThemeData theme,
      BuildContext pageContext,
      double fontSize) {
    if (fullText.isEmpty) return [const TextSpan(text: "")];

    List<Map<String, dynamic>> relevantUserHighlights =
        userHighlights.where((h) {
      final String? hSectionId = h['sectionId'] as String?;
      final String? hLang = h['language'] as String?;
      bool langMatch = _showOriginalText
          ? (hLang == 'en')
          : (hLang == 'pt' || hLang == null);
      return hSectionId == sectionIdForHighlights && langMatch;
    }).toList();

    List<Map<String, dynamic>> userHighlightIntervals = [];
    for (var highlightData in relevantUserHighlights) {
      final String snippet = highlightData['selectedSnippet'] as String;
      if (snippet.isEmpty) continue;
      int startIndex = 0;
      while (startIndex < fullText.length) {
        final int pos = fullText.indexOf(snippet, startIndex);
        if (pos == -1) break;
        userHighlightIntervals.add({'start': pos, 'end': pos + snippet.length});
        startIndex = pos + snippet.length;
      }
    }

    userHighlightIntervals.sort((a, b) {
      int startCompare = (a['start'] as int).compareTo(b['start'] as int);
      if (startCompare != 0) return startCompare;
      return (b['end'] as int).compareTo(a['end'] as int);
    });

    List<Map<String, dynamic>> resolvedUserHighlights = [];
    int lastUserHighlightEnd = -1;
    for (var interval in userHighlightIntervals) {
      if ((interval['start'] as int) >= lastUserHighlightEnd) {
        resolvedUserHighlights.add(interval);
        lastUserHighlightEnd = interval['end'] as int;
      }
    }

    final List<TextSpan> finalSpans = [];
    final RegExp bibleRefRegex = RegExp(
        r'\b([1-3]?[a-zA-Z]{1,5})\s*(\d+)\s*[:.]\s*(\d+(?:\s*-\s*\d+)?)\b',
        caseSensitive: false);
    int currentPosition = 0;
    List<Match> allRefs = bibleRefRegex.allMatches(fullText).toList();

    while (currentPosition < fullText.length) {
      Map<String, dynamic>? nextUserHighlight;
      for (var uh in resolvedUserHighlights) {
        if ((uh['start'] as int) >= currentPosition) {
          if (nextUserHighlight == null ||
              (uh['start'] as int) < (nextUserHighlight['start'] as int)) {
            nextUserHighlight = uh;
          }
        }
      }

      Match? nextRefMatch;
      for (var refMatch in allRefs) {
        if (refMatch.start >= currentPosition) {
          if (nextRefMatch == null || refMatch.start < nextRefMatch.start) {
            nextRefMatch = refMatch;
          }
        }
      }

      int nextEventPosition = fullText.length;
      bool isNextEventRef = false;
      bool isNextEventUserHighlight = false;

      if (nextRefMatch != null) {
        nextEventPosition = nextRefMatch.start;
        isNextEventRef = true;
      }
      if (nextUserHighlight != null &&
          (nextUserHighlight['start'] as int) <= nextEventPosition) {
        nextEventPosition = nextUserHighlight['start'] as int;
        isNextEventRef = false;
        isNextEventUserHighlight = true;
      }

      if (nextEventPosition > currentPosition) {
        finalSpans.add(TextSpan(
            text: fullText.substring(currentPosition, nextEventPosition)));
      }

      if (isNextEventUserHighlight && nextUserHighlight != null) {
        String highlightedSegment = fullText.substring(
            nextUserHighlight['start'] as int, nextUserHighlight['end'] as int);
        List<TextSpan> spansInHighlight = _buildTextSpansForSegment(
            highlightedSegment, theme, pageContext, fontSize);
        for (var span in spansInHighlight) {
          if (span.recognizer == null) {
            finalSpans.add(TextSpan(
              text: span.text,
              style: (span.style ?? const TextStyle()).copyWith(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.35),
                color:
                    (span.style?.color) ?? theme.colorScheme.onPrimaryContainer,
              ),
            ));
          } else {
            finalSpans.add(span);
          }
        }
        currentPosition = nextUserHighlight['end'] as int;
      } else if (isNextEventRef && nextRefMatch != null) {
        final String matchedReference = nextRefMatch.group(0)!;
        finalSpans.add(
          TextSpan(
            text: matchedReference,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.secondary,
            ),
            recognizer: TapGestureRecognizer()..onTap = () async {/* ... */},
          ),
        );
        currentPosition = nextRefMatch.end;
      } else {
        currentPosition = fullText.length;
      }
    }
    return finalSpans.isEmpty ? [const TextSpan(text: "")] : finalSpans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StoreConnector<AppState, _CommentaryModalViewModel>(
      converter: (store) => _CommentaryModalViewModel.fromStore(store),
      builder: (modalBuilderContext, viewModel) {
        final String combinedText = _getCombinedCommentaryText();
        final double baseCommentaryFontSize =
            15.5 * widget.initialFontSizeMultiplier;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.sectionTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onBackground,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // >>> INÍCIO DA MUDANÇA 2/3: Adicionar os botões de controle <<<
                        Row(
                          children: [
                            // Botão de Tradução
                            IconButton(
                              icon: Icon(
                                Icons.translate_rounded,
                                size: 24,
                                color: _showOriginalText
                                    ? theme.colorScheme.primary
                                    : theme.iconTheme.color?.withOpacity(0.8),
                              ),
                              tooltip: _showOriginalText
                                  ? "Ver Tradução (PT)"
                                  : "Ver Original (EN)",
                              onPressed: () {
                                setState(() =>
                                    _showOriginalText = !_showOriginalText);
                                _ttsManager
                                    .stop(); // Para a leitura se o idioma mudar
                              },
                              splashRadius: 22,
                              padding: const EdgeInsets.all(10),
                            ),
                            // Botão de Leitura em Áudio
                            IconButton(
                              icon: Icon(
                                _getAudioIcon(),
                                color: _playerState == TtsPlayerState.playing
                                    ? theme.colorScheme.secondary
                                    : theme.iconTheme.color,
                                size: 28,
                              ),
                              tooltip: _getAudioTooltip(),
                              onPressed: _handleAudioControl,
                              splashRadius: 22,
                              padding: const EdgeInsets.all(10),
                            ),
                          ],
                        ),
                        // >>> FIM DA MUDANÇA 2/3 <<<
                      ],
                    ),
                  ),
                  Divider(
                      height: 1, color: theme.dividerColor.withOpacity(0.3)),
                  Expanded(
                    child: widget.commentaryItems.isEmpty
                        ? Center(
                            child: Text(
                                "Nenhum comentário disponível para esta seção.",
                                style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7)),
                                textAlign: TextAlign.center))
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16.0, 12.0, 16.0, 16.0),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: SelectableText.rich(
                                TextSpan(
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onBackground,
                                    height: 1.65,
                                    fontSize: baseCommentaryFontSize,
                                  ),
                                  children: _buildCombinedTextSpans(
                                      combinedText,
                                      viewModel.userCommentHighlights,
                                      currentSectionIdForHighlights,
                                      theme,
                                      modalBuilderContext,
                                      baseCommentaryFontSize),
                                ),
                                textAlign: TextAlign.justify,
                                contextMenuBuilder: (BuildContext menuContext,
                                    EditableTextState editableTextState) {
                                  final List<ContextMenuButtonItem>
                                      buttonItems =
                                      editableTextState.contextMenuButtonItems;
                                  final currentTextSelection = editableTextState
                                      .textEditingValue.selection;
                                  if (!currentTextSelection.isCollapsed) {
                                    buttonItems.insert(
                                      0,
                                      ContextMenuButtonItem(
                                        label: 'Marcar Trecho',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _markSelectedCommentSnippet(
                                            context,
                                            combinedText,
                                            currentTextSelection,
                                          );
                                        },
                                      ),
                                    );
                                  }
                                  return AdaptiveTextSelectionToolbar
                                      .buttonItems(
                                    anchors:
                                        editableTextState.contextMenuAnchors,
                                    buttonItems: buttonItems,
                                  );
                                },
                              ),
                            ),
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
