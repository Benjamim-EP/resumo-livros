import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/stripe_service.dart';

class SubscriptionSelectionPage extends StatelessWidget {
  const SubscriptionSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escolha seu Plano Premium")),
      body: StoreConnector<AppState, Map<String, String?>>(
        converter: (store) => {
          'userId': store.state.userState.userId,
          'email': store.state.userState.email,
          'nome': store.state.userState.nome,
        },
        builder: (context, userData) {
          final userId = userData['userId'];
          final email = userData['email'];
          final nome = userData['nome'];

          if (userId == null || email == null || nome == null) {
            return const Center(
              child: Text(
                "Erro: Usuário não autenticado.",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPlanCard(
                  title: "Plano Mensal",
                  price: "R\$19,99/mês",
                  description: "Acesso premium por 1 mês.",
                  onTap: () {
                    StripeService.instance.makePayment(
                        "prod_RoEGL7L2Q42qxS", userId, email, nome, context);
                  },
                ),
                _buildPlanCard(
                  title: "Plano Recorrente",
                  price: "R\$19,99/mês",
                  description: "Renovação automática mensal.",
                  onTap: () {
                    StripeService.instance.subscribeUser(
                        "prod_RoEGoEHf7gIgY0", userId, email, nome, context);
                  },
                ),
                _buildPlanCard(
                  title: "Plano Trimestral",
                  price: "R\$47,97/3 meses",
                  description: "20% de desconto no total.",
                  onTap: () {
                    StripeService.instance.makePayment(
                        "prod_RoEHs1QAcZivO4", userId, email, nome, context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String description,
    required VoidCallback onTap,
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
        onTap: onTap,
      ),
    );
  }
}
