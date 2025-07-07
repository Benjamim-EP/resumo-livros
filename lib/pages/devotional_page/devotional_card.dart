// lib/pages/devotional_page/devotional_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/devotional_model.dart';

class DevotionalCard extends StatefulWidget {
  final DevotionalReading reading;
  final bool isRead;
  final VoidCallback onMarkAsRead;
  final VoidCallback onPlay;

  const DevotionalCard({
    super.key,
    required this.reading,
    required this.isRead,
    required this.onMarkAsRead,
    required this.onPlay,
  });

  @override
  State<DevotionalCard> createState() => _DevotionalCardState();
}

class _DevotionalCardState extends State<DevotionalCard>
    with SingleTickerProviderStateMixin {
  // Notificador para saber se o tile está expandido ou não.
  final ValueNotifier<bool> _isExpanded = ValueNotifier(false);

  // Controladores para a animação de "pulsar" do ícone.
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Configuração do controlador da animação.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true); // Faz a animação repetir (ida e volta).

    // Define a curva da animação (escala de 1.0 para 1.3).
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    // É crucial descartar os controladores para liberar recursos.
    _animationController.dispose();
    _isExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMorning = widget.reading.title.toLowerCase().contains('manhã');

    return Stack(
      // Permite que o ícone posicionado "vaze" para fora da área do Stack.
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // 1. O CARD PRINCIPAL COM O CONTEÚDO
        Card(
          elevation: 2,
          // A margem inferior foi removida para que o ícone possa se sobrepor.
          // A margem vertical geral será controlada pelo ListView que usa este card.
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: widget.isRead
                  ? theme.colorScheme.primary.withOpacity(0.6)
                  : theme.dividerColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey(widget.reading.title),
            // Atualiza o estado de expansão quando o usuário clica.
            onExpansionChanged: (bool expanded) {
              _isExpanded.value = expanded;
            },
            // --- Conteúdo do cabeçalho do card (visível quando recolhido) ---
            title: Row(
              children: [
                Icon(
                  isMorning ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.reading.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                widget.reading.scriptureVerse,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              tooltip: "Ouvir Devocional",
              onPressed: widget.onPlay,
            ),
            backgroundColor: theme.cardColor.withOpacity(0.5),
            collapsedBackgroundColor: theme.cardColor.withOpacity(0.8),
            iconColor: theme.colorScheme.secondary,
            collapsedIconColor: theme.colorScheme.secondary.withOpacity(0.7),
            // --- Conteúdo que aparece quando o card é expandido ---
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 16),
                    Text(
                      "Referência: ${widget.reading.scripturePassage}",
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    ...widget.reading.content.map((paragraph) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RichText(
                            textAlign: TextAlign.justify,
                            text: TextSpan(
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.6),
                              children: [TextSpan(text: paragraph)],
                            ),
                          ),
                        )),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(
                          widget.isRead
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: widget.isRead
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                        label:
                            Text(widget.isRead ? "Lido" : "Marcar como lido"),
                        style: TextButton.styleFrom(
                          foregroundColor: widget.isRead
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodySmall?.color,
                        ),
                        onPressed: widget.onMarkAsRead,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),

        // 2. O ÍCONE ANIMADO DE EXPANSÃO (sobreposto)
        Positioned(
          bottom:
              0, // Posiciona na borda inferior do Card, com um pequeno deslocamento para fora.
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isExpanded,
              builder: (context, isExpanded, child) {
                return AnimatedOpacity(
                  opacity: isExpanded ? 0.0 : 1.0, // Some quando expandido
                  duration: const Duration(milliseconds: 1200),
                  child: ScaleTransition(
                    scale: _scaleAnimation, // Aplica a animação de pulsar
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.primary.withOpacity(0.9),
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
