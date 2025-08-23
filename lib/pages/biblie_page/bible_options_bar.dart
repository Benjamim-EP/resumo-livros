// lib/pages/biblie_page/bible_options_bar.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/font_size_slider_dialog.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';

class BibleOptionsBar extends StatelessWidget {
  final String selectedTranslation1;
  final String? selectedTranslation2;
  final String? selectedBook;
  final Map<String, dynamic>? booksMap;
  final bool isCompareModeActive;
  final bool isFocusModeActive;
  final bool showHebrewInterlinear;
  final bool showGreekInterlinear;
  final double currentFontSizeMultiplier;
  final double minFontMultiplier;
  final double maxFontMultiplier;
  final bool isPremium; // Parâmetro para verificar o status de premium

  final Function(String) onTranslation1Changed;
  final Function(String) onTranslation2Changed;
  final VoidCallback onToggleCompareMode;
  final VoidCallback onToggleFocusMode;
  final VoidCallback onToggleHebrewInterlinear;
  final VoidCallback onToggleGreekInterlinear;
  final Function(double) onFontSizeChanged;

  const BibleOptionsBar({
    super.key,
    required this.selectedTranslation1,
    this.selectedTranslation2,
    required this.selectedBook,
    required this.booksMap,
    required this.isCompareModeActive,
    required this.isFocusModeActive,
    required this.showHebrewInterlinear,
    required this.showGreekInterlinear,
    required this.currentFontSizeMultiplier,
    required this.minFontMultiplier,
    required this.maxFontMultiplier,
    required this.isPremium, // Adicionado ao construtor
    required this.onTranslation1Changed,
    required this.onTranslation2Changed,
    required this.onToggleCompareMode,
    required this.onToggleFocusMode,
    required this.onToggleHebrewInterlinear,
    required this.onToggleGreekInterlinear,
    required this.onFontSizeChanged,
  });

  // Função para mostrar o diálogo de assinatura premium
  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'O estudo com Hebraico e Grego Interlinear é exclusivo para assinantes Premium. Desbloqueie este e outros recursos!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

// NOVA FUNÇÃO HELPER
  void _showFontSizeDialog(BuildContext context) {
    final double baseFontSize = 16.0;

    showDialog(
      context: context,
      builder: (context) => FontSizeSliderDialog(
        initialSize: currentFontSizeMultiplier * baseFontSize,
        minSize: minFontMultiplier * baseFontSize,
        maxSize: maxFontMultiplier * baseFontSize,
        onSizeChanged: (newAbsoluteSize) {
          final newMultiplier = newAbsoluteSize / baseFontSize;
          onFontSizeChanged(newMultiplier); // Chama a nova função diretamente
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color premiumIconColor = const Color.fromRGBO(255, 178, 44, 1);
    bool canShowHebrewToggle =
        booksMap?[selectedBook]?['testament'] == 'Antigo' &&
            !isCompareModeActive;
    bool canShowGreekToggle =
        booksMap?[selectedBook]?['testament'] == 'Novo' && !isCompareModeActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.1),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // BOTÃO 1: SELEÇÃO DE TRADUÇÃO (Principal)
          ElevatedButton.icon(
            icon: const Icon(Icons.translate, size: 18),
            label: Text(
                isCompareModeActive
                    ? '${selectedTranslation1.toUpperCase()} / ${selectedTranslation2?.toUpperCase() ?? '...'}'
                    : selectedTranslation1.toUpperCase(),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              // <<< INÍCIO DA CORREÇÃO >>>
              BiblePageWidgets.showTranslationSelection(
                context: context,
                selectedTranslation: selectedTranslation1,
                onTranslationSelected: onTranslation1Changed,
                currentSelectedBookAbbrev: selectedBook,
                booksMap: booksMap,
                isPremium: isPremium,
                onToggleCompareMode:
                    onToggleCompareMode, // Adiciona o parâmetro que faltava
              );
              // <<< FIM DA CORREÇÃO >>>
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                foregroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0),
          ),

          // BOTÃO 2: FERRAMENTAS DE VISUALIZAÇÃO (Agrupador)
          PopupMenuButton<String>(
            icon: Icon(Icons.tune_outlined, color: theme.iconTheme.color),
            tooltip: "Ferramentas de Visualização",
            onSelected: (value) {
              switch (value) {
                // <<< REMOVA O CASE 'compare' DAQUI >>>
                // case 'compare':
                //   onToggleCompareMode();
                //   break;
                case 'focus':
                  onToggleFocusMode();
                  break;
                case 'fontSize':
                  _showFontSizeDialog(context);
                  break;
                case 'hebrew':
                  isPremium
                      ? onToggleHebrewInterlinear()
                      : _showPremiumDialog(context);
                  break;
                case 'greek':
                  isPremium
                      ? onToggleGreekInterlinear()
                      : _showPremiumDialog(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'focus',
                child: ListTile(
                  leading: Icon(isFocusModeActive
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  title: Text(
                      isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura"),
                ),
              ),
              // <<< REMOVA O ITEM DO MENU DE COMPARAÇÃO DAQUI >>>
              // PopupMenuItem<String>(value: 'compare', child: ListTile(...),),
              const PopupMenuItem<String>(
                value: 'fontSize',
                child: ListTile(
                  leading: Icon(Icons.format_size_outlined),
                  title: Text('Ajustar Fonte'),
                ),
              ),
              if (canShowHebrewToggle || canShowGreekToggle)
                const PopupMenuDivider(),
              if (canShowHebrewToggle)
                PopupMenuItem<String>(
                  value: 'hebrew',
                  child: ListTile(
                    leading: Icon(Icons.font_download_outlined,
                        color: isPremium
                            ? (showHebrewInterlinear ? premiumIconColor : null)
                            : premiumIconColor),
                    title: Text('Hebraico Interlinear',
                        style: TextStyle(
                            color: isPremium ? null : premiumIconColor)),
                  ),
                ),
              if (canShowGreekToggle)
                PopupMenuItem<String>(
                  value: 'greek',
                  child: ListTile(
                    leading: Icon(Icons.font_download_outlined,
                        color: isPremium
                            ? (showGreekInterlinear ? premiumIconColor : null)
                            : premiumIconColor),
                    title: Text('Grego Interlinear',
                        style: TextStyle(
                            color: isPremium ? null : premiumIconColor)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
