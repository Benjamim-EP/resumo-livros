// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

// ViewModel para o StoreConnector
class _CommentaryModalViewModel {
  final List<Map<String, dynamic>> userCommentHighlights;
  // Não precisamos mais do sectionId aqui se o filtro for feito no StoreConnector
  // ou se passarmos a lista já filtrada.
  // Para simplificar, vamos assumir que o StoreConnector no build fará o filtro.

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
  final List<Map<String, dynamic>>
      commentaryItems; // Cada item é um mapa com 'original' e 'traducao'
  final String bookAbbrev;
  final String bookSlug; // Usado para construir o sectionId para destaques
  final String bookName;
  final int chapterNumber;
  final String
      versesRangeStr; // Usado para construir o sectionId para destaques

  const SectionCommentaryModal({
    super.key,
    required this.sectionTitle,
    required this.commentaryItems,
    required this.bookAbbrev,
    required this.bookSlug,
    required this.bookName,
    required this.chapterNumber,
    required this.versesRangeStr,
  });

  @override
  State<SectionCommentaryModal> createState() => _SectionCommentaryModalState();
}

class _SectionCommentaryModalState extends State<SectionCommentaryModal> {
  bool _showOriginalText =
      false; // Controla se o texto original (inglês) é exibido

  // Helper getter para construir o ID da seção atual, usado para filtrar e salvar destaques
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
              ? (item['original'] as String? ?? "")
                  .trim() // Mostra original se _showOriginalText for true
              : (item['traducao'] as String? ??
                      item['original'] as String? ??
                      "")
                  .trim(); // Prioriza tradução

