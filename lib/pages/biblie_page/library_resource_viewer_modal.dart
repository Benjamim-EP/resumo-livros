// lib/pages/biblie_page/library_resource_viewer_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// O modal agora é mais simples e recebe os dados prontos
class LibraryResourceViewerModal extends StatelessWidget {
  final String title;
  final List<String> path;
  final String content;

  const LibraryResourceViewerModal({
    super.key,
    required this.title,
    required this.path,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        borderRadius: BorderRadius.circular(10))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                child: Column(
                  children: [
                    Text(title,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(path.join(' > '),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Markdown(
                  controller: scrollController,
                  data: content,
                  padding: const EdgeInsets.all(20.0),
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
