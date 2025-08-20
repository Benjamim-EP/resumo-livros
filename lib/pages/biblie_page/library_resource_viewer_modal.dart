// lib/pages/biblie_page/library_resource_viewer_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/services/library_content_service.dart';

class LibraryResourceViewerModal extends StatefulWidget {
  final String contentId;

  const LibraryResourceViewerModal({
    super.key,
    required this.contentId,
  });

  @override
  State<LibraryResourceViewerModal> createState() =>
      _LibraryResourceViewerModalState();
}

class _LibraryResourceViewerModalState
    extends State<LibraryResourceViewerModal> {
  // Estado para controlar o carregamento e os dados
  bool _isLoading = true;
  ContentUnitPreview? _contentPreview;
  String? _fullContent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      // Busca os dois conjuntos de dados em paralelo para mais eficiência
      final results = await Future.wait([
        LibraryContentService.instance.getContentUnitPreview(widget.contentId),
        LibraryContentService.instance.getFullContent(widget.contentId),
      ]);

      if (mounted) {
        setState(() {
          _contentPreview = results[0] as ContentUnitPreview?;
          _fullContent = results[1] as String?;
          _isLoading = false;
          if (_contentPreview == null || _fullContent == null) {
            _error = "Não foi possível carregar o conteúdo do recurso.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Ocorreu um erro ao carregar o recurso.";
          _isLoading = false;
        });
      }
    }
  }

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
              // Cabeçalho - mostra os dados de preview quando disponíveis
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                child: Column(
                  children: [
                    Text(
                      _contentPreview?.title ??
                          (_isLoading ? "Carregando..." : "Erro"),
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (_contentPreview != null) ...[
                      const SizedBox(height: 4),
                      Text(_contentPreview!.path,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center),
                    ]
                  ],
                ),
              ),
              const Divider(height: 1),

              // Corpo - mostra o conteúdo ou o estado de loading/erro
              Expanded(
                child: _buildBodyContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_fullContent != null) {
      return Markdown(
        controller: scrollController,
        data: _fullContent!,
        padding: const EdgeInsets.all(20.0),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
      );
    }
    return const Center(child: Text("Conteúdo não disponível."));
  }
}
