// lib/pages/library_page/resource_detail_modal.dart
import 'package:flutter/material.dart';

class ResourceDetailModal extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onStartReading;

  const ResourceDetailModal({
    super.key,
    required this.itemData,
    required this.onStartReading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = itemData['title'] ?? 'Sem Título';
    final String author = itemData['author'] ?? 'Desconhecido';
    final String description = itemData['description'] ?? 'Sem descrição.';
    final String pageCount = itemData['pageCount'] ?? '';
    final String coverPath = itemData['coverImagePath'] ?? '';
    final ImageProvider? coverImage =
        coverPath.isNotEmpty ? AssetImage(coverPath) : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // "Handle" do modal
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(10))),
              ),
              // Conteúdo do Modal
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // ✅ 1. CAPA DO LIVRO CENTRALIZADA E MAIOR
                    Center(
                      child: Card(
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: 220, // Altura maior para a capa
                          child: coverImage != null
                              ? Image(image: coverImage, fit: BoxFit.cover)
                              : Container(
                                  width: 150,
                                  color: theme.colorScheme.surfaceVariant,
                                  child: const Icon(Icons.book, size: 50),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ 2. TÍTULO E AUTOR ABAIXO DA CAPA
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "por $author",
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.hintColor, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 32),

                    // ✅ 3. DESCRIÇÃO E OUTRAS INFORMAÇÕES
                    Text(
                      description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          color: theme.textTheme.bodyLarge?.color
                              ?.withOpacity(0.8)),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 24),

                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 16),
                      label: Text(pageCount),
                    ),
                    const SizedBox(height: 32),

                    // Botão de Ação
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: const Text("Começar a Ler"),
                        onPressed: onStartReading,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
