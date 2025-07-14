// Dentro do seu arquivo de reducers ou em um novo arquivo para SubscriptionState
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';

enum SubscriptionStatus {
  unknown, // Estado inicial ou erro ao carregar
  free, // Usuário não tem assinatura ativa
  premiumPendingValidation, // Compra feita, aguardando validação do backend
  premiumActive, // Assinatura ativa e validada
  premiumExpired, // Assinatura expirou
  premiumCancelled, // Assinatura foi cancelada mas pode estar ativa até o fim do período
  error
}

class SubscriptionState {
  final SubscriptionStatus status;
  final String?
      activeProductId; // ID do produto/plano atualmente ativo (ex: 'monthly_plan', 'quarterly_plan')
  final DateTime? expirationDate;
  final String? lastPurchaseToken; // Para validação e gerenciamento no Android
  final String? lastError;
  final bool
      isLoading; // Para indicar que uma operação de pagamento/verificação está em andamento

  SubscriptionState({
    this.status = SubscriptionStatus.unknown,
    this.activeProductId,
    this.expirationDate,
    this.lastPurchaseToken,
    this.lastError,
    this.isLoading = false,
  });

  factory SubscriptionState.initial() {
    return SubscriptionState();
  }

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    String?
        activeProductId, // Use ValueGetter<String?> para permitir definir como null
    DateTime? expirationDate, // Use ValueGetter<DateTime?>
    String? lastPurchaseToken, // Use ValueGetter<String?>
    String? lastError,
    bool? isLoading,
    bool clearError = false,
    bool clearActiveProduct = false,
    bool clearExpirationDate = false,
    bool clearLastPurchaseToken = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      activeProductId:
          clearActiveProduct ? null : (activeProductId ?? this.activeProductId),
      expirationDate:
          clearExpirationDate ? null : (expirationDate ?? this.expirationDate),
      lastPurchaseToken: clearLastPurchaseToken
          ? null
          : (lastPurchaseToken ?? this.lastPurchaseToken),
      lastError: clearError ? null : (lastError ?? this.lastError),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Reducer para SubscriptionState
SubscriptionState subscriptionReducer(SubscriptionState state, dynamic action) {
  if (action is InitiateGooglePlaySubscriptionAction) {
    return state.copyWith(isLoading: true, clearError: true);
  }

  // >>>>> ADICIONE ESTE BLOCO <<<<<
  if (action is FinalizePurchaseAttemptAction) {
    // Esta ação é despachada em caso de erro ou cancelamento para resetar o loading
    return state.copyWith(isLoading: false);
  }
  if (action is InitiateStripePaymentAction ||
      action is InitiateGooglePlaySubscriptionAction) {
    // Adicionada nova ação
    return state.copyWith(isLoading: true, clearError: true);
  }
  if (action is StripeCheckoutReadyAction) {
    // Mantido para Stripe, pode ser adaptado
    return state.copyWith(isLoading: false);
  }
  if (action is GooglePlayPurchaseInitiatedAction) {
    // Nova ação
    return state.copyWith(
        isLoading: false); // Pode ser true se houver mais passos no cliente
  }
  if (action is GooglePlayPurchaseVerifiedAction) {
    // Nova ação
    // A validação do backend é que mudará o status para premiumActive.
    // Esta ação pode ser usada para registrar que o recibo foi enviado para verificação.
    return state.copyWith(
        isLoading: false, // Ou true se a UI deve esperar a confirmação final
        status: SubscriptionStatus
            .premiumPendingValidation, // Atualiza para pendente
        lastPurchaseToken:
            action.purchaseDetails.purchaseID // Ou o token de compra do Google
        );
  }
  if (action is GooglePlayPurchaseErrorAction) {
    // Nova ação
    return state.copyWith(
        isLoading: false,
        status: SubscriptionStatus.error,
        lastError: action.error);
  }
  if (action is SubscriptionStatusUpdatedAction) {
    // Esta ação é crucial e será despachada pelo middleware que ouve o Firestore
    // ou após a validação do backend.
    SubscriptionStatus newStatus;
    bool shouldClearData = false;

    switch (action.status.toLowerCase()) {
      case 'active':
      case 'trialing':
        newStatus = SubscriptionStatus.premiumActive;
        break;
      case 'past_due':
      case 'canceled':
        newStatus =
            action.endDate != null && action.endDate!.isAfter(DateTime.now())
                ? SubscriptionStatus.premiumActive
                : SubscriptionStatus.premiumExpired;
        // Se cancelado e já expirado, também limpa os dados
        if (newStatus == SubscriptionStatus.premiumExpired) {
          shouldClearData = true;
        }
        break;
      case 'expired':
      case 'inactive': // ✅ Casos que devem limpar os dados
      case 'paused':
      default:
        newStatus = SubscriptionStatus.free;
        shouldClearData = true; // Marca para limpar os dados da assinatura
    }
    return state.copyWith(
      isLoading: false,
      status: newStatus,
      // Se for para limpar, passa null explicitamente, senão usa o da ação ou o antigo
      activeProductId: shouldClearData ? null : action.priceId,
      expirationDate: shouldClearData ? null : action.endDate,
      // Usa as flags de limpeza que já existem no copyWith
      clearActiveProduct: shouldClearData,
      clearExpirationDate: shouldClearData,
      clearError: true,
    );
  }
  if (action is StripePaymentFailedAction ||
      action is GooglePlayPaymentFailedAction) {
    // Adicionada nova ação
    return state.copyWith(
        isLoading: false,
        status: SubscriptionStatus.error,
        lastError: action.error);
  }
  if (action is GooglePlayPaymentFailedAction) {
    return state.copyWith(
        isLoading: false, // Garante que isLoading seja false em caso de falha
        status: SubscriptionStatus.error,
        lastError: action.error);
  }
  if (action is UserLoggedOutAction) {
    // Limpa o estado da assinatura ao deslogar
    return SubscriptionState.initial();
  }
  return state;
}
