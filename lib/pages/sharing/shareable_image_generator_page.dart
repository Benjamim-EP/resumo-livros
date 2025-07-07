// lib/pages/sharing/shareable_image_generator_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ShareableImageGeneratorPage extends StatefulWidget {
  final String verseText;
  final String verseReference;
  final String imageUrl;

  const ShareableImageGeneratorPage({
    super.key,
    required this.verseText,
    required this.verseReference,
    required this.imageUrl,
  });

  @override
  State<ShareableImageGeneratorPage> createState() =>
      _ShareableImageGeneratorPageState();
}

class _ShareableImageGeneratorPageState
    extends State<ShareableImageGeneratorPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _captureAndShareImage() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 2.0, // Aumenta a resolução da imagem final
      );

      if (imageBytes == null) {
        throw Exception("Não foi possível capturar a imagem.");
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/septima_verse_share.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Confira este versículo: ${widget.verseReference} #SeptimaApp',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pré-visualização"),
        actions: [
          _isSharing
              ? const Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5))))
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: "Compartilhar",
                  onPressed: _captureAndShareImage,
                )
        ],
      ),
      body: Center(
        child: Screenshot(
          controller: _screenshotController,
          child: AspectRatio(
            aspectRatio: 9 / 16, // Proporção de story (vertical)
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagem de Fundo
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                      color: Colors.grey,
                      child: const Icon(Icons.error, color: Colors.white)),
                ),
                // Overlay para Contraste
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.40),
                  ),
                ),
                // Conteúdo de Texto
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '"${widget.verseText}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          shadows: [
                            Shadow(blurRadius: 10.0, color: Colors.black54),
                            Shadow(
                                blurRadius: 2.0,
                                color: Colors.black54,
                                offset: Offset(1, 1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.verseReference,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(blurRadius: 8.0, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sua logo (opcional)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Text(
                    "Septima",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
