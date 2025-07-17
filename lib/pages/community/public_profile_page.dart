// lib/pages/community/public_profile_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/avatar/avatar_user.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
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
  bool _isProcessingRequest = false;

  Future<void> _sendFriendRequest() async {
    setState(() => _isProcessingRequest = true);
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('sendFriendRequest');
      await callable.call({'targetUserId': widget.userId});

      // Recarrega os dados do usuário logado para atualizar a UI
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(LoadUserDetailsAction());

      if (mounted)
        CustomNotificationService.showSuccess(
            context, "Pedido de amizade enviado!");
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, e.message ?? "Erro ao enviar pedido.");
    } finally {
      if (mounted) setState(() => _isProcessingRequest = false);
    }
  }

  // Aqui você chamaria a função acceptFriendRequest e declineFriendRequest
  // Elas seriam muito similares à _sendFriendRequest
  // Por simplicidade inicial, vamos focar apenas em enviar o pedido.

  Widget _buildActionButton(_ViewModel vm) {
    if (vm.friends.contains(widget.userId)) {
      return FilledButton.icon(
        onPressed: null,
        icon: Icon(Icons.check),
        label: Text("Amigos"),
      );
    }
    if (vm.requestsSent.contains(widget.userId)) {
      return FilledButton.icon(
        onPressed: null,
        icon: Icon(Icons.hourglass_top),
        label: Text("Pedido Enviado"),
      );
    }
    if (vm.requestsReceived.contains(widget.userId)) {
      // Idealmente, isso teria dois botões: Aceitar e Recusar
      return FilledButton.icon(
        onPressed: () {/* Chamar _acceptFriendRequest() */},
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Responder ao Pedido"),
      );
    }

    return FilledButton.icon(
      onPressed: _isProcessingRequest ? null : _sendFriendRequest,
      icon: _isProcessingRequest
          ? Container(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
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
