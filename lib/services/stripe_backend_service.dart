// lib/services/stripe_backend_service.dart
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/consts.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';

class StripeBackendService {
  final Dio _dio = Dio();
  final FirestoreService _firestoreService = FirestoreService();
  final String _stripeApiBaseUrl = "https://api.stripe.com/v1";

  StripeBackendService() {
    _dio.options.headers = {
      "Authorization": "Bearer $stripeSecretKey",
      "Content-Type": 'application/x-www-form-urlencoded',
    };
    // Adiciona um interceptor para loggar requisições e respostas (útil para debug)
    _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => print(">>> Dio Log: $o") // Redireciona log do Dio
        ));
  }

  Future<String?> getOrCreateCustomer(
      String email, String name, String userId) async {
    // --- DEBUG PRINT ---
    print(
        ">>> BackendService: getOrCreateCustomer chamado para email: $email, userId: $userId");
    // --- FIM DEBUG PRINT ---
    try {
      final searchResponse = await _dio.get(
        "$_stripeApiBaseUrl/customers",
        queryParameters: {"email": email, "limit": 1},
      );

      final List<dynamic> customers = searchResponse.data["data"];
      if (customers.isNotEmpty) {
        final customerId = customers.first["id"];
        // --- DEBUG PRINT ---
        print(">>> BackendService: Cliente Stripe encontrado: $customerId");
        // --- FIM DEBUG PRINT ---
        await _updateCustomerMetadataIfNeeded(customerId, userId);
        return customerId;
      }

      // --- DEBUG PRINT ---
      print(">>> BackendService: Criando novo cliente Stripe para: $email");
      // --- FIM DEBUG PRINT ---
      final createResponse = await _dio.post(
        "$_stripeApiBaseUrl/customers",
        data: {
          "email": email,
          "name": name,
          "metadata[userId]": userId,
        },
      );
      final newCustomerId = createResponse.data["id"];
      // --- DEBUG PRINT ---
      print(">>> BackendService: Novo cliente Stripe criado: $newCustomerId");
      // --- FIM DEBUG PRINT ---
      return newCustomerId;
    } catch (e) {
      // --- DEBUG PRINT ---
      print(">>> BackendService: ERRO (getOrCreateCustomer) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
      return null;
    }
  }

  Future<void> _updateCustomerMetadataIfNeeded(
      String customerId, String userId) async {
    // --- DEBUG PRINT ---
    print(
        ">>> BackendService: Verificando/Atualizando metadata para customer $customerId com userId $userId");
    // --- FIM DEBUG PRINT ---
    try {
      final customerData =
          await _dio.get("$_stripeApiBaseUrl/customers/$customerId");
      final metadata =
          customerData.data['metadata'] as Map<String, dynamic>? ?? {};
      if (metadata['userId'] != userId) {
        // --- DEBUG PRINT ---
        print(">>> BackendService: Metadata desatualizado. Atualizando...");
        // --- FIM DEBUG PRINT ---
        await _dio.post(
          "$_stripeApiBaseUrl/customers/$customerId",
          data: {"metadata[userId]": userId},
        );
        print(">>> BackendService: Metadata atualizado com sucesso."); // DEBUG
      } else {
        print(">>> BackendService: Metadata já está correto."); // DEBUG
      }
    } catch (e) {
      // --- DEBUG PRINT ---
      print(">>> BackendService: ERRO (_updateCustomerMetadataIfNeeded) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
    }
  }

  Future<String?> createPaymentIntent(String priceId, String customerId) async {
    // --- DEBUG PRINT ---
    print(
        ">>> BackendService: createPaymentIntent chamado para priceId: $priceId, customerId: $customerId");
    // --- FIM DEBUG PRINT ---
    final amount = stripePriceAmountMap[priceId];
    if (amount == null) {
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService: ERRO - Valor não encontrado para priceId $priceId");
      // --- FIM DEBUG PRINT ---
      return null;
    }
    // --- DEBUG PRINT ---
    print(">>> BackendService: Valor calculado: $amount");
    // --- FIM DEBUG PRINT ---

    try {
      final response = await _dio.post(
        "$_stripeApiBaseUrl/payment_intents",
        data: {
          "amount": amount,
          "currency": "brl",
          "customer": customerId,
          "payment_method_types[]": "card",
          "metadata[priceId]": priceId,
        },
      );
      final clientSecret = response.data["client_secret"];
      final paymentIntentId = response.data["id"];
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService: PaymentIntent criado: $paymentIntentId, client_secret: $clientSecret");
      // --- FIM DEBUG PRINT ---
      return clientSecret;
    } catch (e) {
      // --- DEBUG PRINT ---
      print(">>> BackendService: ERRO (createPaymentIntent) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> createSubscription(
      String priceId, String customerId) async {
    // --- DEBUG PRINT ---
    print(
        ">>> BackendService: createSubscription chamado para priceId: $priceId, customerId: $customerId");
    // --- FIM DEBUG PRINT ---
    try {
      final response = await _dio.post(
        "$_stripeApiBaseUrl/subscriptions",
        data: {
          "customer": customerId,
          "items[0][price]": priceId,
          "payment_behavior": "default_incomplete",
          "payment_settings[save_default_payment_method]": "on_subscription",
          "expand[]": "latest_invoice.payment_intent",
          "metadata[priceId]": priceId,
        },
      );

      final subscription = response.data;
      final latestInvoice = subscription["latest_invoice"];
      final paymentIntent = latestInvoice?["payment_intent"];
      final subscriptionId = subscription["id"];
      final status = subscription["status"];

      // --- DEBUG PRINT ---
      print(
          ">>> BackendService: Assinatura criada: $subscriptionId, Status: $status");
      if (paymentIntent != null) {
        print(
            ">>> BackendService: PaymentIntent da fatura: ${paymentIntent['id']}, client_secret: ${paymentIntent['client_secret']}");
      } else {
        print(
            ">>> BackendService: Nenhum PaymentIntent associado à primeira fatura (Status: $status).");
      }
      // --- FIM DEBUG PRINT ---

      if (paymentIntent != null && paymentIntent["client_secret"] != null) {
        return {
          "subscriptionId": subscriptionId,
          "clientSecret": paymentIntent["client_secret"],
          "status": status,
        };
      } else if (status == 'active') {
        print(
            ">>> BackendService: Assinatura $subscriptionId ativa imediatamente. Simulando webhook.");
        await handleSubscriptionWebhookEvent(
            subscriptionId, 'active', subscription['current_period_end']);
        return {
          "subscriptionId": subscriptionId,
          "clientSecret": null,
          "status": status
        };
      } else {
        print(
            ">>> BackendService: ERRO - client_secret não encontrado ou status inesperado ($status).");
        return null;
      }
    } catch (e) {
      // --- DEBUG PRINT ---
      print(">>> BackendService: ERRO (createSubscription) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
      return null;
    }
  }

  // --- SIMULAÇÃO DE WEBHOOK HANDLER ---

  Future<void> handlePaymentIntentSucceeded(String identifier) async {
    // Identificador pode ser o client_secret ou o paymentIntentId
    String paymentIntentId = identifier;
    // Se for o client_secret, extraia o ID (exemplo)
    if (identifier.contains("_secret_")) {
      paymentIntentId = identifier.split('_secret_').first;
    }

    // --- DEBUG PRINT ---
    print(
        ">>> BackendService Webhook Sim: handlePaymentIntentSucceeded para PI ID: $paymentIntentId");
    // --- FIM DEBUG PRINT ---
    try {
      final response =
          await _dio.get("$_stripeApiBaseUrl/payment_intents/$paymentIntentId");
      final paymentIntent = response.data;
      final customerId = paymentIntent['customer'];
      final priceId = paymentIntent['metadata']?['priceId'];

      if (customerId == null) {
        print(
            ">>> BackendService Webhook Sim: ERRO - Customer ID não encontrado em $paymentIntentId");
        return;
      }

      final userId =
          await _firestoreService.findUserIdByStripeCustomerId(customerId);
      if (userId == null) {
        print(
            ">>> BackendService Webhook Sim: ERRO - Usuário Firebase não encontrado para Customer $customerId");
        return;
      }

      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: Atualizando Firestore para userId $userId (Pagamento Único $priceId)");
      // --- FIM DEBUG PRINT ---

      DateTime expirationDate = DateTime.now();
      if (priceId == stripePriceIdMonthly) {
        expirationDate = expirationDate.add(const Duration(days: 31));
      } else if (priceId == stripePriceIdQuarterly) {
        expirationDate = expirationDate.add(const Duration(days: 92));
      } else {
        expirationDate = expirationDate.add(const Duration(days: 31));
      }

      await _firestoreService.updateUserSubscriptionStatus(
          userId: userId,
          status: 'active',
          endDate: Timestamp.fromDate(expirationDate),
          subscriptionId: null,
          customerId: customerId,
          priceId: priceId);
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: Firestore atualizado para usuário $userId.");
      // --- FIM DEBUG PRINT ---
    } catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: ERRO (handlePaymentIntentSucceeded) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
    }
  }

  Future<void> handleSubscriptionWebhookEvent(
      String subscriptionId, String status, int? currentPeriodEndUnix) async {
    // --- DEBUG PRINT ---
    print(
        ">>> BackendService Webhook Sim: handleSubscriptionWebhookEvent para Sub ID: $subscriptionId, Status: $status");
    // --- FIM DEBUG PRINT ---
    try {
      final response =
          await _dio.get("$_stripeApiBaseUrl/subscriptions/$subscriptionId");
      final subscription = response.data;
      final customerId = subscription['customer'];
      final priceId = subscription['items']?['data']?[0]?['price']?['id'];

      if (customerId == null) {
        print(
            ">>> BackendService Webhook Sim: ERRO - Customer ID não encontrado em $subscriptionId");
        return;
      }

      final userId =
          await _firestoreService.findUserIdByStripeCustomerId(customerId);
      if (userId == null) {
        print(
            ">>> BackendService Webhook Sim: ERRO - Usuário Firebase não encontrado para Customer $customerId");
        return;
      }

      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: Atualizando Firestore para userId $userId (Assinatura $priceId)");
      // --- FIM DEBUG PRINT ---

      Timestamp? endDate;
      // Usa o currentPeriodEnd da assinatura recuperada se o passado for nulo
      final periodEnd =
          currentPeriodEndUnix ?? subscription['current_period_end'];
      if (periodEnd != null && periodEnd is int) {
        endDate = Timestamp.fromMillisecondsSinceEpoch(periodEnd * 1000);
      }

      await _firestoreService.updateUserSubscriptionStatus(
          userId: userId,
          status: status,
          endDate: endDate,
          subscriptionId: subscriptionId,
          customerId: customerId,
          priceId: priceId);
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: Firestore atualizado para usuário $userId.");
      // --- FIM DEBUG PRINT ---
    } catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> BackendService Webhook Sim: ERRO (handleSubscriptionWebhookEvent) - $e");
      // --- FIM DEBUG PRINT ---
      if (e is DioException) {
        print(
            ">>> BackendService: Detalhes DioException: ${e.response?.statusCode} - ${e.response?.data}");
      }
    }
  }
}
