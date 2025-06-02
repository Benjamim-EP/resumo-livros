// lib/redux/actions/payment_actions.dart
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart'; // Para PurchaseDetails

// Ações existentes para Stripe (mantidas para referência ou se você tiver Stripe para web/iOS)
class InitiateStripePaymentAction {
  final String priceId;
  final bool isSubscription;
  InitiateStripePaymentAction(
      {required this.priceId, required this.isSubscription});
}

class StripeCheckoutReadyAction {
  final String clientSecret;
  StripeCheckoutReadyAction({required this.clientSecret});
}

class StripePaymentFailedAction {
  final String error;
  StripePaymentFailedAction(this.error);
}

// --- NOVAS AÇÕES PARA GOOGLE PLAY BILLING ---

// Disparada pela UI para iniciar a compra de uma assinatura via Google Play
class InitiateGooglePlaySubscriptionAction {
  final String
      productId; // O ID do produto de assinatura no Google Play Console (ex: 'monthly_premium_v1')
  InitiateGooglePlaySubscriptionAction({required this.productId});
}

// Disparada pelo middleware após o fluxo de compra do Google Play ser iniciado (UI pode mostrar um loader)
class GooglePlayPurchaseInitiatedAction {
  // Pode não precisar de payload se o plugin in_app_purchase gerencia a UI de compra
}

// Disparada pelo middleware quando a compra é concluída (ou restaurada) no cliente,
// contendo os detalhes da compra para serem enviados ao backend para verificação.
class GooglePlayPurchaseVerifiedAction {
  final PurchaseDetails purchaseDetails;
  GooglePlayPurchaseVerifiedAction({required this.purchaseDetails});
}

// Disparada se houver um erro durante o processo de compra no cliente (antes da verificação do backend)
class GooglePlayPurchaseErrorAction {
  final String error;
  final String? productId; // Opcional: produto que falhou
  GooglePlayPurchaseErrorAction({required this.error, this.productId});
}

// Disparada se houver um erro geral no sistema de pagamento/assinatura (ex: erro de configuração)
class GooglePlayPaymentFailedAction {
  final String error;
  GooglePlayPaymentFailedAction(this.error);
}

// --- FIM NOVAS AÇÕES GOOGLE PLAY ---

// Ação para atualizar o estado da assinatura no Redux
// (Geralmente despachada após validação do backend ou ao carregar o estado do usuário)
class SubscriptionStatusUpdatedAction {
  final String
      status; // 'active', 'inactive', 'expired', 'pending', 'canceled', etc.
  final DateTime? endDate;
  final String?
      subscriptionId; // ID da assinatura no sistema de pagamento (Stripe ou Google)
  final String? customerId; // ID do cliente no sistema de pagamento
  final String?
      priceId; // ID do plano/preço ativo (Stripe) ou productId (Google Play)

  SubscriptionStatusUpdatedAction({
    required this.status,
    this.endDate,
    this.subscriptionId,
    this.customerId,
    this.priceId,
  });
}
