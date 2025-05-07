// lib/pages/biblie_page/section_commentary_modal.dart
import 'package:flutter/material.dart';

class SectionCommentaryModal extends StatefulWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> commentaryItems;

  const SectionCommentaryModal({
    Key? key,
    required this.sectionTitle,
    required this.commentaryItems,
  }) : super(key: key);

  @override
  State<SectionCommentaryModal> createState() => _SectionCommentaryModalState();
}

class _SectionCommentaryModalState extends State<SectionCommentaryModal> {
  late List<bool> _showOriginalFlags;

  @override
  void initState() {
    super.initState();
    _showOriginalFlags =
        List.generate(widget.commentaryItems.length, (_) => false);
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
                        // <<< Alterado para ListView.builder
                        controller: controller,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: widget.commentaryItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.commentaryItems[index];
                          final hasOriginal = item['original'] != null &&
                              (item['original'] as String).isNotEmpty;
                          final hasTraducao = item['traducao'] != null &&
                              (item['traducao'] as String).isNotEmpty;

                          // <<< MODIFICAÇÃO: Define se o título "Comentário:" deve ser mostrado >>>
                          final bool showCommentaryTitle = index == 0;
                          // <<< FIM MODIFICAÇÃO >>>

                          return Padding(
                            // Adiciona padding entre os parágrafos do comentário
                            padding: EdgeInsets.only(
                                bottom:
                                    index < widget.commentaryItems.length - 1
                                        ? 16.0
                                        : 0.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // <<< MODIFICAÇÃO: Condicional para o título "Comentário:" >>>
                                if (showCommentaryTitle && hasTraducao) ...[
                                  const Text(
                                    "Comentário:", // Título genérico
                                    style: TextStyle(
                                      color: Color(0xFFCDE7BE),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                // <<< FIM MODIFICAÇÃO >>>
                                if (hasTraducao) ...[
                                  Text(
                                    item['traducao'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5),
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
                                    Text(
                                      item['original'],
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.4),
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
