import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:resumo_dos_deuses_flutter/consts.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  Future<void> makePayment(String priceId, String userId, String email,
      String nome, BuildContext context) async {
    try {
      final customerId = await _getOrCreateCustomer(userId, email, nome);
      if (customerId == null) return;

      String? paymentIntentClientSecret =
          await _createPaymentIntent(priceId, customerId);
      if (paymentIntentClientSecret == null) return;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentClientSecret,
          merchantDisplayName: "Septima",
          customerId: customerId,
        ),
      );

      bool success = await _processPayment(context);
      if (success) {
        print("Pagamento concluído com sucesso!");
      }
    } catch (e) {
      print("Erro no pagamento: $e");
    }
  }

  Future<void> subscribeUser(String priceId, String userId, String email,
      String nome, BuildContext context) async {
    try {
      final customerId = await _getOrCreateCustomer(userId, email, nome);
      if (customerId == null) return;

      final Dio dio = Dio();
      final response = await dio.post(
        "https://api.stripe.com/v1/subscriptions",
        data: {
          "customer": customerId,
          "items": [
            {"price": priceId}
          ],
          "payment_behavior": "default_incomplete",
          "expand": ["latest_invoice.payment_intent"],
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $stripeSecretKey",
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );

      final clientSecret =
          response.data["latest_invoice"]["payment_intent"]["client_secret"];
      if (clientSecret != null) {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: "Septima",
            customerId: customerId,
          ),
        );

        bool success = await _processPayment(context);
        if (success) {
          print("Assinatura confirmada com sucesso!");
        }
      }
    } catch (e) {
      print("Erro na assinatura: $e");
    }
  }

  Future<String?> _getOrCreateCustomer(
      String userId, String email, String nome) async {
    try {
      final Dio dio = Dio();
      final searchResponse = await dio.get(
        "https://api.stripe.com/v1/customers",
        queryParameters: {"email": email},
        options: Options(
          headers: {
            "Authorization": "Bearer $stripeSecretKey",
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );

      final List<dynamic> customers = searchResponse.data["data"];
      if (customers.isNotEmpty) {
        return customers.first["id"];
      }

      final response = await dio.post(
        "https://api.stripe.com/v1/customers",
        data: {
          "email": email,
          "name": nome,
          "metadata": {"userId": userId},
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $stripeSecretKey",
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );

      return response.data["id"];
    } catch (e) {
      print("Erro ao criar/obter cliente no Stripe: $e");
      return null;
    }
  }

  Future<String?> _createPaymentIntent(
      String priceId, String customerId) async {
    try {
      final Dio dio = Dio();
      var response = await dio.post(
        "https://api.stripe.com/v1/payment_intents",
        data: {
          "amount": _calculateAmount(priceId),
          "currency": "brl",
          "customer": customerId,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $stripeSecretKey",
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );
      return response.data["client_secret"];
    } catch (e) {
      print("Erro ao criar PaymentIntent: $e");
      return null;
    }
  }

  Future<bool> _processPayment(BuildContext context) async {
    try {
      await Stripe.instance.presentPaymentSheet();
      await Stripe.instance.confirmPaymentSheetPayment();

      await Future.delayed(
          Duration(milliseconds: 500)); // Aguarde antes de exibir

      if (context.mounted) {
        _showSuccessDialog(context);
      }
      return true;
    } catch (e) {
      print("Erro ao processar pagamento: $e");

      await Future.delayed(Duration(milliseconds: 500));

      if (context.mounted) {
        _showErrorDialog(context);
      }
      return false;
    }
  }

  String _calculateAmount(String priceId) {
    switch (priceId) {
      case "prod_RoEGL7L2Q42qxS":
        return "1999";
      case "prod_RoEGoEHf7gIgY0":
        return "1999";
      case "prod_RoEHs1QAcZivO4":
        return "4797";
      default:
        return "1999";
    }
  }

  void _showSuccessDialog(BuildContext context) {
    print("veio para cá");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pagamento Confirmado ✅"),
        content: const Text("Seu pagamento foi processado com sucesso."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erro no Pagamento ❌"),
        content: const Text(
            "Ocorreu um erro ao processar o pagamento. Tente novamente."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
