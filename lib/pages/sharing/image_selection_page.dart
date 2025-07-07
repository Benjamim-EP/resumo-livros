// lib/pages/sharing/image_selection_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/pexels_model.dart';
import 'package:septima_biblia/services/pexels_service.dart';
import 'package:septima_biblia/pages/sharing/shareable_image_generator_page.dart';

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

  @override
  void initState() {
    super.initState();
    _photosFuture = _pexelsService.getCuratedPhotos();
  }

  void _searchPhotos(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _photosFuture = _pexelsService.getCuratedPhotos();
      });
      return;
    }
    setState(() {
      _photosFuture = _pexelsService.searchPhotos(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escolha uma Imagem"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por tema (ex: céu, natureza, cruz)...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _searchPhotos,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PexelsPhoto>>(
              future: _photosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Erro ao carregar imagens."));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("Nenhuma imagem encontrada."));
                }

                final photos = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return GestureDetector(
                      onTap: () {
                        // A URL vem do nosso modelo agora, o que é mais seguro
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
                                      'Não foi possível carregar esta imagem.')));
                        }
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Image.network(
                          photo.src.medium.isNotEmpty
                              ? photo.src.medium
                              : 'https://via.placeholder.com/150', // Fallback
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                                child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null));
                          },
                          errorBuilder: (context, error, stack) => Icon(
                              Icons.broken_image,
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
