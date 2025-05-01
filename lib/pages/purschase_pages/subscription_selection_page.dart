import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
// Removido: import 'package:resumo_dos_deuses_flutter/services/stripe_service.dart'; // Não chama mais diretamente
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Importa a ação
import 'package:resumo_dos_deuses_flutter/consts.dart'; // Para os IDs de preço

class SubscriptionSelectionPage extends StatelessWidget {
  const SubscriptionSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escolha seu Plano Premium"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Colors.black, // Usa cor do tema
      ),
      body: StoreConnector<AppState, Map<String, String?>>(
        // Apenas para ler dados do user se necessário, mas não mais usado aqui
        converter: (store) => {
          // Não precisamos mais converter dados do usuário aqui,
          // o middleware pegará do store.
        },
        builder: (context, userData) {
          // Não precisamos mais de userData diretamente aqui

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPlanCard(
                  context: context, // Passa o contexto
                  title: "Plano Mensal",
                  price: "R\$19,99/mês",
                  description: "Acesso premium por 1 mês.",
                  priceId: stripePriceIdMonthly, // Usa constante
                  isSubscription: false, // É pagamento único
                ),
                _buildPlanCard(
                  context: context, // Passa o contexto
                  title: "Plano Recorrente",
                  price: "R\$19,99/mês",
                  description: "Renovação automática mensal.",
                  priceId: stripePriceIdRecurring, // Usa constante
                  isSubscription: true, // É assinatura
                ),
                _buildPlanCard(
                  context: context, // Passa o contexto
                  title: "Plano Trimestral",
                  price: "R\$47,97 / 3 meses", // Valor total
                  description: "Pagamento único para 3 meses.",
                  priceId: stripePriceIdQuarterly, // Usa constante
                  isSubscription: false, // É pagamento único
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context, // Recebe o contexto
    required String title,
    required String price,
    required String description,
    required String priceId, // ID do preço/plano no Stripe
    required bool isSubscription, // Indica se é assinatura recorrente
    // REMOVIDO: VoidCallback onTap - A ação é despachada aqui mesmo
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.amber[800],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        subtitle: Text(description,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Text(price,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        onTap: () {
          // --- DEBUG PRINT ---
          print(
              '>>> UI: Botão ${isSubscription ? "Assinatura" : "Pagamento"} $priceId clicado!');
          // --- FIM DEBUG PRINT ---

          // Despacha a ação Redux para iniciar o processo
          StoreProvider.of<AppState>(context, listen: false).dispatch(
            InitiateStripePaymentAction(
              priceId: priceId,
              isSubscription: isSubscription,
            ),
          );
        },
      ),
    );
  }
}
