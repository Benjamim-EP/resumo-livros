// test/reducers/subscription_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';

void main() {
  group('SubscriptionReducer', () {
    // Teste 1: Estado inicial
    test('deve ter um estado inicial correto', () {
      final state = SubscriptionState.initial();

      expect(state.status, SubscriptionStatus.unknown);
      expect(state.isLoading, false);
      expect(state.lastError, isNull);
      expect(state.activeProductId, isNull);
    });

    // Teste 2: Início de uma compra
    test('deve definir isLoading como true ao iniciar uma compra', () {
      // DADO um estado inicial
      final initialState = SubscriptionState.initial();
      final action =
          InitiateGooglePlaySubscriptionAction(productId: 'monthly_premium');

      // QUANDO a ação de iniciar compra é processada
      final newState = subscriptionReducer(initialState, action);

      // ENTÃO o estado de loading deve ser true e erros anteriores limpos
      expect(newState.isLoading, true);
      expect(newState.lastError, isNull);
    });

    // Teste 3: Finalização da tentativa de compra (sucesso ou falha)
    test(
        'deve definir isLoading como false ao finalizar uma tentativa de compra',
        () {
      // DADO um estado de loading
      final loadingState = SubscriptionState(isLoading: true);
      final action =
          FinalizePurchaseAttemptAction(productId: 'monthly_premium');

      // QUANDO a ação de finalizar é processada
      final newState = subscriptionReducer(loadingState, action);

      // ENTÃO o loading deve ser false
      expect(newState.isLoading, false);
    });

    // Teste 4: Erro na compra
    test(
        'deve registrar um erro e parar o loading ao receber GooglePlayPurchaseErrorAction',
        () {
      // DADO um estado de loading
      final loadingState = SubscriptionState(isLoading: true);
      final action = GooglePlayPurchaseErrorAction(error: "Compra cancelada");

      // QUANDO a ação de erro é processada
      final newState = subscriptionReducer(loadingState, action);

      // ENTÃO o loading deve ser false e o erro deve ser registrado
      expect(newState.isLoading, false);
      expect(newState.status, SubscriptionStatus.error);
      expect(newState.lastError, "Compra cancelada");
    });

    // Teste 5: Atualização de status para ATIVO
    test(
        'deve atualizar o estado para premiumActive ao receber SubscriptionStatusUpdatedAction com status "active"',
        () {
      final initialState = SubscriptionState.initial();
      final expirationDate = DateTime.now().add(const Duration(days: 30));
      final action = SubscriptionStatusUpdatedAction(
        status: 'active',
        endDate: expirationDate,
        priceId: 'monthly_premium',
      );

      final newState = subscriptionReducer(initialState, action);

      expect(newState.status, SubscriptionStatus.premiumActive);
      expect(newState.isLoading, false);
      expect(newState.activeProductId, 'monthly_premium');
      expect(newState.expirationDate, expirationDate);
      expect(newState.lastError, isNull);
    });

    // Teste 6: Atualização de status para INATIVO
    test(
        'deve atualizar o estado para free ao receber SubscriptionStatusUpdatedAction com status "inactive"',
        () {
      // DADO um estado premium ativo
      final activeState = SubscriptionState(
          status: SubscriptionStatus.premiumActive,
          activeProductId: 'monthly_premium');
      final action = SubscriptionStatusUpdatedAction(status: 'inactive');

      // QUANDO a ação de atualização é processada
      final newState = subscriptionReducer(activeState, action);

      // ENTÃO o status deve ser free
      expect(newState.status, SubscriptionStatus.free);
      expect(newState.activeProductId,
          isNull); // O reducer deve limpar o ID do produto
      expect(newState.expirationDate, isNull);
    });

    // Teste 7: Logout do usuário
    test('deve resetar para o estado inicial ao receber UserLoggedOutAction',
        () {
      // DADO um estado premium ativo
      final activeState = SubscriptionState(
          status: SubscriptionStatus.premiumActive,
          activeProductId: 'monthly_premium',
          isLoading: false,
          lastError: 'um erro antigo');
      final action = UserLoggedOutAction();

      // QUANDO o usuário faz logout
      final newState = subscriptionReducer(activeState, action);
      final initialState = SubscriptionState.initial();

      // ENTÃO o estado deve ser idêntico ao inicial
      expect(newState.status, initialState.status);
      expect(newState.activeProductId, initialState.activeProductId);
      expect(newState.isLoading, initialState.isLoading);
      expect(newState.lastError, initialState.lastError);
    });
  });
}
