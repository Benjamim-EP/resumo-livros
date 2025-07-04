// lib/pages/purschase_pages/subscription_selection_page.dart

import 'dart:async'; // Para o Completer da lógica de compra
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Para showLoginRequiredDialog e outras ações
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para AppThemeOption
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/consts.dart'; // <<< IMPORTA SUAS CONSTANTES GLOBAIS
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/login_required.dart';

// ViewModel para obter os dados necessários do store
class _ViewModel {
  final bool isLoading; // Loading global do estado de subscrição
  final AppThemeOption activeTheme;
  final bool isGuest;

  _ViewModel({
    required this.isLoading,
    required this.activeTheme,
    required this.isGuest,
  });

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoading: store.state.subscriptionState.isLoading,
      activeTheme: store.state.themeState.activeThemeOption,
      isGuest: store.state.userState.isGuestUser,
    );
  }
}

// Convertido para StatefulWidget para gerenciar o estado de loading local
class SubscriptionSelectionPage extends StatefulWidget {
  const SubscriptionSelectionPage({super.key});

  @override
  State<SubscriptionSelectionPage> createState() =>
      _SubscriptionSelectionPageState();
}

class _SubscriptionSelectionPageState extends State<SubscriptionSelectionPage> {
  // Estado para controlar qual botão está em processo de compra
  String? _processingProductId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seja Septima Premium"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        builder: (context, viewModel) {
          // Usa o loading global do Redux como um fallback,
          // mas o loading local (_processingProductId) é mais responsivo.
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _buildFreePlanCard(context, theme),
                const SizedBox(height: 24),
                _buildPremiumPlanCard(
                    context, theme, viewModel.activeTheme, viewModel.isGuest),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "As assinaturas são processadas pela Google Play Store e podem ser gerenciadas a qualquer momento nas configurações da sua conta na Play Store.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // Card para o plano Gratuito
  Widget _buildFreePlanCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Plano Gratuito", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            _buildFeatureRow(Icons.menu_book_outlined,
                "Bíblia completa em 3 versões", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(
                Icons.comment_bank_outlined, "Comentários por seção", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(
                Icons.wb_sunny_outlined, "Devocionais Diários", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.history_edu_outlined,
                "Sermões e Roteiros de Estudo", theme),
            const Divider(height: 32),
            _buildLimitationRow(
                Icons.ad_units_outlined, "Anúncios durante a navegação", theme),
          ],
        ),
      ),
    );
  }

  // Card para o plano Premium
  Widget _buildPremiumPlanCard(BuildContext context, ThemeData theme,
      AppThemeOption activeTheme, bool isGuest) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.cardColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Premium", style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              _buildPremiumFeatureRow(Icons.all_inclusive,
                  "Tudo do plano gratuito, e mais:", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.do_not_disturb_on_outlined,
                  "Experiência sem anúncios", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(
                  Icons.translate_rounded, "Estudo Interlinear", theme,
                  isHighlighted: true),
              _buildSubFeatureRow(
                  "Hebraico e Grego com Léxico de Strong", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(
                  Icons.format_paint_outlined, "Marcações coloridas", theme),
              _buildSubFeatureRow(
                  "Destaque e adicione tags em toda a biblioteca", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.school_outlined,
                  "Conteúdo Exclusivo em Expansão", theme),
              _buildSubFeatureRow("História da Igreja (8 volumes)", theme),
              _buildSubFeatureRow("Institutas de Turretin (3 volumes)", theme),
              const Divider(height: 40),
              _buildPlanOptionButton(
                context,
                theme,
                title: "Assinar Plano Mensal",
                price: "R\$ 19,99 / mês",
                productId: googlePlayMonthlyProductId, // Constante
                activeTheme: activeTheme,
                isGuest: isGuest,
              ),
              const SizedBox(height: 16),
              _buildPlanOptionButton(
                context,
                theme,
                title: "Assinar Plano Trimestral",
                price: "R\$ 47,99 / 3 meses",
                productId: googlePlayQuarterlyProductId, // Constante
                activeTheme: activeTheme,
                isGuest: isGuest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para uma linha de benefício Gratuito
  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline,
            color: theme.colorScheme.secondary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9))),
        ),
      ],
    );
  }

  // Widget para uma linha de limitação
  Widget _buildLimitationRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            color: theme.colorScheme.onSurface.withOpacity(0.5), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7))),
        ),
      ],
    );
  }

  // Widget para uma linha de benefício Premium
  Widget _buildPremiumFeatureRow(IconData icon, String text, ThemeData theme,
      {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight:
                    isHighlighted ? FontWeight.bold : FontWeight.normal),
          ),
        ),
        if (isHighlighted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text("POPULAR",
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold)),
          )
      ],
    );
  }

  // Widget para sub-item de benefício
  Widget _buildSubFeatureRow(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 38.0, top: 4.0),
      child: Text("• $text",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.75))),
    );
  }

  // Widget para os botões de seleção de plano com a lógica de compra
  Widget _buildPlanOptionButton(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String price,
    required String productId,
    required AppThemeOption activeTheme,
    required bool isGuest,
  }) {
    final bool isGreenTheme = activeTheme == AppThemeOption.green;
    final bool isLoading = _processingProductId == productId;

    final Color titleColor;
    final Color priceColor;
    final Color backgroundColor;
    final Color iconColor;

    if (isGreenTheme) {
      backgroundColor = const Color(0xFFCDE7BE);
      titleColor = const Color(0xFF181A1A);
      priceColor = const Color(0xFF181A1A).withOpacity(0.7);
      iconColor = Colors.black54;
    } else {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      titleColor = theme.colorScheme.primary;
      priceColor = theme.colorScheme.primary.withOpacity(0.8);
      iconColor = theme.colorScheme.primary;
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading
            ? null // Desabilita o clique se estiver processando
            : () {
                if (isGuest) {
                  showLoginRequiredDialog(context,
                      featureName: "fazer uma assinatura");
                } else {
                  // Define o estado de loading localmente para este botão
                  setState(() {
                    _processingProductId = productId;
                  });
                  // Despacha a ação de compra. O middleware cuidará do resto.
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                    InitiateGooglePlaySubscriptionAction(productId: productId),
                  );
                  // O loading será removido quando o fluxo de compra terminar
                  // (seja com sucesso, erro ou cancelamento) através de uma
                  // atualização no estado de subscrição global, ou podemos
                  // resetar o _processingProductId no `dispose` ou em um `then`.
                  // Por enquanto, o middleware irá mostrar diálogos de loading.
                }
              },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: titleColor, fontWeight: FontWeight.bold)),
                    Text(price,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: priceColor)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black54,
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios_rounded, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
