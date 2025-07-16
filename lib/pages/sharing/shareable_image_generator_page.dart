// lib/pages/sharing/shareable_image_generator_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:share_plus/share_plus.dart';

// O Enum não é mais necessário, então foi removido.

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

  double _overlayOpacity = 0.40;
  double _fontSizeScale = 1.0;
  final TransformationController _transformationController =
      TransformationController();

  final TextEditingController _signatureController = TextEditingController();

  // A variável de alinhamento não é mais necessária.

  // O initState e o dispose do _signatureController foram removidos pois o controller
  // agora é usado diretamente no TextField, que gerencia seu ciclo de vida.

  Future<void> _captureAndShareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 2.0,
      );

      if (imageBytes == null)
        throw Exception("Não foi possível capturar a imagem.");

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/septima_verse_share.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // >>> INÍCIO DA MODIFICAÇÃO <<<

      // Captura o resultado do compartilhamento
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Confira este versículo: ${widget.verseReference} #SeptimaApp',
      );

      // Registra o evento de analytics com o resultado
      // Nota: Não conseguimos saber QUAL app foi escolhido (WhatsApp, etc.) por limitações de privacidade das plataformas.
      // Mas podemos saber se foi um sucesso ou se o usuário cancelou.
      await AnalyticsService.instance.logEvent(
        name: 'app_shared',
        parameters: {
          'content_type': 'verse_image',
          'share_result_status':
              result.status.name, // Ex: 'success', 'dismissed'
          'verse_reference': widget.verseReference, // Parâmetro bônus útil
        },
      );
      print(
          "Analytics: Evento 'app_shared' registrado com status: ${result.status.name}");

      // >>> FIM DA MODIFICAÇÃO <<<
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // O widget _buildSignatureWidget não é mais necessário.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const double baseVerseFontSize = 26.0;
    const double baseReferenceFontSize = 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar e Compartilhar"),
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
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Screenshot(
                controller: _screenshotController,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.5,
                        maxScale: 4.0,
                        clipBehavior: Clip.none,
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey,
                              child:
                                  const Icon(Icons.error, color: Colors.white)),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(_overlayOpacity),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 48.0),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: Text(
                                  '"${widget.verseText}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                        baseVerseFontSize * _fontSizeScale,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black54),
                                      Shadow(
                                          blurRadius: 2.0,
                                          color: Colors.black54,
                                          offset: Offset(1, 1)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: Text(
                                  widget.verseReference,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                        baseReferenceFontSize * _fontSizeScale,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black87),
                                    ],
                                  ),
                                ),
                              ),
                              // <<< MUDANÇA: RENDERIZA A ASSINATURA AQUI, ABAIXO DO VERSÍCULO >>>
                              // O controller do TextField atualiza a UI diretamente
                              if (_signatureController.text
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 32),
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  child: Text(
                                    _signatureController.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15, // Tamanho fixo
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                      shadows: const [
                                        Shadow(
                                            blurRadius: 5.0,
                                            color: Colors.black87),
                                      ],
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),

                      // Logo com tamanho ajustado
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Text(
                          "Septima",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            // <<< MUDANÇA: TAMANHO DA LOGO REDUZIDO >>>
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration:
                BoxDecoration(color: theme.scaffoldBackgroundColor, boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _signatureController,
                  // <<< MUDANÇA: setState() para reconstruir a UI quando o texto muda >>>
                  onChanged: (text) {
                    setState(() {});
                  },
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: "Seu nome ou @usuario (opcional)",
                    isDense: true,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                // <<< REMOÇÃO: Os botões de posição e o Divider foram removidos >>>
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Icon(Icons.brightness_6_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: _overlayOpacity,
                        min: 0.0,
                        max: 0.8,
                        divisions: 8,
                        label:
                            'Escurecer: ${(_overlayOpacity * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setState(() => _overlayOpacity = value),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.format_size),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: _fontSizeScale,
                        min: 0.7,
                        max: 1.5,
                        divisions: 8,
                        label:
                            'Fonte: ${(_fontSizeScale * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setState(() => _fontSizeScale = value),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
