// lib/services/stripe_backend_service.dart
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/consts.dart'; // Para chaves e IDs
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // Para interagir com Firestore

class StripeBackendService {
  final Dio _dio = Dio();
  final FirestoreService _firestoreService = FirestoreService();
  final String _stripeApiBaseUrl = "https://api.stripe.com/v1";

  StripeBackendService() {
    _dio.options.headers = {
      "Authorization":
          "Bearer $stripeSecretKey", // USA CHAVE SECRETA (APENAS DEV!)
      "Content-Type": 'application/x-www-form-urlencoded',
    };
  }

  // --- Métodos Simulados do Backend ---

  /// (Backend) Obtém ou cria um Customer no Stripe.
  Future<String?> getOrCreateCustomer(
      String email, String name, String userId) async {
    try {
      // 1. Tenta buscar cliente pelo email
      final searchResponse = await _dio.get(
        "$_stripeApiBaseUrl/customers",
        queryParameters: {"email": email, "limit": 1},
      );

      final List<dynamic> customers = searchResponse.data["data"];
      if (customers.isNotEmpty) {
        print("Cliente Stripe encontrado: ${customers.first["id"]}");
        // Garante que o userId está nos metadados (caso tenha sido criado antes)
        await _updateCustomerMetadataIfNeeded(customers.first["id"], userId);
        return customers.first["id"];
      }

      // 2. Se não encontrar, cria um novo cliente
      print("Criando novo cliente Stripe para: $email");
      final createResponse = await _dio.post(
        "$_stripeApiBaseUrl/customers",
        data: {
          "email": email,
          "name": name,
          "metadata[userId]":
              userId, // Associa o ID do Firebase ao cliente Stripe
        },
      );
      final newCustomerId = createResponse.data["id"];
      print("Novo cliente Stripe criado: $newCustomerId");
      return newCustomerId;
    } catch (e) {
      print("Erro (Backend Simulado) ao obter/criar cliente Stripe: $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
      return null;
    }
  }

  /// (Backend) Garante que o metadata[userId] está presente no cliente Stripe.
  Future<void> _updateCustomerMetadataIfNeeded(
      String customerId, String userId) async {
    try {
      final customerData =
          await _dio.get("$_stripeApiBaseUrl/customers/$customerId");
      final metadata =
          customerData.data['metadata'] as Map<String, dynamic>? ?? {};
      if (metadata['userId'] != userId) {
        print(
            "Atualizando metadata do cliente Stripe $customerId com userId $userId");
        await _dio.post(
          "$_stripeApiBaseUrl/customers/$customerId",
          data: {"metadata[userId]": userId},
        );
      }
    } catch (e) {
      print("Erro ao verificar/atualizar metadata do cliente $customerId: $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
    }
  }

  /// (Backend) Cria um PaymentIntent para pagamento único.
  Future<String?> createPaymentIntent(String priceId, String customerId) async {
    final amount = stripePriceAmountMap[
        priceId]; // Pega valor do mapa (REMOVER EM PRODUÇÃO)
    if (amount == null) {
      print(
          "Erro (Backend Simulado): Valor não encontrado para priceId $priceId");
      return null;
    }

    try {
      final response = await _dio.post(
        "$_stripeApiBaseUrl/payment_intents",
        data: {
          "amount": amount,
          "currency": "brl",
          "customer": customerId,
          "payment_method_types[]":
              "card", // Ou outros métodos que você suporta
          // 'automatic_payment_methods[enabled]': 'true', // Alternativa mais moderna
          "metadata[priceId]":
              priceId, // Guarda o Price ID para referência futura
        },
      );
      final clientSecret = response.data["client_secret"];
      print("PaymentIntent criado (Backend Simulado): ${response.data["id"]}");
      return clientSecret;
    } catch (e) {
      print("Erro (Backend Simulado) ao criar PaymentIntent: $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
      return null;
    }
  }

  /// (Backend) Cria uma Assinatura no Stripe.
  Future<Map<String, dynamic>?> createSubscription(
      String priceId, String customerId) async {
    try {
      // Cria a assinatura
      final response = await _dio.post(
        "$_stripeApiBaseUrl/subscriptions",
        data: {
          "customer": customerId,
          "items[0][price]": priceId,
          "payment_behavior":
              "default_incomplete", // Requer confirmação do cliente
          "payment_settings[save_default_payment_method]":
              "on_subscription", // Salva método p/ futuro
          "expand[]":
              "latest_invoice.payment_intent", // Pega o intent da 1a fatura
          "metadata[priceId]": priceId,
        },
      );

      final subscription = response.data;
      final latestInvoice = subscription["latest_invoice"];
      final paymentIntent = latestInvoice?["payment_intent"];

      print("Assinatura criada (Backend Simulado): ${subscription['id']}");

      if (paymentIntent != null && paymentIntent["client_secret"] != null) {
        return {
          "subscriptionId": subscription["id"],
          "clientSecret": paymentIntent["client_secret"],
          "status":
              subscription["status"], // Geralmente 'incomplete' inicialmente
        };
      } else if (subscription['status'] == 'active') {
        // Caso raro onde a assinatura pode ficar ativa imediatamente (ex: trial sem pagamento inicial)
        print("Assinatura ${subscription['id']} ficou ativa imediatamente.");
        // Simula o webhook de sucesso aqui mesmo para DEV
        await handleSubscriptionWebhookEvent(subscription['id'], 'active',
            subscription['current_period_end'] // Timestamp Unix
            );
        return {
          "subscriptionId": subscription["id"],
          "clientSecret": null, // Não precisa de confirmação
          "status": subscription["status"],
        };
      } else {
        print(
            "Erro (Backend Simulado): client_secret não encontrado na resposta da assinatura.");
        return null;
      }
    } catch (e) {
      print("Erro (Backend Simulado) ao criar Assinatura: $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
      return null;
    }
  }

  // --- SIMULAÇÃO DE WEBHOOK HANDLER ---
  // Em produção, isso seria uma Cloud Function separada exposta como endpoint HTTP
  // e acionada pelos eventos do Stripe.

  /// (Backend - Webhook Simulado) Processa evento de sucesso de PaymentIntent.
  Future<void> handlePaymentIntentSucceeded(String paymentIntentId) async {
    print(
        "Webhook Simulado: Processando payment_intent.succeeded para $paymentIntentId");
    try {
      // 1. Recupera detalhes do PaymentIntent (opcional, pode já ter dados suficientes)
      final response =
          await _dio.get("$_stripeApiBaseUrl/payment_intents/$paymentIntentId");
      final paymentIntent = response.data;
      final customerId = paymentIntent['customer'];
      final priceId =
          paymentIntent['metadata']?['priceId']; // Recupera do metadata

      if (customerId == null) {
        print(
            "Webhook Simulado Erro: Customer ID não encontrado no PaymentIntent $paymentIntentId");
        return;
      }

      // 2. Encontra o usuário no Firestore pelo customerId
      final userId =
          await _firestoreService.findUserIdByStripeCustomerId(customerId);
      if (userId == null) {
        print(
            "Webhook Simulado Erro: Usuário Firebase não encontrado para Stripe Customer $customerId");
        return;
      }

      print(
          "Webhook Simulado: Atualizando status para usuário $userId (Pagamento Único)");

      // 3. Calcula a data de expiração baseado no priceId (exemplo simples)
      DateTime expirationDate = DateTime.now();
      if (priceId == stripePriceIdMonthly) {
        expirationDate = expirationDate
            .add(const Duration(days: 31)); // Aproximadamente 1 mês
      } else if (priceId == stripePriceIdQuarterly) {
        expirationDate = expirationDate
            .add(const Duration(days: 92)); // Aproximadamente 3 meses
      } else {
        // Lógica para outros planos de pagamento único, se houver
        expirationDate =
            expirationDate.add(const Duration(days: 31)); // Default
      }

      // 4. Atualiza o Firestore
      await _firestoreService.updateUserSubscriptionStatus(
          userId: userId,
          status: 'active', // Pagamento único concede acesso 'ativo'
          endDate: Timestamp.fromDate(expirationDate),
          subscriptionId: null, // Não é uma assinatura recorrente
          customerId: customerId, // Salva o customerId
          priceId: priceId // Salva o priceId comprado
          );

      print(
          "Webhook Simulado: Usuário $userId atualizado para status 'active' (pagamento único) até $expirationDate");
    } catch (e) {
      print("Webhook Simulado Erro (PaymentIntent): $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
    }
  }

  /// (Backend - Webhook Simulado) Processa eventos de atualização de assinatura.
  Future<void> handleSubscriptionWebhookEvent(
      String subscriptionId, String status, int? currentPeriodEndUnix) async {
    print(
        "Webhook Simulado: Processando evento para Subscription $subscriptionId - Status: $status");
    try {
      // 1. Recupera a assinatura para obter o customerId
      final response =
          await _dio.get("$_stripeApiBaseUrl/subscriptions/$subscriptionId");
      final subscription = response.data;
      final customerId = subscription['customer'];
      final priceId = subscription['items']?['data']?[0]?['price']
          ?['id']; // Pega o priceId da assinatura

      if (customerId == null) {
        print(
            "Webhook Simulado Erro: Customer ID não encontrado na Assinatura $subscriptionId");
        return;
      }

      // 2. Encontra o usuário no Firestore pelo customerId
      final userId =
          await _firestoreService.findUserIdByStripeCustomerId(customerId);
      if (userId == null) {
        print(
            "Webhook Simulado Erro: Usuário Firebase não encontrado para Stripe Customer $customerId");
        return;
      }

      print(
          "Webhook Simulado: Atualizando status para usuário $userId (Assinatura)");

      // 3. Determina a data de expiração
      Timestamp? endDate;
      if (currentPeriodEndUnix != null) {
        endDate =
            Timestamp.fromMillisecondsSinceEpoch(currentPeriodEndUnix * 1000);
      }

      // 4. Atualiza o Firestore
      await _firestoreService.updateUserSubscriptionStatus(
          userId: userId,
          status: status, // 'active', 'canceled', 'past_due', etc.
          endDate: endDate,
          subscriptionId: subscriptionId, // Salva o ID da assinatura
          customerId: customerId,
          priceId: priceId // Salva o priceId da assinatura ativa
          );

      print(
          "Webhook Simulado: Status da assinatura do usuário $userId atualizado para '$status' ${endDate != null ? 'até ${endDate.toDate()}' : ''}");
    } catch (e) {
      print("Webhook Simulado Erro (Subscription): $e");
      if (e is DioException) {
        print("Detalhes do erro Dio: ${e.response?.data}");
      }
    }
  }
}
