// lib/pages/library_page/components/featured_carousel_widget.dart

import 'package:flutter/material.dart' hide CarouselController;
// <<< CORREÇÃO 1: Adicionado o prefixo 'cs' ao import >>>
import 'package:carousel_slider/carousel_slider.dart';
import 'package:septima_biblia/models/featured_content.dart';
import 'package:septima_biblia/pages/library_page/reading_sequence_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class FeaturedCarouselWidget extends StatefulWidget {
  final List<FeaturedContent> items;

  const FeaturedCarouselWidget({super.key, required this.items});

  @override
  State<FeaturedCarouselWidget> createState() => _FeaturedCarouselWidgetState();
}

class _FeaturedCarouselWidgetState extends State<FeaturedCarouselWidget> {
  int _currentIndex = 0;
  // <<< CORREÇÃO 2: Usando o prefixo para especificar a classe correta >>>
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // <<< CORREÇÃO 3: Usando o prefixo >>>
        CarouselSlider(
          carouselController: _carouselController,
          // <<< CORREÇÃO 4: Usando o prefixo >>>
          options: CarouselOptions(
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 8),
            aspectRatio: 16 / 9,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: widget.items.map((item) {
            return Builder(
              builder: (BuildContext context) {
                return _buildCarouselItem(context, item);
              },
            );
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.items.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => _carouselController.animateToPage(entry.key),
              child: Container(
                width: 8.0,
                height: 8.0,
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black)
                      .withOpacity(_currentIndex == entry.key ? 0.9 : 0.4),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCarouselItem(BuildContext context, FeaturedContent item) {
    // Ação que será executada ao tocar no card
    void handleTap() {
      if (item.type == 'reading_sequence') {
        // Encontra o assetPath correspondente ao id do item (simulação)
        final String assetPath =
            'assets/guias/sequencia_mulheres_da_palavra.json'; // Exemplo

        Navigator.push(
          context,
          FadeScalePageRoute(
            page: ReadingSequencePage(
              assetPath: assetPath, // Passa o caminho do JSON
              sequenceTitle: item.title,
            ),
          ),
        );
      } else if (item.type == 'study_guide') {
        // Navega para a página de Guia de Estudo (que você pode criar no futuro)
        // Navigator.push(context, FadeScalePageRoute(page: StudyGuidePage(assetPath: ...)));
        print("Navegar para a página de Guia de Estudo: ${item.title}");
      }
    }

    return InkWell(
        // Envolve o Container com InkWell
        onTap: handleTap, // Define a ação de toque
        child: Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  item.featuredImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: Colors.grey.shade800);
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20.0,
                  left: 20.0,
                  right: 20.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black54)
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14.0,
                          shadows: const [
                            Shadow(blurRadius: 2, color: Colors.black)
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
