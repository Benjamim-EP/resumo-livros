// lib/pages/community/notifications_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:redux/redux.dart';

// ViewModel não precisa de mudanças
class _NotificationsViewModel {
  final bool isLoading;
  final List<Map<String, dynamic>> notifications;

  _NotificationsViewModel(
      {required this.isLoading, required this.notifications});

  static _NotificationsViewModel fromStore(Store<AppState> store) {
    return _NotificationsViewModel(
      isLoading: store.state.userState.isLoadingNotifications,
      notifications: store.state.userState.userNotifications,
    );
  }
}

// O widget agora é Stateful para gerenciar o estado local da lista
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Estado para controlar o loading de uma ação específica
  String? _processingNotificationId;

  // ✅ 1. CÓPIA LOCAL DA LISTA DE NOTIFICAÇÕES
  // Usaremos esta lista para renderizar, permitindo a remoção otimista de itens.
  List<Map<String, dynamic>> _displayedNotifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(LoadNotificationsAction());
        _markAllVisibleAsRead();
      }
    });
  }

  Future<void> _markAllVisibleAsRead() async {
    // (Esta função permanece a mesma)
    final store = StoreProvider.of<AppState>(context, listen: false);
    final unreadNotificationIds = store.state.userState.userNotifications
        .where((n) => !(n['isRead'] as bool? ?? true))
        .map((n) => n['id'] as String)
        .toList();

    if (unreadNotificationIds.isEmpty) return;

    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('markNotificationsAsRead');
      await callable.call({'notificationIds': unreadNotificationIds});
    } catch (e) {
      print("Erro ao marcar notificações como lidas: $e");
    }
  }

  // A função para lidar com o pedido agora aceita o mapa completo da notificação
  Future<void> _handleFriendRequest(
      Map<String, dynamic> notification, bool accept) async {
    final requesterId = notification['fromUserId'] as String?;
    if (requesterId == null || _processingNotificationId != null) return;

    setState(() => _processingNotificationId = notification['id']);

    try {
      final functionName =
          accept ? 'acceptFriendRequest' : 'declineFriendRequest';
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable(functionName);
      await callable.call({'requesterUserId': requesterId});

      if (mounted) {
        CustomNotificationService.showSuccess(
            context, accept ? "Amizade aceita!" : "Pedido recusado.");

        // ✅ 2. REMOÇÃO OTIMISTA DA UI
        // Remove o item da lista local para que a UI atualize instantaneamente.
        setState(() {
          _displayedNotifications
              .removeWhere((item) => item['id'] == notification['id']);
        });

        // Recarrega os dados em segundo plano para garantir consistência
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(LoadFriendsDataAction());
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, e.message ?? "Ocorreu um erro.");
    } finally {
      if (mounted) setState(() => _processingNotificationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notificações")),
      body: StoreConnector<AppState, _NotificationsViewModel>(
        converter: (store) => _NotificationsViewModel.fromStore(store),
        // ✅ 3. onWillChange PARA ATUALIZAR NOSSA LISTA LOCAL
        // Sempre que os dados do Redux mudarem, atualizamos nossa lista local.
        onWillChange: (previousViewModel, newViewModel) {
          if (previousViewModel?.notifications != newViewModel.notifications) {
            setState(() {
              _displayedNotifications = newViewModel.notifications;
            });
          }
        },
        builder: (context, viewModel) {
          // A UI agora usa a lista local `_displayedNotifications` para construir
          if (viewModel.isLoading && _displayedNotifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_displayedNotifications.isEmpty) {
            return const Center(
                child: Text("Nenhuma notificação para mostrar."));
          }

          return ListView.builder(
            itemCount: _displayedNotifications.length,
            itemBuilder: (context, index) {
              final notif = _displayedNotifications[index];
              return _buildNotificationTile(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final theme = Theme.of(context);
    final bool isRead = notif['isRead'] as bool? ?? true;
    final type = notif['type'] as String?;

    IconData iconData = Icons.notifications;
    Color iconColor = theme.colorScheme.secondary;
    String title = "Nova Atividade";
    String subtitle =
        notif['fromUserName'] ?? "Você recebeu uma nova notificação.";

    final timestamp = notif['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy HH:mm').format(timestamp.toDate())
        : '';

    Widget? trailing;

    // A lógica para construir os botões agora é baseada se a notificação já foi lida
    if (type == 'friend_request' && !isRead) {
      final fromUserId = notif['fromUserId'] as String;
      iconData = Icons.person_add_alt_1;
      iconColor = Colors.blueAccent;
      title = "Pedido de Amizade";
      subtitle = "${notif['fromUserName'] ?? 'Alguém'} quer ser seu amigo.";

      trailing = _processingNotificationId ==
              notif['id'] // Usa o ID da notificação para o loading
          ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle,
                      color: Colors.green, size: 28),
                  tooltip: "Aceitar",
                  onPressed: () => _handleFriendRequest(notif, true),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                  tooltip: "Recusar",
                  onPressed: () => _handleFriendRequest(notif, false),
                ),
              ],
            );
    } else if (type == 'friend_request' && isRead) {
      // Se a notificação do pedido já foi lida (ou seja, respondida), não mostra botões.
      trailing = const Chip(label: Text("Respondido"));
    }

    return Container(
      color: isRead
          ? Colors.transparent
          : theme.colorScheme.primary.withOpacity(0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: () {
          if (type == 'friend_request') {
            Navigator.pushNamed(context, '/friends');
          }
        },
      ),
    );
  }
}
