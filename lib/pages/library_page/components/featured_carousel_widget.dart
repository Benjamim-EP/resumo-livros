// lib/pages/library_page/components/featured_carousel_widget.dart

import 'package:carousel_slider/carousel_controller.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:septima_biblia/models/featured_content.dart';
import 'package:septima_biblia/pages/library_page/reading_sequence_page.dart';
import 'package:septima_biblia/pages/library_page/study_guide_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FeaturedCarouselWidget extends StatefulWidget {
  final List<FeaturedContent> items;

  const FeaturedCarouselWidget({super.key, required this.items});

  @override
  State<FeaturedCarouselWidget> createState() => _FeaturedCarouselWidgetState();
}

class _FeaturedCarouselWidgetState extends State<FeaturedCarouselWidget> {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final double? carouselHeight = kIsWeb ? 280.0 : null;
    final double carouselAspectRatio = kIsWeb ? 16 / 9 : 16 / 9;
    final double viewportFraction = kIsWeb ? 0.25 : 1.0;
    final bool enlargeCenterPage = kIsWeb
        ? true
        : false; // Era `true` para ambos, mudei para `false` no mobile para ocupar 100%

    return Column(
      children: [
        cs.CarouselSlider(
          carouselController: _carouselController,
          options: cs.CarouselOptions(
            // <<< 3. USAR AS VARIÁVEIS RESPONSIVAS >>>
            height: carouselHeight,
            aspectRatio: carouselAspectRatio,
            viewportFraction: viewportFraction,
            enlargeCenterPage: enlargeCenterPage,

            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 8),
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

        // Os indicadores de ponto (dots)
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
    void handleTap() {
      if (item.type == 'reading_sequence') {
        Navigator.push(
          context,
          FadeScalePageRoute(
            page: ReadingSequencePage(
              assetPath: item.assetPath,
              sequenceTitle: item.title,
            ),
          ),
        );
      } else if (item.type == 'study_guide') {
        Navigator.push(
          context,
          FadeScalePageRoute(
            page: StudyGuidePage(
              title: item.title,
              contentPath: item.contentPath!, // Passa o caminho do arquivo .md
              guideId: item.id, // Passa o ID para rastreamento de progresso
            ),
          ),
        );
      }
    }

    return InkWell(
      onTap: handleTap,
      child: Container(
        width: MediaQuery.of(context).size.width,
        // <<< MUDANÇA 4: Margem para o item central ampliado não cortar >>>
        margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
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
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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
      ),
    );
  }
}
