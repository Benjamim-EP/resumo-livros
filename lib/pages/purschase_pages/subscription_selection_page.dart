// lib/pages/purschase_pages/subscription_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';
// Remova a importação de consts.dart se os IDs de produto vierem de outro lugar ou direto aqui
// import 'package:resumo_dos_deuses_flutter/consts.dart';

class SubscriptionSelectionPage extends StatelessWidget {
  const SubscriptionSelectionPage({super.key});

  // Defina seus Product IDs do Google Play Console aqui
  static const String googlePlayMonthlyProductId =
      "seu_id_mensal_google_play"; // Ex: "premium_monthly_v1"
  static const String googlePlayQuarterlyProductId =
      "seu_id_trimestral_google_play"; // Ex: "premium_quarterly_v1"
  // Adicione outros IDs de produto se necessário

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escolha seu Plano Premium"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: StoreConnector<AppState, bool>(
        // Conecta ao isLoading do SubscriptionState
        converter: (store) => store.state.subscriptionState.isLoading,
        builder: (context, isLoading) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              // Usando ListView para o caso de ter muitos planos
              children: [
                _buildPlanCard(
                  context: context,
                  title: "Plano Mensal (Google Play)",
                  price:
                      "R\$19,99/mês", // O preço real será exibido pelo Google Play
                  description:
                      "Acesso premium por 1 mês, renovado automaticamente.",
                  productId: googlePlayMonthlyProductId,
                ),
                const SizedBox(height: 16),
                _buildPlanCard(
                  context: context,
                  title: "Plano Trimestral (Google Play)",
                  price:
                      "R\$47,97 / 3 meses", // O preço real será exibido pelo Google Play
                  description:
                      "Pagamento único para 3 meses de acesso premium.",
                  productId: googlePlayQuarterlyProductId,
                ),
                // Adicione mais planos se necessário
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required String description,
    required String productId,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: theme.colorScheme.primaryContainer, // Usando cores do tema
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        // Para dar feedback visual ao toque
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          print('>>> UI: Botão Assinatura Google Play $productId clicado!');
          StoreProvider.of<AppState>(context, listen: false).dispatch(
            InitiateGooglePlaySubscriptionAction(productId: productId),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withOpacity(0.8))),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(price,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
