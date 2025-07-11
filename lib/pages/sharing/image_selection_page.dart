// lib/pages/sharing/image_selection_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/pexels_model.dart';
import 'package:septima_biblia/services/pexels_service.dart';
import 'package:septima_biblia/pages/sharing/shareable_image_generator_page.dart';
import 'package:septima_biblia/services/translation_service.dart'; // Importa o serviço de tradução

class ImageSelectionPage extends StatefulWidget {
  final String verseText;
  final String verseReference;

  const ImageSelectionPage({
    super.key,
    required this.verseText,
    required this.verseReference,
  });

  @override
  State<ImageSelectionPage> createState() => _ImageSelectionPageState();
}

class _ImageSelectionPageState extends State<ImageSelectionPage> {
  final PexelsService _pexelsService = PexelsService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<PexelsPhoto>> _photosFuture;

  // Instancia o serviço de tradução
  final TranslationService _translationService = TranslationService();
  bool _isTranslatingAndSearching = false; // Para mostrar feedback de loading

  @override
  void initState() {
    super.initState();
    // Inicia com as fotos curadas (populares)
    _photosFuture = _pexelsService.getCuratedPhotos();
  }

  /// Inicia a busca de fotos. Traduz a query para o inglês antes de consultar a API Pexels.
  void _searchPhotos(String query) async {
    // Se a busca estiver vazia, volta para as fotos curadas
    if (query.trim().isEmpty) {
      setState(() {
        _photosFuture = _pexelsService.getCuratedPhotos();
      });
      return;
    }

    // Ativa o indicador de loading na UI
    if (mounted) {
      setState(() {
        _isTranslatingAndSearching = true;
      });
    }

    try {
      // Traduz o termo de busca para o inglês
      final String translatedQuery =
          await _translationService.translateText(query);

      // Atualiza o Future para que o FutureBuilder reconstrua com os novos resultados
      if (mounted) {
        setState(() {
          _photosFuture = _pexelsService.searchPhotos(translatedQuery);
        });
      }
    } finally {
      // Garante que o loading seja desativado, mesmo em caso de erro
      if (mounted) {
        setState(() {
          _isTranslatingAndSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _translationService.dispose(); // Libera os recursos do tradutor
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escolha uma Imagem de Fundo"),
      ),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por tema (ex: céu, natureza, cruz)...',
                prefixIcon: const Icon(Icons.search),
                // Mostra um indicador de progresso enquanto traduz e busca
                suffixIcon: _isTranslatingAndSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // Desabilita o campo enquanto uma busca está em andamento
              onSubmitted: _isTranslatingAndSearching ? null : _searchPhotos,
            ),
          ),
          // Grade de imagens
          Expanded(
            child: FutureBuilder<List<PexelsPhoto>>(
              future: _photosFuture,
              builder: (context, snapshot) {
                // Estado de carregamento
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Estado de erro
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Ocorreu um erro ao carregar as imagens. Tente novamente.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                // Estado sem dados
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhuma imagem encontrada para sua busca.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Estado de sucesso
                final photos = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Duas colunas
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return GestureDetector(
                      onTap: () {
                        // Usa a URL da imagem de alta qualidade
                        final imageUrl = photo.src.large2x;
                        if (imageUrl.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShareableImageGeneratorPage(
                                verseText: widget.verseText,
                                verseReference: widget.verseReference,
                                imageUrl: imageUrl,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Não foi possível carregar esta imagem.')),
                          );
                        }
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: Image.network(
                          photo.src.medium, // URL da imagem para a miniatura
                          fit: BoxFit.cover,
                          // Mostra um placeholder de carregamento para cada imagem
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2.5,
                              ),
                            );
                          },
                          // Mostra um ícone de erro se a imagem falhar
                          errorBuilder: (context, error, stack) => Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.error),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
