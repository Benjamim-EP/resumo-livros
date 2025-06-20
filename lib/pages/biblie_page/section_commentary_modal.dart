// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Para BiblePageHelper.loadVersesFromReference
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

// ViewModel para o StoreConnector (pode permanecer o mesmo)
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
  final double initialFontSizeMultiplier; // Para passar o tamanho da fonte

  const SectionCommentaryModal({
    super.key,
    required this.sectionTitle,
    required this.commentaryItems,
    required this.bookAbbrev,
    required this.bookSlug,
    required this.bookName,
    required this.chapterNumber,
    required this.versesRangeStr,
    this.initialFontSizeMultiplier = 1.0, // Valor padrão
  });

  @override
  State<SectionCommentaryModal> createState() => _SectionCommentaryModalState();
}

class _SectionCommentaryModalState extends State<SectionCommentaryModal> {
  bool _showOriginalText = false;

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
        .join(
            "\n\n"); // Usar um separador menos propenso a conflitos com markdown
  }

  void _markSelectedCommentSnippet(
    BuildContext passedContext,
    String fullCommentText,
    TextSelection selection,
  ) {
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

    final highlightData = {
      'selectedSnippet': selectedSnippet,
      'fullCommentText':
          fullCommentText, // Pode ser muito grande, considere truncar ou não salvar
      'bookAbbrev': widget.bookAbbrev,
      'bookName': widget.bookName,
      'chapterNumber': widget.chapterNumber,
      'sectionId': currentSectionIdForHighlights,
      'sectionTitle': widget.sectionTitle,
      'verseReferenceText':
          "${widget.bookName} ${widget.chapterNumber} (Seção: ${widget.sectionTitle})",
      'language': _showOriginalText ? 'en' : 'pt',
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static List<TextSpan> _buildTextSpansForSegment(
    String textSegment,
    ThemeData theme,
    BuildContext pageContext,
    double fontSize,
  ) {
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
                  Navigator.of(pageContext, rootNavigator: true)
                      .pop(); // Fecha loading
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
    double fontSize,
  ) {
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

    // Mapeia os destaques do usuário para objetos de intervalo para facilitar a verificação
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
    // Ordena por início, depois por fim (maior primeiro para lidar com aninhamento se houver)
    userHighlightIntervals.sort((a, b) {
      int startCompare = (a['start'] as int).compareTo(b['start'] as int);
      if (startCompare != 0) return startCompare;
      return (b['end'] as int).compareTo(a['end'] as int);
    });

    // Remove sobreposições de destaques do usuário (o primeiro/maior vence)
    List<Map<String, dynamic>> resolvedUserHighlights = [];
    int lastUserHighlightEnd = -1;
    for (var interval in userHighlightIntervals) {
      if ((interval['start'] as int) >= lastUserHighlightEnd) {
        resolvedUserHighlights.add(interval);
        lastUserHighlightEnd = interval['end'] as int;
      }
    }

    // Agora, processa o texto inteiro para referências e intercala com os destaques do usuário
    final List<TextSpan> finalSpans = [];
    final RegExp bibleRefRegex = RegExp(
      r'\b([1-3]?[a-zA-Z]{1,5})\s*(\d+)\s*[:.]\s*(\d+(?:\s*-\s*\d+)?)\b',
      caseSensitive: false,
    );

    int currentPosition = 0;

    // Encontra todas as referências primeiro
    List<Match> allRefs = bibleRefRegex.allMatches(fullText).toList();

    // Itera sobre o texto, considerando tanto os destaques do usuário quanto as referências
    while (currentPosition < fullText.length) {
      // Encontra o próximo destaque do usuário ou referência, o que vier primeiro
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
          (nextUserHighlight['start'] as int) < nextEventPosition) {
        nextEventPosition = nextUserHighlight['start'] as int;
        isNextEventRef =
            false; // Destaque do usuário tem precedência se começar antes
        isNextEventUserHighlight = true;
      } else if (nextUserHighlight != null &&
          (nextUserHighlight['start'] as int) == nextEventPosition &&
          isNextEventRef) {
        // Se ambos começam na mesma posição, precisamos decidir a prioridade.
        // Se a referência estiver DENTRO do destaque do usuário, o destaque "envolve"
        // Neste caso, vamos priorizar o destaque e processar o conteúdo dele para referências depois.
        // Se a referência for maior que o destaque, a lógica atual de iterar já pode lidar com isso.
        // Para simplificar, se for igual, vamos com o destaque primeiro.
        isNextEventRef = false;
        isNextEventUserHighlight = true;
      }

      // Adiciona texto normal antes do próximo evento
      if (nextEventPosition > currentPosition) {
        finalSpans.add(TextSpan(
            text: fullText.substring(currentPosition, nextEventPosition)));
      }

      if (isNextEventUserHighlight && nextUserHighlight != null) {
        // Processa o trecho destacado para referências INTERNAS
        String highlightedSegment = fullText.substring(
            nextUserHighlight['start'] as int, nextUserHighlight['end'] as int);
        List<TextSpan> spansInHighlight = _buildTextSpansForSegment(
            highlightedSegment, theme, pageContext, fontSize);

        // Aplica o fundo de destaque a cada TextSpan dentro do segmento destacado,
        // exceto para os que já são referências (que têm seu próprio estilo)
        for (var span in spansInHighlight) {
          if (span.recognizer == null) {
            // Se não for uma referência clicável
            finalSpans.add(TextSpan(
              text: span.text,
              style: (span.style ?? const TextStyle()).copyWith(
                // Pega o estilo original do span (se houver)
                backgroundColor: theme.colorScheme.primary.withOpacity(0.35),
                // Mantém a cor do texto do span original, ou define uma cor de contraste
                color:
                    (span.style?.color) ?? theme.colorScheme.onPrimaryContainer,
              ),
            ));
          } else {
            // É uma referência, mantém seu estilo e recognizer
            finalSpans.add(span);
          }
        }
        currentPosition = nextUserHighlight['end'] as int;
      } else if (isNextEventRef && nextRefMatch != null) {
        // Adiciona a referência clicável
        final String matchedReference = nextRefMatch.group(0)!;
        finalSpans.add(
          TextSpan(
            text: matchedReference,
            style: TextStyle(
              color:
                  theme.colorScheme.primary, // Cor diferente para referências
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.secondary,
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
                      _showVerseTextDialog(pageContext, matchedReference,
                          verseTexts.join("\n\n"));
                  } else {
                    if (pageContext.mounted)
                      _showVerseTextDialog(pageContext, matchedReference,
                          "Não foi possível carregar: ${verseTexts.join("\n")}");
                  }
                } catch (e) {
                  if (pageContext.mounted)
                    Navigator.of(pageContext, rootNavigator: true)
                        .pop(); // Fecha loading
                  if (pageContext.mounted)
                    _showVerseTextDialog(
                        pageContext, matchedReference, "Erro ao carregar: $e");
                }
              },
          ),
        );
        currentPosition = nextRefMatch.end;
      } else {
        // Não há mais eventos, sai do loop
        currentPosition = fullText.length;
      }
    }
    return finalSpans.isEmpty ? [const TextSpan(text: "")] : finalSpans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Não é necessário pegar o store aqui se o StoreConnector faz o trabalho

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
                color: theme
                    .scaffoldBackgroundColor, // Usar a cor de fundo do scaffold do tema
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
                            setState(
                                () => _showOriginalText = !_showOriginalText);
                          },
                          splashRadius: 22,
                          padding: const EdgeInsets.all(10),
                        )
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
                              textAlign: TextAlign.center,
                            ),
                          )
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
                                      modalBuilderContext, // Passa o contexto correto
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
                                            modalBuilderContext, // Usa o contexto do builder do StoreConnector
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