          return textToShow;
        })
        .where((text) => text.isNotEmpty)
        .join("\n\n\n"); // Usar um separador mais distinto se necessário
  }

  void _markSelectedCommentSnippet(
    BuildContext
        passedContext, // Contexto vindo do builder do StoreConnector ou do contextMenuBuilder
    String fullCommentText,
    TextSelection selection,
  ) {
    if (selection.isCollapsed) {
      // Tenta usar o ScaffoldMessenger do contexto mais próximo que tem um Scaffold
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(passedContext);
      if (scaffoldMessenger != null && mounted) {
        // Verifica se o widget ainda está montado
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text("Nenhum texto selecionado."),
              duration: Duration(seconds: 2)),
        );
      } else {
        print(
            "WARN: Não foi possível mostrar SnackBar (nenhum texto selecionado) - ScaffoldMessenger não encontrado ou widget desmontado.");
      }
      return;
    }
    final selectedSnippet =
        fullCommentText.substring(selection.start, selection.end);

    // Usa o StoreProvider com o contexto que tem acesso ao Store
    // O 'context' do build do StoreConnector é uma boa escolha
    final store = StoreProvider.of<AppState>(passedContext, listen: false);

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
      'language': _showOriginalText ? 'en' : 'pt', // Idioma do texto destacado
    };

    store.dispatch(AddCommentHighlightAction(highlightData));

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(passedContext);
    if (scaffoldMessenger != null && mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text("Trecho do comentário marcado!"),
            duration: Duration(seconds: 2)),
      );
    } else {
      print(
          "WARN: Não foi possível mostrar SnackBar (trecho marcado) - ScaffoldMessenger não encontrado ou widget desmontado.");
    }
  }

  List<TextSpan> _buildTextSpansWithHighlights(
      String fullText,
      List<Map<String, dynamic>>
          allUserHighlights, // Todos os destaques do usuário
      String currentSectionId, // ID da seção atual para filtrar
      ThemeData theme) {
    if (fullText.isEmpty) return [const TextSpan(text: "")];

    // 1. Filtra os destaques para esta seção e idioma
    List<Map<String, dynamic>> relevantHighlightsForSectionAndLang =
        allUserHighlights.where((h) {
      final String? hSectionId = h['sectionId'] as String?;
      final String? hLang = h['language'] as String?;
      bool langMatch = _showOriginalText
          ? (hLang == 'en')
          : (hLang == 'pt' || hLang == null); // Se lang for null, assume pt
      return hSectionId == currentSectionId && langMatch;
    }).toList();

    if (relevantHighlightsForSectionAndLang.isEmpty) {
      return [TextSpan(text: fullText)]; // Sem destaques para mostrar
    }

    // 2. Encontra todas as ocorrências dos snippets destacados
    List<Map<String, dynamic>> occurrences = [];
    for (var highlight in relevantHighlightsForSectionAndLang) {
      final String snippet = highlight['selectedSnippet'] as String;
      if (snippet.isEmpty) continue;

      int startIndex = 0;
      while (startIndex < fullText.length) {
        final int pos = fullText.indexOf(snippet, startIndex);
        if (pos == -1) break;
        occurrences.add({
          'start': pos,
          'end': pos + snippet.length,
          'text': snippet, // O texto do snippet para o TextSpan
          // Adicionar o ID do highlight se precisar deletar/modificar um destaque específico no futuro
          'highlightId': highlight['id'] as String? ?? ''
        });
        startIndex = pos +
            snippet.length; // Evita sobreposições infinitas do mesmo snippet
      }
    }

    if (occurrences.isEmpty) return [TextSpan(text: fullText)];

    // 3. Ordenar ocorrências pela posição inicial e depois pelo final (para lidar com aninhamento, o mais longo primeiro)
    occurrences.sort((a, b) {
      int startCompare = (a['start'] as int).compareTo(b['start'] as int);
      if (startCompare != 0) return startCompare;
      return (b['end'] as int)
          .compareTo(a['end'] as int); // Destaque mais longo primeiro
    });

    // 4. Resolver sobreposições (simples: o primeiro na lista ordenada vence se houver sobreposição)
    List<Map<String, dynamic>> finalHighlightsToRender = [];
    int lastProcessedEnd = -1;
    for (var occ in occurrences) {
      if ((occ['start'] as int) >= lastProcessedEnd) {
        finalHighlightsToRender.add(occ);
        lastProcessedEnd = occ['end'] as int;
      }
    }

    // 5. Construir TextSpans
    List<TextSpan> spans = [];
    int currentTextPosition = 0;
    for (var highlightSpanData in finalHighlightsToRender) {
      final int start = highlightSpanData['start'];
      final int end = highlightSpanData['end'];
      final String snippetText = highlightSpanData['text'];

      if (start > currentTextPosition) {
        spans.add(
            TextSpan(text: fullText.substring(currentTextPosition, start)));
      }
      spans.add(
        TextSpan(
          text: snippetText,
          style: TextStyle(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.35),
            color: theme.colorScheme
                .onPrimaryContainer, // Ajuste se necessário para contraste
          ),
          // Aqui você poderia adicionar um LongPressGestureRecognizer se quisesse
          // permitir que o usuário interagisse com um trecho já destacado (ex: para remover o destaque)
          // recognizer: LongPressGestureRecognizer()..onLongPress = () {
          //   print("Destaque '${highlightSpanData['highlightId']}' pressionado longamente!");
          //   // Implementar lógica para remover/editar destaque
          // },
        ),
      );
      currentTextPosition = end;
    }

    if (currentTextPosition < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(currentTextPosition)));
    }

    return spans.isEmpty ? [const TextSpan(text: "")] : spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Não chame _getCombinedCommentaryText aqui ainda, pois o StoreConnector precisa ser construído primeiro
    // para que o viewModel.userCommentHighlights esteja disponível para _buildTextSpansWithHighlights.

    return StoreConnector<AppState, _CommentaryModalViewModel>(
        converter: (store) => _CommentaryModalViewModel.fromStore(
            store), // Passa todos os destaques
        builder: (context, viewModel) {
          // viewModel agora é _CommentaryModalViewModel

          // Chame _getCombinedCommentaryText DENTRO do builder, após ter acesso ao viewModel se necessário
          // (embora esta função não use o viewModel diretamente, é bom manter a lógica de dados junta).
          final String combinedText = _getCombinedCommentaryText();

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
                        crossAxisAlignment: CrossAxisAlignment
                            .center, // Alinhado ao centro verticalmente
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
                              Icons.translate_rounded, // Ícone mais sugestivo
                              size: 24, // Tamanho um pouco maior
                              color: _showOriginalText
                                  ? theme.colorScheme.primary
                                  : theme.iconTheme.color?.withOpacity(0.8),
                            ),
                            tooltip: _showOriginalText
                                ? "Ver Tradução (PT)"
                                : "Ver Original (EN)",
                            onPressed: () {
                              setState(() {
                                _showOriginalText = !_showOriginalText;
                              });
                            },
                            splashRadius: 22,
                            padding: const EdgeInsets.all(
                                10), // Padding para área de toque
                          )
                        ],
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: theme.dividerColor
                            .withOpacity(0.3)), // Divisor mais sutil

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
                                  16.0, 12.0, 16.0, 16.0), // Ajuste de padding
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: SelectableText.rich(
                                  TextSpan(
                                      children: _buildTextSpansWithHighlights(
                                          combinedText,
                                          viewModel
                                              .userCommentHighlights, // Destaques do usuário (todos)
                                          currentSectionIdForHighlights, // ID da seção atual
                                          theme),
                                      // Estilo base para o texto não destacado
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onBackground,
                                        height:
                                            1.65, // Aumentado para melhor legibilidade
                                        fontSize: 15.5, // Ajuste fino
                                      )),
                                  textAlign: TextAlign.justify,
                                  contextMenuBuilder: (BuildContext menuContext,
                                      EditableTextState editableTextState) {
                                    final List<ContextMenuButtonItem>
                                        buttonItems = editableTextState
                                            .contextMenuButtonItems;
                                    final currentTextSelection =
                                        editableTextState
                                            .textEditingValue.selection;

                                    if (!currentTextSelection.isCollapsed) {
                                      buttonItems.insert(
                                        0,
                                        ContextMenuButtonItem(
                                          label: 'Marcar Trecho',
                                          onPressed: () {
                                            ContextMenuController.removeAny();
                                            _markSelectedCommentSnippet(
                                              context, // Usa o context do builder do StoreConnector (que tem acesso ao Store)
                                              combinedText,
                                              currentTextSelection,
                                            );
                                          },
                                        ),
                                      );
                                    }
                                    // Você pode adicionar mais botões aqui, como "Copiar", "Pesquisar", etc.
                                    // buttonItems.add(ContextMenuButtonItem(label: "Copiar", onPressed: (){...}));

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
        });
  }
}
