// test/reducers/chat_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';

void main() {
  group('ChatReducer', () {
    // Teste 1: Estado Inicial
    test('deve ter um estado inicial com latestResponse nulo', () {
      final initialState =
          ChatState(); // O construtor padrão já define latestResponse como null

      expect(initialState.latestResponse, isNull);
    });

    // Teste 2: Sucesso ao enviar mensagem
    test(
        'deve atualizar latestResponse com a resposta do bot em caso de sucesso',
        () {
      // DADO: um estado inicial
      final initialState = ChatState();
      final botResponse = "Olá! Como posso ajudar?";
      final action = SendMessageSuccessAction(botResponse);

      // QUANDO: a ação de sucesso é processada
      final newState = chatReducer(initialState, action);

      // ENTÃO: o latestResponse deve conter a mensagem do bot
      expect(newState.latestResponse, botResponse);
    });

    // Teste 3: Falha ao enviar mensagem
    test(
        'deve atualizar latestResponse com a mensagem de erro em caso de falha',
        () {
      // DADO: um estado que talvez já tivesse uma resposta anterior
      final stateWithPreviousResponse =
          ChatState(latestResponse: "Resposta antiga");
      final errorMessage = "Falha de conexão";
      final action = SendMessageFailureAction(errorMessage);

      // QUANDO: a ação de falha é processada
      final newState = chatReducer(stateWithPreviousResponse, action);

      // ENTÃO: o latestResponse deve conter a mensagem de erro formatada
      expect(newState.latestResponse, "Erro: Falha de conexão");
    });

    // Teste 4: Ação desconhecida
    test('deve retornar o estado atual se uma ação desconhecida for despachada',
        () {
      final initialState = ChatState(latestResponse: "Uma resposta qualquer");

      final newState = chatReducer(initialState, "ACAO_INVALIDA");

      // ENTÃO: o estado deve ser o mesmo
      expect(newState.latestResponse, "Uma resposta qualquer");
      // Comparar a instância funciona aqui porque nenhuma mudança ocorreu
      expect(newState, initialState);
    });
  });
}
