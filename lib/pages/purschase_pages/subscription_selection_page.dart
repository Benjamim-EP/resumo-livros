// lib/pages/purschase_pages/subscription_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para AppThemeOption
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// ViewModel para obter os dados necessários do store
class _ViewModel {
  final bool isLoading;
  final AppThemeOption activeTheme;

  _ViewModel({required this.isLoading, required this.activeTheme});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoading: store.state.subscriptionState.isLoading,
      activeTheme: store.state.themeState.activeThemeOption,
    );
  }
}

class SubscriptionSelectionPage extends StatelessWidget {
  const SubscriptionSelectionPage({super.key});

  static const String googlePlayMonthlyProductId = "premium_monthly_v1";
  static const String googlePlayQuarterlyProductId = "premium_quarterly_v1";

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
                // Passa a informação do tema ativo para o card Premium
                _buildPremiumPlanCard(context, theme, viewModel.activeTheme),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "As assinaturas são processadas pela Google Play Store e podem ser gerenciadas a qualquer momento nas configurações da sua conta.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
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

            // Seção de benefícios gratuitos
            _buildFeatureRow(Icons.menu_book_outlined,
                "Bíblia completa em 3 versões", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.comment_bank_outlined,
                "Comentários bíblicos selecionados", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.wb_sunny_outlined,
                "Devocionais Diários (Spurgeon)", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.format_paint_outlined,
                "Sermões de Spurgeon (+3000)", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.format_paint_outlined,
                "Marcações e notas na Bíblia no Comentário Bíblico", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(
                Icons.format_paint_outlined,
                "Promessas da Bíblia- Compêndio com todas as promessas bíblicas",
                theme),

            const Divider(height: 32),

            // Seção de limitações
            _buildLimitationRow(
                Icons.ad_units_outlined, "Anúncios durante a navegação", theme),
            const SizedBox(height: 16),
            _buildLimitationRow(
                Icons.search_off_rounded, "Buscas com custo de moedas", theme),
          ],
        ),
      ),
    );
  }

  // Card para o plano Premium
  Widget _buildPremiumPlanCard(
      BuildContext context, ThemeData theme, AppThemeOption activeTheme) {
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
              _buildSubFeatureRow("História da Igreja (+5000 pág.)", theme),
              _buildSubFeatureRow("Institutas de Turretin (+2000 pág.)", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.do_not_disturb_on_outlined,
                  "Experiência sem anúncios", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.saved_search_rounded,
                  "Busca Semântica Ilimitada", theme,
                  isHighlighted: true),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(
                  Icons.translate_rounded, "Estudo Interlinear", theme,
                  isHighlighted: true),
              _buildSubFeatureRow(
                  "Hebraico e Grego com Léxico de Strong", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.format_paint_outlined,
                  "Marcações em toda a biblioteca", theme),
              const Divider(height: 40),
              _buildPlanOptionButton(
                context,
                theme,
                title: "Assinar Plano Mensal",
                price: "R\$ 19,99 / mês",
                productId: googlePlayMonthlyProductId,
                activeTheme: activeTheme,
              ),
              const SizedBox(height: 16),
              _buildPlanOptionButton(
                context,
                theme,
                title: "Assinar Plano Trimestral",
                price: "R\$ 47,99 / 3 meses",
                productId: googlePlayQuarterlyProductId,
                activeTheme: activeTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para uma linha de benefício Gratuito (positivo)
  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline,
            color: theme.colorScheme.secondary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para uma linha de limitação (negativo)
  Widget _buildLimitationRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            color: theme.colorScheme.onSurface.withOpacity(0.5), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
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
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
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

  // >>> NOVO WIDGET para sub-item de benefício <<<
  Widget _buildSubFeatureRow(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 38.0, top: 4.0), // Indentação para alinhar com o texto
      child: Text(
        "• $text",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.75),
        ),
      ),
    );
  }

  // Widget para os botões de seleção de plano (sem alterações)
  Widget _buildPlanOptionButton(BuildContext context, ThemeData theme,
      {required String title,
      required String price,
      required String productId,
      required AppThemeOption activeTheme}) {
    final bool isGreenTheme = activeTheme == AppThemeOption.green;

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
        onTap: () {
          StoreProvider.of<AppState>(context, listen: false).dispatch(
            InitiateGooglePlaySubscriptionAction(productId: productId),
          );
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
              Icon(Icons.arrow_forward_ios_rounded, color: iconColor)
            ],
          ),
        ),
      ),
    );
  }
}
