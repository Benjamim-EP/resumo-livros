// // lib/services/stripe_service.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_stripe/flutter_stripe.dart';

// class StripeService {
//   StripeService._();
//   static final StripeService instance = StripeService._();

//   Future<void> presentPaymentSheetWithSecret(
//       String clientSecret, String customerId, BuildContext context,
//       {required bool isSubscription, required String identifier}) async {
//     print(
//         '>>> StripeService: presentPaymentSheetWithSecret iniciado. Identifier: $identifier');
//     try {
//       print('>>> StripeService: Chamando Stripe.instance.initPaymentSheet...');
//       await Stripe.instance.initPaymentSheet(
//         paymentSheetParameters: SetupPaymentSheetParameters(
//           paymentIntentClientSecret: clientSecret,
//           merchantDisplayName: "Septima",
//           customerId: customerId,
//         ),
//       );
//       print('>>> StripeService: initPaymentSheet concluído.');

//       print(
//           '>>> StripeService: Chamando Stripe.instance.presentPaymentSheet...');
//       await Stripe.instance.presentPaymentSheet();
//       print(
//           '>>> StripeService: presentPaymentSheet CONCLUÍDO. Pagamento/Confirmação bem-sucedida no frontend.');

//       _showSuccessDialog(context,
//           isSubscription ? "Assinatura iniciada!" : "Pagamento processado!");
//       // Listener no MainAppScreen cuidará de recarregar o estado
//     } on StripeException catch (e) {
//       print(
//           ">>> StripeService: CATCH StripeException - ${e.error.code} - ${e.error.localizedMessage}");
//       // Chama o diálogo de erro INTERNO (agora público)
//       showErrorDialog(
//           context,
//           e.error.localizedMessage ??
//               "Erro durante o pagamento."); // <<< USA MÉTODO PÚBLICO
//     } catch (e) {
//       print(">>> StripeService: CATCH Geral - Erro inesperado: $e");
//       // Chama o diálogo de erro INTERNO (agora público)
//       showErrorDialog(
//           context, "Ocorreu um erro inesperado."); // <<< USA MÉTODO PÚBLICO
//     }
//   }

//   // --- Diálogos de Feedback ---
//   // Sucesso pode permanecer privado
//   void _showSuccessDialog(BuildContext context, String message) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (context.mounted) {
//         print(">>> StripeService: Mostrando diálogo de SUCESSO: $message");
//         showDialog(
//           context: context,
//           builder: (_) => AlertDialog(
//             title: const Text("Sucesso ✅"),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text("OK"),
//               ),
//             ],
//           ),
//         );
//       } else {
//         print(">>> StripeService: ERRO - Contexto não montado (sucesso).");
//       }
//     });
//   }

//   // Erro agora é PÚBLICO para ser chamado pelo middleware
//   void showErrorDialog(BuildContext context, String message) {
//     // <<< REMOVIDO O '_'
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (context.mounted) {
//         print(">>> StripeService: Mostrando diálogo de ERRO: $message");
//         showDialog(
//           context: context,
//           builder: (_) => AlertDialog(
//             title: const Text("Erro ❌"),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text("OK"),
//               ),
//             ],
//           ),
//         );
//       } else {
//         print(">>> StripeService: ERRO - Contexto não montado (erro).");
//       }
//     });
//   }
// }
