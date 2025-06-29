// lib/pages/biblie_page/bible_options_bar.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
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
  final VoidCallback onIncreaseFontSize;
  final VoidCallback onDecreaseFontSize;

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
    required this.onIncreaseFontSize,
    required this.onDecreaseFontSize,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color premiumIconColor = const Color.fromRGBO(255, 178, 44, 1);

    bool canShowHebrewToggle =
        booksMap?[selectedBook]?['testament'] == 'Antigo' &&
            selectedTranslation1 != 'hebrew_original' &&
            !isCompareModeActive;

    bool canShowGreekToggle = booksMap?[selectedBook]?['testament'] == 'Novo' &&
        selectedTranslation1 != 'greek_interlinear' &&
        !isCompareModeActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.1),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          // Botão para selecionar a Tradução 1
          ElevatedButton.icon(
            icon: const Icon(Icons.translate, size: 18),
            label: Text(selectedTranslation1.toUpperCase(),
                style: const TextStyle(fontSize: 12)),
            onPressed: () {
              BiblePageWidgets.showTranslationSelection(
                context: context,
                selectedTranslation: selectedTranslation1,
                onTranslationSelected: onTranslation1Changed,
                currentSelectedBookAbbrev: selectedBook,
                booksMap: booksMap,
                isPremium: isPremium,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1),
          ),

          // Botão para selecionar a Tradução 2 (se estiver no modo de comparação)
          if (isCompareModeActive)
            ElevatedButton.icon(
              icon: const Icon(Icons.translate, size: 18),
              label: Text(selectedTranslation2?.toUpperCase() ?? '...',
                  style: const TextStyle(fontSize: 12)),
              onPressed: () {
                BiblePageWidgets.showTranslationSelection(
                    context: context,
                    selectedTranslation: selectedTranslation2 ?? 'acf',
                    onTranslationSelected: onTranslation2Changed,
                    currentSelectedBookAbbrev: selectedBook,
                    booksMap: booksMap,
                    isPremium: isPremium);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.cardColor,
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 1),
            ),

          // Botão de Estudos
          ElevatedButton.icon(
            icon: const Icon(Icons.school_outlined, size: 18),
            label: const Text("Estudos", style: TextStyle(fontSize: 12)),
            onPressed: () {
              interstitialManager
                  .tryShowInterstitial(fromScreen: "BiblePage_To_StudyHub")
                  .then((_) {
                if (context.mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const StudyHubPage()));
                }
              });
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1),
          ),

          // Botão Modo Foco
          IconButton(
            icon: Icon(
                isFocusModeActive ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 22),
            tooltip: isFocusModeActive ? "Sair do Modo Foco" : "Modo Leitura",
            onPressed: onToggleFocusMode,
            color: isFocusModeActive
                ? theme.colorScheme.secondary
                : theme.iconTheme.color,
            splashRadius: 20,
          ),

          // Botão Modo Comparação
          IconButton(
            icon: Icon(
                isCompareModeActive
                    ? Icons.compare_arrows
                    : Icons.compare_arrows_outlined,
                size: 22),
            tooltip: isCompareModeActive
                ? "Desativar Comparação"
                : "Comparar Traduções",
            onPressed: onToggleCompareMode,
            color: isCompareModeActive
                ? theme.colorScheme.secondary
                : theme.iconTheme.color,
            splashRadius: 20,
          ),

          // Botão Toggle Hebraico Interlinear
          if (canShowHebrewToggle)
            IconButton(
              icon: Icon(
                  showHebrewInterlinear
                      ? Icons.font_download_off_outlined
                      : Icons.font_download_outlined,
                  size: 22),
              tooltip: "Hebraico Interlinear (Premium)",
              onPressed: () {
                if (isPremium) {
                  onToggleHebrewInterlinear();
                } else {
                  _showPremiumDialog(context);
                }
              },
              color: isPremium
                  ? (showHebrewInterlinear
                      ? premiumIconColor
                      : theme.iconTheme.color)
                  : premiumIconColor.withOpacity(1),
              splashRadius: 20,
            ),

          // Botão Toggle Grego Interlinear
          if (canShowGreekToggle)
            IconButton(
              icon: Icon(
                  showGreekInterlinear
                      ? Icons.font_download_off_outlined
                      : Icons.font_download_outlined,
                  size: 22),
              tooltip: "Grego Interlinear (Premium)",
              onPressed: () {
                if (isPremium) {
                  onToggleGreekInterlinear();
                } else {
                  _showPremiumDialog(context);
                }
              },
              color: isPremium
                  ? (showGreekInterlinear
                      ? premiumIconColor
                      : theme.iconTheme.color)
                  : premiumIconColor.withOpacity(1),
              splashRadius: 20,
            ),

          // Botões para Tamanho da Fonte
          IconButton(
            icon: const Icon(Icons.text_decrease_outlined, size: 22),
            tooltip: "Diminuir Fonte",
            onPressed: currentFontSizeMultiplier > minFontMultiplier
                ? onDecreaseFontSize
                : null,
            color: currentFontSizeMultiplier > minFontMultiplier
                ? theme.iconTheme.color
                : theme.disabledColor,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_outlined, size: 22),
            tooltip: "Aumentar Fonte",
            onPressed: currentFontSizeMultiplier < maxFontMultiplier
                ? onIncreaseFontSize
                : null,
            color: currentFontSizeMultiplier < maxFontMultiplier
                ? theme.iconTheme.color
                : theme.disabledColor,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
