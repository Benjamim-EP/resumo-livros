// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/font_size_slider_dialog.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// <<< 1. IMPORTAR SEU UTILITY DE TEXTSPAN >>>
import 'package:septima_biblia/utils/text_span_utils.dart';

// ViewModel (sem alterações)
class _CommentaryModalViewModel {
  final List<Map<String, dynamic>> userCommentHighlights;
  final bool isPremium;
  final List<String> allUserTags;

  _CommentaryModalViewModel({
    required this.userCommentHighlights,
    required this.isPremium,
    required this.allUserTags,
  });

  static _CommentaryModalViewModel fromStore(
      Store<AppState> store, String sectionId) {
    // Lógica para filtrar destaques
    final highlights = store.state.userState.userCommentHighlights
        .where((h) => h['sectionId'] == sectionId)
        .toList();

    // Lógica robusta para status premium
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

    return _CommentaryModalViewModel(
      userCommentHighlights: highlights,
      isPremium: premiumStatus,
      allUserTags: store.state.userState.allUserTags,
    );
  }
}

class SectionCommentaryModal extends StatefulWidget {
  // Seus parâmetros existentes
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
  // <<< INÍCIO DA MODIFICAÇÃO 1/3: ADICIONAR ESTADO PARA A FONTE >>>
  late double _currentFontSizeMultiplier;
  static const double MIN_FONT_MULTIPLIER = 0.8;
  static const double MAX_FONT_MULTIPLIER = 1.6;
  static const double FONT_STEP = 0.1;
  // <<< FIM DA MODIFICAÇÃO 1/3 >>>

  bool _showOriginalText = false;
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _playerState = TtsPlayerState.stopped;

  @override
  void initState() {
    super.initState();
    // <<< INÍCIO DA MODIFICAÇÃO 2/3: INICIALIZAR O MULTIPLICADOR DE FONTE >>>
    _currentFontSizeMultiplier = widget.initialFontSizeMultiplier;
    // <<< FIM DA MODIFICAÇÃO 2/3 >>>
    _ttsManager.playerState.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    super.dispose();
  }

  // <<< INÍCIO DA MODIFICAÇÃO 3/3: ADICIONAR FUNÇÕES DE CONTROLE DE FONTE >>>
  void _updateFontSize(double newMultiplier) {
    if (mounted) {
      setState(() {
        _currentFontSizeMultiplier =
            newMultiplier.clamp(MIN_FONT_MULTIPLIER, MAX_FONT_MULTIPLIER);
      });
    }
  }

  void _showFontSizeDialog(BuildContext context) {
    final double baseFontSize = 15.5; // Tamanho base que você definiu no modal

    showDialog(
      context: context,
      builder: (dialogContext) => FontSizeSliderDialog(
        initialSize: _currentFontSizeMultiplier * baseFontSize,
        minSize: MIN_FONT_MULTIPLIER * baseFontSize,
        maxSize: MAX_FONT_MULTIPLIER * baseFontSize,
        onSizeChanged: (newAbsoluteSize) {
          final newMultiplier = newAbsoluteSize / baseFontSize;
          _updateFontSize(newMultiplier); // Atualiza o estado local do modal
        },
      ),
    );
  }

  void _onTtsStateChanged() {
    if (mounted && _playerState != _ttsManager.playerState.value) {
      setState(() => _playerState = _ttsManager.playerState.value);
    }
  }

  void _startCommentaryPlayback() {
    final List<TtsQueueItem> queue = [];
    final String sectionId =
        "commentary_${widget.bookSlug}_${widget.chapterNumber}_${widget.versesRangeStr}";

    queue.add(TtsQueueItem(
        sectionId: sectionId,
        textToSpeak: "Comentário sobre: ${widget.sectionTitle}"));

    final commentaryText = _getCombinedCommentaryText(true);
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

  void _handleHighlight(
    BuildContext context,
    String fullParagraph,
    EditableTextState editableTextState,
    _CommentaryModalViewModel viewModel, // Recebe o ViewModel
  ) async {
    editableTextState.hideToolbar();
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;

    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#FFA07A",
        initialTags: const [],
        allUserTags: viewModel.allUserTags, // Usa as tags do ViewModel
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
      'sectionId': currentSectionIdForHighlights,
      'sectionTitle': widget.sectionTitle,
      'verseReferenceText':
          "${widget.bookName} ${widget.chapterNumber}:${widget.versesRangeStr} (Comentário)",
      'sourceType': 'bible_commentary',
      'language': _showOriginalText ? 'en' : 'pt',
      'color': result.colorHex,
      'tags': result.tags,
    };

    store.dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Destaque salvo!")));
  }

