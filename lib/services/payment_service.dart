// lib/services/payment_service.dart

// 1. A Interface (o "Contrato")
abstract class IPaymentService {
  /// Inicia o fluxo de compra para um produto específico (assinatura).
  Future<void> initiatePurchase(String productId);

  /// Tenta restaurar compras anteriores.
  Future<void> restorePurchases();
}

// 2. Implementação Falsa/Vazia (para a versão da Play Store por enquanto)
//    Isso nos permite compilar a versão da Play Store sem ter a lógica do Google ainda.
class GooglePlayPaymentService implements IPaymentService {
  @override
  Future<void> initiatePurchase(String productId) async {
    // A lógica real do Google Play Billing virá aqui no futuro.
    print(
        "GooglePlayPaymentService: Compra iniciada para $productId (ainda não implementado).");
    // Lançar um erro ou mostrar um aviso pode ser útil.
    throw UnimplementedError(
        'Google Play Billing não está configurado para este build.');
  }

  @override
  Future<void> restorePurchases() async {
    print(
        "GooglePlayPaymentService: Restaurando compras (ainda não implementado).");
    throw UnimplementedError(
        'Restauração do Google Play Billing não está configurada.');
  }
}

// 3. Implementação da Stripe (para a versão do site)
class StripePaymentService implements IPaymentService {
  @override
  Future<void> initiatePurchase(String productId) async {
    // AQUI VAI A LÓGICA PARA INICIAR O CHECKOUT DA STRIPE
    // 1. Chamar sua Cloud Function 'createStripeCheckoutSession'.
    // 2. Receber o clientSecret.
    // 3. Usar o pacote flutter_stripe para apresentar a folha de pagamento.
    print("StripePaymentService: Compra iniciada para o plano $productId.");
    // A implementação detalhada virá a seguir.
  }

  @override
  Future<void> restorePurchases() async {
    // A Stripe não tem um fluxo de "restaurar compras" como as lojas de app.
    // A fonte da verdade é o seu backend (Firestore).
    // O usuário simplesmente precisa fazer login para que o app verifique
    // o status da assinatura no documento dele no Firestore.
    print(
        "StripePaymentService: 'Restaurar' não é aplicável. O status é verificado no login.");
    return;
  }
}
