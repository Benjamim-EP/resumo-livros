import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/TextFrame/markdown_viewer.dart';
import './buttons/tag_button_text.dart';
import './TextFrame/icon_counter.dart';
import './TextFrame/icon_text.dart';
import './TextFrame/topic_title.dart';

class TopicCard extends StatelessWidget {
  const TopicCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFF2D3047),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF57596C), width: 2),
      ),
      child: Stack(
        children: [
          // Icon Counters and Icons Row
          const Positioned(
            left: 234,
            top: 11,
            child: Row(
              children: [
                IconCounter(count: 28, backgroundColor: Color(0xFF939999)),
                SizedBox(width: 12),
                IconCounter(count: 21, backgroundColor: Color(0xFFEB3741)),
                SizedBox(width: 12),
                IconText(icon: Icons.bookmark, color: Color(0xFF939999)),
              ],
            ),
          ),

          // Title and Tags
          Positioned(
            left: 16,
            top: 35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopicTitle(title: 'Título do Tópico Descrevendo'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TagButtonText(
                      label: 'fé e religiao',
                      onPressed: () {
                        print('Tag "fé e religiao" clicada');
                      },
                    ),
                    const SizedBox(width: 8),
                    TagButtonText(
                      label: 'caminhada da fé',
                      onPressed: () {
                        print('Tag "caminhada da fé" clicada');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Description Section substituída por MarkdownViewer com LayoutBuilder
          Positioned(
            left: 16,
            top: 114,
            right: 16, // Adiciona espaçamento à direita
            bottom: 16, // Adiciona espaçamento na parte inferior
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: constraints
                      .maxHeight, // Restringe a altura ao máximo permitido
                  child: MarkdownViewer(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