  // <<< 3. FUNÇÃO _buildHighlightedParagraph RESTAURADA E ADAPTADA >>>
  List<TextSpan> _buildHighlightedParagraph(
    String originalParagraph,
    List<TextSpan> spansWithLinks,
    List<Map<String, dynamic>> highlights,
    ThemeData theme,
  ) {
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
          'color': highlight['color'] as String? ?? '#FFA07A'
        });
        startIndex = pos + snippet.length;
      }
    }

    if (snippetsInParagraph.isEmpty) {
      return spansWithLinks;
    }

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

  String _getCombinedCommentaryText([bool forTTS = false]) {
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
          return forTTS
              ? textToShow.replaceFirst(RegExp(r'^\d+\.\s*'), '')
              : textToShow;
        })
        .where((text) => text.isNotEmpty)
        .join("\n\n");
  }

  void _markSelectedCommentSnippet(
    BuildContext passedContext,
    String
        fullCommentText, // Este é o parágrafo completo onde a seleção foi feita
    TextSelection selection,
  ) async {
    // 1. Garante que há texto selecionado
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

    // 2. Extrai o trecho e obtém a instância da store
    final selectedSnippet =
        fullCommentText.substring(selection.start, selection.end);
    final store = StoreProvider.of<AppState>(passedContext, listen: false);

    // <<< MUDANÇA ESSENCIAL AQUI >>>
    // Pega a lista de tags diretamente do estado ANTES de mostrar o diálogo
    final List<String> allUserTags = store.state.userState.allUserTags;

    // 3. Mostra o diálogo para o usuário, passando a lista de tags
    final result = await showDialog<HighlightResult?>(
      context: passedContext,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#FFA07A", // Cor padrão para destaques de literatura
        initialTags: const [], // Destaques de comentário sempre começam sem tags
        allUserTags: allUserTags, // <<< PASSA A LISTA AQUI
      ),
    );

    // 4. Se o usuário cancelou o diálogo, não faz nada
    if (result == null || result.shouldRemove || result.colorHex == null)
      return;

    // 5. Constrói o objeto de dados do destaque
    final highlightData = {
      'selectedSnippet': selectedSnippet,
      'fullContext': fullCommentText,
      'bookAbbrev': widget.bookAbbrev,
      'bookName': widget.bookName,
      'chapterNumber': widget.chapterNumber,
      'sectionId': currentSectionIdForHighlights,
      'sectionTitle': widget.sectionTitle,
      'verseReferenceText':
          "${widget.bookName} ${widget.chapterNumber}:${widget.versesRangeStr} (Comentário)",
      'sourceType': 'bible_commentary',
      'language': _showOriginalText ? 'en' : 'pt',
      'color': result.colorHex,
      'tags': result.tags,
    };

    // 6. Despacha a ação para salvar o destaque no Firestore
    store.dispatch(AddCommentHighlightAction(highlightData));

    // 7. Mostra um feedback visual de sucesso
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(passedContext);
    if (scaffoldMessenger != null && mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text("Trecho do comentário marcado!"),
            duration: Duration(seconds: 2)),
      );
    }
  }

  // <<< CORREÇÃO AQUI: A função _buildTextSpansForSegment agora é um método da classe, não estático >>>
  List<TextSpan> _buildCombinedTextSpans(
      String fullText,
      List<Map<String, dynamic>> userHighlights,
      String sectionIdForHighlights,
      ThemeData theme,
      BuildContext pageContext,
      double fontSize) {
    if (fullText.isEmpty) return [const TextSpan(text: "")];

    // ... A lógica interna desta função permanece a mesma. Apenas certifique-se
    // que a chamada para _buildTextSpansForSegment dentro dela seja feita sem o `static`.
    // Exemplo: spansInHighlight = _buildTextSpansForSegment(highlightedSegment, ...);
    //
    // O código abaixo é uma cópia da sua versão anterior, mas agora pode chamar
    // métodos da classe diretamente.

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
      final String? colorHex = highlightData['color'] as String?;
      if (snippet.isEmpty) continue;
      int startIndex = 0;
      while (startIndex < fullText.length) {
        final int pos = fullText.indexOf(snippet, startIndex);
        if (pos == -1) break;
        userHighlightIntervals.add(
            {'start': pos, 'end': pos + snippet.length, 'color': colorHex});
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
        String? colorHex = nextUserHighlight['color'] as String? ?? "#FFA07A";
        Color highlightColor =
            Color(int.parse(colorHex.replaceFirst('#', '0xff')));

        Color backgroundColor = highlightColor.withOpacity(0.40);
        Color textColor = theme.colorScheme.onSurface;

        // A chamada agora é para um método da classe, não estático
        List<TextSpan> spansInHighlight = _buildTextSpansForSegment(
            highlightedSegment, theme, pageContext, fontSize);

        for (var span in spansInHighlight) {
          if (span.recognizer == null) {
            finalSpans.add(TextSpan(
              text: span.text,
              style: (span.style ?? const TextStyle()).copyWith(
                backgroundColor: backgroundColor,
                color: textColor,
              ),
            ));
          } else {
            finalSpans.add(TextSpan(
              text: span.text,
              style: span.style?.copyWith(backgroundColor: backgroundColor),
              recognizer: span.recognizer,
            ));
          }
        }
        currentPosition = nextUserHighlight['end'] as int;
      } else if (isNextEventRef && nextRefMatch != null) {
        finalSpans.add(_createClickableReferenceSpan(
            nextRefMatch.group(0)!, theme, pageContext, fontSize));
        currentPosition = nextRefMatch.end;
      } else {
        currentPosition = fullText.length;
      }
    }
    return finalSpans.isEmpty ? [const TextSpan(text: "")] : finalSpans;
  }

  // --- FIM DO CÓDIGO A SER COLADO ---

  /// Cria um TextSpan clicável para uma referência bíblica.
  TextSpan _createClickableReferenceSpan(String reference, ThemeData theme,
      BuildContext pageContext, double fontSize) {
    return TextSpan(
      text: reference,
      style: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary.withOpacity(0.5),
        fontSize: fontSize,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          print("Referência clicada: $reference");
          showDialog(
            context: pageContext,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) => AlertDialog(
              content: Row(children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Carregando...")
              ]),
            ),
          );
          try {
            final List<String> verseTexts =
                await BiblePageHelper.loadVersesFromReference(reference, 'nvi');
            if (pageContext.mounted)
              Navigator.of(pageContext, rootNavigator: true).pop();
            if (verseTexts.isNotEmpty &&
                !verseTexts.first.contains("Erro") &&
                !verseTexts.first.contains("inválid")) {
              if (pageContext.mounted)
                _showVerseTextDialog(
                    pageContext, reference, verseTexts.join("\n\n"));
            } else {
              if (pageContext.mounted)
                _showVerseTextDialog(pageContext, reference,
                    "Não foi possível carregar: ${verseTexts.join("\n")}");
            }
          } catch (e) {
            if (pageContext.mounted)
              Navigator.of(pageContext, rootNavigator: true).pop();
            if (pageContext.mounted)
              _showVerseTextDialog(
                  pageContext, reference, "Erro ao carregar: $e");
          }
        },
    );
  }

  /// Constrói os spans de texto, agora chamando o método de classe _createClickableReferenceSpan
  List<TextSpan> _buildTextSpansForSegment(String textSegment, ThemeData theme,
      BuildContext pageContext, double fontSize) {
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
      spans.add(_createClickableReferenceSpan(
          matchedReference, theme, pageContext, fontSize));
      currentPosition = match.end;
    }
    if (currentPosition < textSegment.length) {
      spans.add(TextSpan(text: textSegment.substring(currentPosition)));
    }
    return spans.isEmpty && textSegment.isNotEmpty
        ? [TextSpan(text: textSegment)]
        : spans;
  }

  // O _showVerseTextDialog agora também é um método da classe
  void _showVerseTextDialog(
      BuildContext context, String reference, String verseText) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double baseFontSize =
        15.5 * _currentFontSizeMultiplier; // <<< FONTE DINÂMICA

    final TextStyle titleStyle = theme.textTheme.titleLarge!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontFamily: theme.textTheme.headlineSmall?.fontFamily,
    );
    final TextStyle bodyStyle = theme.textTheme.bodyLarge!.copyWith(
      height: 1.6,
      fontSize: baseFontSize, // <<< APLICA A FONTE DINÂMICA
      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
      color: theme.colorScheme.onSurface.withOpacity(0.9),
    );
    final TextStyle numberStyle = bodyStyle.copyWith(
      color: theme.colorScheme.secondary,
      fontWeight: FontWeight.w700,
      fontSize: bodyStyle.fontSize! * 1.1,
    );

    return StoreConnector<AppState, _CommentaryModalViewModel>(
      converter: (store) => _CommentaryModalViewModel.fromStore(
          store, currentSectionIdForHighlights),
      builder: (modalBuilderContext, viewModel) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 4.0, 8.0, 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          // >>>>>>>>>>>> INÍCIO DA MODIFICAÇÃO <<<<<<<<<<<<<<<
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sectionTitle,
                                style: titleStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // ADICIONADO AQUI: Subtítulo com o nome do autor
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "Comentário de Matthew Henry",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // >>>>>>>>>>>> FIM DA MODIFICAÇÃO <<<<<<<<<<<<<<<
                        ),
                        // <<< INÍCIO DA MODIFICAÇÃO: Botões de Ação >>>
                        Row(
                          children: [
                            // Botão único para abrir o diálogo de fonte
                            IconButton(
                              icon: const Icon(Icons.format_size_outlined),
                              iconSize: 22,
                              tooltip: "Ajustar Fonte",
                              color: theme.iconTheme.color,
                              onPressed: () => _showFontSizeDialog(context),
                            ),
                            // Botão de Tradução
                            IconButton(
                              icon: Icon(Icons.translate_rounded,
                                  color: _showOriginalText
                                      ? theme.colorScheme.primary
                                      : theme.iconTheme.color),
                              tooltip: _showOriginalText
                                  ? "Ver Tradução (PT)"
                                  : "Ver Original (EN)",
                              onPressed: () {
                                setState(() =>
                                    _showOriginalText = !_showOriginalText);
                                _ttsManager.stop();
                              },
                            ),
                            // Botão de Áudio
                            IconButton(
                              icon: Icon(
                                _getAudioIcon(),
                                color: _playerState == TtsPlayerState.playing
                                    ? theme.iconTheme.color?.withOpacity(0.7)
                                    : theme.iconTheme.color?.withOpacity(0.7),
                                size: 28,
                              ),
                              tooltip: _getAudioTooltip(),
                              onPressed: _handleAudioControl,
                            ),
                          ],
                        ),
                        // <<< FIM DA MODIFICAÇÃO >>>
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.dividerColor.withOpacity(0.2)),
                  Expanded(
                    child: widget.commentaryItems.isEmpty
                        ? Center(
                            child: Text("Nenhum comentário disponível.",
                                style: theme.textTheme.bodyMedium))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(
                                20.0, 16.0, 20.0, 24.0),
                            itemCount: widget.commentaryItems.length,
                            itemBuilder: (context, index) {
                              final item = widget.commentaryItems[index];
                              final text = _showOriginalText
                                  ? (item['original'] as String? ?? '').trim()
                                  : (item['traducao'] as String? ??
                                          item['original'] as String? ??
                                          '')
                                      .trim();

                              if (text.isEmpty) return const SizedBox.shrink();

                              final chapterHighlights = viewModel
                                  .userCommentHighlights
                                  .where((h) => h['fullContext'] == text)
                                  .toList();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: SelectableText.rich(
                                  TextSpan(
                                    style: bodyStyle,
                                    // <<< 4. LÓGICA DE CONSTRUÇÃO DO TEXTO ATUALIZADA >>>
                                    children: _buildHighlightedParagraph(
                                      text,
                                      // 4a. Primeiro, gera os spans com os links clicáveis
                                      TextSpanUtils.buildTextSpansForSegment(
                                          text,
                                          theme,
                                          modalBuilderContext,
                                          baseFontSize),
                                      // 4b. Depois, passa o resultado para a função que aplica os destaques
                                      chapterHighlights,
                                      theme,
                                    ),
                                  ),
                                  textAlign: TextAlign.justify,
                                  contextMenuBuilder:
                                      (context, editableTextState) {
                                    final buttonItems = editableTextState
                                        .contextMenuButtonItems;
                                    buttonItems.insert(
                                      0,
                                      ContextMenuButtonItem(
                                        label: 'Destacar',
                                        onPressed: () {
                                          _handleHighlight(context, text,
                                              editableTextState, viewModel);
                                        },
                                      ),
                                    );
                                    return AdaptiveTextSelectionToolbar
                                        .buttonItems(
                                      anchors:
                                          editableTextState.contextMenuAnchors,
                                      buttonItems: buttonItems,
                                    );
                                  },
                                ),
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
}
