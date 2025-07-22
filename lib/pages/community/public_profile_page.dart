// lib/pages/community/public_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/avatar/avatar_user.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// ViewModel para obter os dados do *usuário logado* e comparar com o perfil público
class _ViewModel {
  final List<String> friends;
  final List<String> requestsSent;
  final List<String> requestsReceived;

  _ViewModel({
    required this.friends,
    required this.requestsSent,
    required this.requestsReceived,
  });

  static _ViewModel fromStore(Store<AppState> store) {
    final userDetails = store.state.userState.userDetails ?? {};
    return _ViewModel(
      friends: List<String>.from(userDetails['friends'] ?? []),
      requestsSent: List<String>.from(userDetails['friendRequestsSent'] ?? []),
      requestsReceived:
          List<String>.from(userDetails['friendRequestsReceived'] ?? []),
    );
  }
}

class PublicProfilePage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> initialUserData;

  const PublicProfilePage({
    super.key,
    required this.userId,
    required this.initialUserData,
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  // Mantemos este estado local para evitar cliques duplos no botão
  bool _isProcessingRequest = false;

  // ===================================
  // <<< FUNÇÃO ATUALIZADA >>>
  // ===================================
  Future<void> _sendFriendRequest() async {
    if (_isProcessingRequest) return;
    setState(() => _isProcessingRequest = true);

    // Despacha a ação otimista. A UI será atualizada instantaneamente pelo reducer.
    // O middleware cuidará da chamada de backend em segundo plano.
    StoreProvider.of<AppState>(context, listen: false).dispatch(
        SendFriendRequestOptimisticAction(targetUserId: widget.userId));

    // Reabilita o botão após um curto período. A UI já terá sido atualizada.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProcessingRequest = false);
    });
  }

  Widget _buildActionButton(_ViewModel vm) {
    // Esta lógica não precisa mudar, pois ela lê o estado do Redux.
    // Quando o reducer atualizar o estado de forma otimista, este widget
    // será reconstruído automaticamente com o botão correto.
    if (vm.friends.contains(widget.userId)) {
      return FilledButton.icon(
        onPressed: null, // Desabilitado pois já são amigos
        icon: Icon(Icons.check),
        label: Text("Amigos"),
        style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.green)),
      );
    }
    if (vm.requestsSent.contains(widget.userId)) {
      return FilledButton.icon(
        onPressed: null, // Desabilitado pois o pedido já foi enviado
        icon: Icon(Icons.hourglass_top),
        label: Text("Pedido Enviado"),
      );
    }
    if (vm.requestsReceived.contains(widget.userId)) {
      // O usuário deve ir para a tela de amigos para aceitar/recusar
      return FilledButton.icon(
        onPressed: () {
          // Navega para a aba de pedidos recebidos
          Navigator.of(context).pop(); // Fecha o perfil
          Navigator.of(context).pushNamed('/friends'); // Abre a tela de amigos
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Responder ao Pedido"),
      );
    }

    // Botão padrão para adicionar amigo
    return FilledButton.icon(
      onPressed: _isProcessingRequest ? null : _sendFriendRequest,
      icon: _isProcessingRequest
          ? Container(
              width: 18,
              height: 18,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.person_add_outlined),
      label: const Text("Adicionar Amigo"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil de ${widget.initialUserData['nome'] ?? 'Usuário'}"),
      ),
      body: StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        // O `distinct: true` é importante para performance
        distinct: true,
        builder: (context, viewModel) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Avatar(userPhotoURL: widget.initialUserData['photoURL']),
                  const SizedBox(height: 16),
                  Text(
                    widget.initialUserData['nome'] ?? 'Usuário',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.initialUserData['descrição'] ?? 'Sem descrição',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _buildActionButton(viewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
