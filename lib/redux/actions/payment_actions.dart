// lib/redux/actions/payment_actions.dart

// Ação disparada pela UI para iniciar um checkout/pagamento
class InitiateStripePaymentAction {
  final String priceId;
  final bool isSubscription; // true para assinatura, false para pagamento único

  InitiateStripePaymentAction(
      {required this.priceId, required this.isSubscription});
}

// Ação (geralmente disparada pelo middleware após chamada de backend bem-sucedida)
// Pode conter o client_secret ou sessionId para o frontend usar
class StripeCheckoutReadyAction {
  final String clientSecret; // Ou sessionId para Stripe Checkout
  // Adicione outros dados se necessário

  StripeCheckoutReadyAction({required this.clientSecret});
}

// Ação disparada pelo (simulado) webhook handler ou listener do Firestore
// para atualizar o estado da assinatura no Redux
class SubscriptionStatusUpdatedAction {
  final String status; // 'active', 'canceled', 'past_due', etc.
  final DateTime? endDate;
  final String? subscriptionId;
  final String? customerId;
  final String? priceId; // ID do plano ativo

  SubscriptionStatusUpdatedAction({
    required this.status,
    this.endDate,
    this.subscriptionId,
    this.customerId,
    this.priceId,
  });
}

// Ação para indicar falha no processo de pagamento/assinatura
class StripePaymentFailedAction {
  final String error;
  StripePaymentFailedAction(this.error);
}
