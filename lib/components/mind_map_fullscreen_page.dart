// lib/pages/components/mind_map_fullscreen_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/components/mind_map_view.dart';

class MindMapFullscreenPage extends StatelessWidget {
  final Map<String, dynamic> mapData;

  const MindMapFullscreenPage({super.key, required this.mapData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos um Stack para sobrepor o botão de fechar
      body: Stack(
        children: [
          // O mapa mental ocupa a tela inteira
          MindMapView(mapData: mapData),
          // Botão de fechar posicionado no canto superior direito
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Fechar Tela Cheia',
              child: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
