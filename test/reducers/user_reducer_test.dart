// test/reducers/user_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';

void main() {
  group('UserReducer', () {
    // Teste 1: Ação de login
    test('deve atualizar o estado para logado ao receber UserLoggedInAction',
        () {
      // DADO: um estado inicial de deslogado
      final initialState = UserState();
      final action = UserLoggedInAction(
          userId: '123', email: 'test@test.com', nome: 'Teste');

      // QUANDO: o reducer é chamado
      final newState = userReducer(initialState, action);

      // ENTÃO: o estado deve refletir o login
      expect(newState.isLoggedIn, true);
      expect(newState.isGuestUser, false);
      expect(newState.userId, '123');
      expect(newState.nome, 'Teste');
      expect(newState.isLoadingLogin,
          true); // Confirma que o estado de loading é ativado
    });

    // Teste 2: Ação de logout
    test('deve resetar o estado para o inicial ao receber UserLoggedOutAction',
        () {
      // DADO: um estado de usuário logado e com dados
      final loggedInState = UserState(
          isLoggedIn: true,
          userId: '123',
          userCoins: 50,
          userDetails: {'nome': 'Usuário Antigo'});
      final action = UserLoggedOutAction();

      // QUANDO: o reducer é chamado
      final newState = userReducer(loggedInState, action);

      // ENTÃO: o novo estado deve ser igual ao estado inicial padrão
      final expectedInitialState = UserState();
      expect(newState.isLoggedIn, expectedInitialState.isLoggedIn);
      expect(newState.userId, expectedInitialState.userId);
      expect(newState.userCoins, expectedInitialState.userCoins);
      expect(newState.userDetails, expectedInitialState.userDetails);
    });

    // Teste 3: Ação de atualizar moedas
    test('deve atualizar userCoins ao receber UpdateUserCoinsAction', () {
      // DADO: um estado com 50 moedas
      final initialState = UserState(userCoins: 50);
      final action = UpdateUserCoinsAction(45);

      // QUANDO: o reducer é chamado
      final newState = userReducer(initialState, action);

      // ENTÃO: o número de moedas deve ser 45
      expect(newState.userCoins, 45);
    });

    // Teste 4: Ação de atualizar moedas com clamp (limite)
    test('deve limitar as moedas a 100 ao receber um valor maior', () {
      final initialState = UserState(userCoins: 95);
      // Tenta adicionar moedas que ultrapassariam o limite, mas a ação UpdateUserCoinsAction já faz o clamp.
      final action = UpdateUserCoinsAction(110);

      final newState = userReducer(initialState, action);

      expect(newState.userCoins, 100);
    });

    test('deve impedir que as moedas fiquem negativas', () {
      final initialState = UserState(userCoins: 5);
      final action = UpdateUserCoinsAction(-10);

      final newState = userReducer(initialState, action);

      expect(newState.userCoins, 0);
    });

    // Teste 5: Modo Convidado
    test('deve configurar o modo convidado e limpar dados do usuário anterior',
        () {
      // DADO: um estado de usuário logado
      final loggedInState =
          UserState(isLoggedIn: true, userId: '123', email: 'user@test.com');
      final action = UserEnteredGuestModeAction(initialCoins: 25);

      // QUANDO: o reducer é chamado para entrar no modo convidado
      final newState = userReducer(loggedInState, action);

      // ENTÃO: o estado deve refletir o modo convidado e os dados antigos devem ser nulos
      expect(newState.isGuestUser, true);
      expect(newState.isLoggedIn, false);
      expect(newState.userId,
          isNull); // ✅ VERIFICAÇÃO DIRETA: o userId deve ser nulo
      expect(newState.email,
          isNull); // ✅ VERIFICAÇÃO DIRETA: o email deve ser nulo
      expect(newState.nome, 'Convidado');
      expect(newState.userCoins, 25);
    });
  });
}
