// lib/pages/community/friends_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessingRequest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Dispara a ação para carregar todos os dados de amigos ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(LoadFriendsDataAction());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptRequest(String requesterId) async {
    if (_isProcessingRequest) return;
    setState(() => _isProcessingRequest = true);

    StoreProvider.of<AppState>(context, listen: false).dispatch(
        AcceptFriendRequestOptimisticAction(requesterUserId: requesterId));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProcessingRequest = false);
    });
  }

  // Função para RECUSAR um pedido de amizade (ATUALIZADA)
  Future<void> _declineRequest(String requesterId) async {
    if (_isProcessingRequest) return;
    setState(() => _isProcessingRequest = true);

    StoreProvider.of<AppState>(context, listen: false).dispatch(
        DeclineFriendRequestOptimisticAction(requesterUserId: requesterId));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProcessingRequest = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comunidade"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: "Amigos"),
            Tab(icon: Icon(Icons.person_add_alt_1_outlined), text: "Recebidos"),
            Tab(icon: Icon(Icons.send_outlined), text: "Enviados"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildReceivedRequestsList(),
          _buildSentRequestsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/findFriends'),
        tooltip: "Encontrar Amigos",
        child: const Icon(Icons.person_add),
      ),
    );
  }

  // Constrói a aba "Amigos"
  Widget _buildFriendsList() {
    return StoreConnector<AppState, List<Map<String, dynamic>>>(
      converter: (store) => store.state.userState.friendsDetails,
      builder: (context, friends) {
        if (friends.isEmpty) {
          return const Center(
              child: Text(
                  "Você ainda não tem amigos. Use o botão + para encontrar."));
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final user = friends[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    (user['photoURL'] != null && user['photoURL']!.isNotEmpty)
                        ? NetworkImage(user['photoURL']!)
                        : null,
                child: (user['photoURL'] == null || user['photoURL']!.isEmpty)
                    ? Text(user['nome']?[0] ?? '?')
                    : null,
              ),
              title: Text(user['nome'] ?? 'Usuário Desconhecido'),
              onTap: () {/* Navegar para o perfil público do amigo */},
            );
          },
        );
      },
    );
  }

  // Constrói a aba "Recebidos"
  Widget _buildReceivedRequestsList() {
    return StoreConnector<AppState, List<Map<String, dynamic>>>(
      converter: (store) => store.state.userState.friendRequestsReceivedDetails,
      builder: (context, requests) {
        if (requests.isEmpty) {
          return const Center(
              child: Text("Nenhum pedido de amizade recebido."));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final user = requests[index];
            final userId = user['userId'];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    (user['photoURL'] != null && user['photoURL']!.isNotEmpty)
                        ? NetworkImage(user['photoURL']!)
                        : null,
                child: (user['photoURL'] == null || user['photoURL']!.isEmpty)
                    ? Text(user['nome']?[0] ?? '?')
                    : null,
              ),
              title: Text(user['nome'] ?? 'Usuário Desconhecido'),
              trailing: _isProcessingRequest
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          tooltip: "Aceitar",
                          onPressed: () => _acceptRequest(userId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: "Recusar",
                          onPressed: () => _declineRequest(userId),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  // Constrói a aba "Enviados"
  Widget _buildSentRequestsList() {
    return StoreConnector<AppState, List<Map<String, dynamic>>>(
      converter: (store) => store.state.userState.friendRequestsSentDetails,
      builder: (context, requests) {
        if (requests.isEmpty) {
          return const Center(child: Text("Nenhum pedido de amizade enviado."));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final user = requests[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    (user['photoURL'] != null && user['photoURL']!.isNotEmpty)
                        ? NetworkImage(user['photoURL']!)
                        : null,
                child: (user['photoURL'] == null || user['photoURL']!.isEmpty)
                    ? Text(user['nome']?[0] ?? '?')
                    : null,
              ),
              title: Text(user['nome'] ?? 'Usuário Desconhecido'),
              trailing: const Chip(
                label: Text("Pendente"),
                labelStyle: TextStyle(fontSize: 12),
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          },
        );
      },
    );
  }
}
