// lib/pages/user_page/comment_highlight_detail_dialog.dart
import 'package:flutter/material.dart';

class CommentHighlightDetailDialog extends StatefulWidget {
  final String referenceText;
  final String fullCommentText;
  final String selectedSnippet;
  final Color highlightColor;

  const CommentHighlightDetailDialog({
    super.key,
    required this.referenceText,
    required this.fullCommentText,
    required this.selectedSnippet,
    this.highlightColor = Colors.amber,
  });

  @override
  State<CommentHighlightDetailDialog> createState() =>
      _CommentHighlightDetailDialogState();
}

class _CommentHighlightDetailDialogState
    extends State<CommentHighlightDetailDialog> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Adiciona um callback para ser executado DEPOIS que o primeiro frame for renderizado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlight() {
    // Garante que o contexto da chave global está disponível antes de tentar o scroll
    if (_highlightKey.currentContext != null) {
      Scrollable.ensureVisible(
        _highlightKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3, // Alinha o destaque a 30% do topo da área visível
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // >>> INÍCIO DA CORREÇÃO: Mudar o tipo de retorno da função <<<
    List<InlineSpan> buildHighlightedText() {
      // >>> FIM DA CORREÇÃO <<<
      if (widget.fullCommentText.isEmpty || widget.selectedSnippet.isEmpty) {
        return [TextSpan(text: widget.fullCommentText)];
      }

      final int startIndex =
          widget.fullCommentText.indexOf(widget.selectedSnippet);

      if (startIndex == -1) {
        return [TextSpan(text: widget.fullCommentText)];
      }

      final int endIndex = startIndex + widget.selectedSnippet.length;

      final normalStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.6);
      final highlightStyle = normalStyle?.copyWith(
        // Removido o backgroundColor daqui para aplicar no Container
        fontWeight: FontWeight.bold,
      );

      return [
        TextSpan(
          text: widget.fullCommentText.substring(0, startIndex),
          style: normalStyle,
        ),
        WidgetSpan(
          alignment:
              PlaceholderAlignment.middle, // Melhora o alinhamento vertical
          child: Container(
            key: _highlightKey,
            decoration: BoxDecoration(
              color: widget.highlightColor.withOpacity(0.3),
              borderRadius:
                  BorderRadius.circular(4), // Bordas arredondadas no destaque
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 2), // Pequeno padding horizontal
            child: Text(
              widget.selectedSnippet,
              style: highlightStyle,
            ),
          ),
        ),
        TextSpan(
          text: widget.fullCommentText.substring(endIndex),
          style: normalStyle,
        ),
      ];
    }

    // >>> INÍCIO DA MODIFICAÇÃO: Layout do Dialog <<<
    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      // InsetPadding controla o espaçamento ao redor do diálogo.
      // Um valor menor faz com que ele ocupe mais espaço.
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0,
          12.0), // Remove padding do content para o divider ficar completo
      title: Text(
        widget.referenceText,
        style: theme.textTheme.titleLarge
            ?.copyWith(color: theme.colorScheme.primary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width, // Usa a largura da tela
        child: Column(
          mainAxisSize: MainAxisSize.min, // Faz a coluna encolher ao conteúdo
          children: [
            const Divider(height: 1),
            // O Flexible permite que o SingleChildScrollView ocupe o espaço restante
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24.0),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: buildHighlightedText(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    );
    // >>> FIM DA MODIFICAGÇÃO <<<
  }
}
