// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class SectionCommentaryModal extends StatefulWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> commentaryItems;
  final String bookAbbrev;
  final String bookSlug;
  final String bookName;
  final int chapterNumber;
  final String versesRangeStr;

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
  late List<bool> _showOriginalFlags;
  // Controladores para os TextFields
  final List<TextEditingController> _traducaoControllers = [];
  final List<TextEditingController> _originalControllers = [];

  @override
  void initState() {
    super.initState();
    _showOriginalFlags =
        List.generate(widget.commentaryItems.length, (_) => false);
    // Inicializar os controladores
    for (var item in widget.commentaryItems) {
      _traducaoControllers
          .add(TextEditingController(text: item['traducao'] ?? ""));
      _originalControllers
          .add(TextEditingController(text: item['original'] ?? ""));
    }
  }

  @override
  void dispose() {
    for (var controller in _traducaoControllers) {
      controller.dispose();
    }
    for (var controller in _originalControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markSelectedCommentSnippet(
    BuildContext modalContext,
    String fullCommentText,
    TextSelection selection,
  ) {
    if (selection.isCollapsed) {
      ScaffoldMessenger.of(modalContext).showSnackBar(
        const SnackBar(
            content: Text("Nenhum texto selecionado."),
            duration: Duration(seconds: 2)),
      );
      return;
    }
    final selectedSnippet =
        fullCommentText.substring(selection.start, selection.end);

    final store = StoreProvider.of<AppState>(modalContext, listen: false);

    final highlightData = {
      'selectedSnippet': selectedSnippet, // O trecho específico
      'fullCommentText': fullCommentText, // O comentário completo para contexto
      'bookAbbrev': widget.bookAbbrev,
      'bookName': widget.bookName,
      'chapterNumber': widget.chapterNumber,
      'sectionId':
          "${widget.bookSlug}_c${widget.chapterNumber}_v${widget.versesRangeStr}",
      'sectionTitle': widget.sectionTitle,
      'verseReferenceText':
          "${widget.bookName} ${widget.chapterNumber} (Seção: ${widget.sectionTitle})",
      // 'timestamp' será adicionado pelo FirestoreService/middleware
    };
    store.dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(modalContext).showSnackBar(
      const SnackBar(
          content: Text("Trecho do comentário marcado!"),
          duration: Duration(seconds: 2)),
    );
  }

  Widget _buildCommentTextField({
    required TextEditingController controller,
    required String fullCommentText,
    required BuildContext modalContext,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      showCursor: true, // Pode ser true para indicar que é selecionável
      maxLines: null, // Permite múltiplas linhas
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      decoration: const InputDecoration(
        border: InputBorder.none, // Remove a borda padrão do TextField
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      contextMenuBuilder:
          (BuildContext context, EditableTextState editableTextState) {
        final List<ContextMenuButtonItem> buttonItems =
            editableTextState.contextMenuButtonItems;
        // Adiciona o botão personalizado
        buttonItems.insert(
          0, // Insere no início do menu
          ContextMenuButtonItem(
            label: 'Marcar Trecho',
            onPressed: () {
              ContextMenuController.removeAny(); // Fecha o menu de contexto
              _markSelectedCommentSnippet(
                modalContext, // Passa o contexto do modal principal
                controller.text,
                editableTextState.textEditingValue.selection,
              );
            },
          ),
        );
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.sectionTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              Expanded(
                child: widget.commentaryItems.isEmpty
                    ? const Center(
                        child: Text(
                          "Nenhum comentário disponível para esta seção.",
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller:
                            controller, // Use o controller do DraggableScrollableSheet
                        padding: const EdgeInsets.all(16.0),
                        itemCount: widget.commentaryItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.commentaryItems[index];
                          final hasOriginal = item['original'] != null &&
                              (item['original'] as String).isNotEmpty;
                          final hasTraducao = item['traducao'] != null &&
                              (item['traducao'] as String).isNotEmpty;
                          final bool showCommentaryTitle = index == 0;

                          return Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    index < widget.commentaryItems.length - 1
                                        ? 16.0
                                        : 0.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showCommentaryTitle && hasTraducao) ...[
                                  const Text(
                                    "Comentário:",
                                    style: TextStyle(
                                      color: Color(0xFFCDE7BE),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (hasTraducao) ...[
                                  _buildCommentTextField(
                                    controller: _traducaoControllers[index],
                                    fullCommentText:
                                        _traducaoControllers[index].text,
                                    modalContext:
                                        context, // Passa o contexto do builder do modal
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (hasOriginal) ...[
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showOriginalFlags[index] =
                                            !_showOriginalFlags[index];
                                      });
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _showOriginalFlags[index]
                                              ? "Ocultar Original"
                                              : "Ver Original",
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Icon(
                                          _showOriginalFlags[index]
                                              ? Icons.arrow_drop_up
                                              : Icons.arrow_drop_down,
                                          color: Colors.amber,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_showOriginalFlags[index]) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Original:",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildCommentTextField(
                                      controller: _originalControllers[index],
                                      fullCommentText:
                                          _originalControllers[index].text,
                                      modalContext:
                                          context, // Passa o contexto do builder do modal
                                    ),
                                  ],
                                ],
                                if (!hasTraducao && !hasOriginal)
                                  const Text(
                                    "Conteúdo do comentário não disponível.",
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontStyle: FontStyle.italic),
                                  ),
                              ],
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
  }
}
