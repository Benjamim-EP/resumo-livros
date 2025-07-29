// lib/pages/community/article_viewer_modal.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';

class ArticleViewerModal extends StatelessWidget {
  final String title;
  final String content;
  final bool isPremiumUser;
  final int characterLimit;

  const ArticleViewerModal({
    super.key,
    required this.title,
    required this.content,
    required this.isPremiumUser,
    this.characterLimit = 1000,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreview = !isPremiumUser && content.length > characterLimit;
    final truncatedContent = isPreview
        ? '${content.substring(0, min(content.length, characterLimit))}...'
        : content;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
              // "Handle" do modal
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
              // Título
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),
              // Conteúdo Markdown
              Expanded(
                child: Stack(
                  children: [
                    Markdown(
                      controller: scrollController,
                      data: truncatedContent,
                      padding: const EdgeInsets.fromLTRB(
                          20, 16, 20, 120), // Padding extra no final para o CTA
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        h3: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        h4: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Lógica para mostrar o CTA de assinatura
                    if (isPreview)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildPremiumCta(context, theme),
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

  // Widget para o Call-to-Action Premium
  Widget _buildPremiumCta(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.0),
            theme.colorScheme.surface,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text("Continue lendo com Premium"),
            onPressed: () {
              Navigator.pop(context); // Fecha o modal do artigo
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SubscriptionSelectionPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            "Assine para ter acesso completo a este e todos os outros recursos.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
