// lib/pages/community/notifications_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Carrega as notificações ao entrar na tela
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(LoadNotificationsAction());
        // Marca todas as notificações visíveis como lidas
        _markAllAsRead();
      }
    });
  }

  Future<void> _markAllAsRead() async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final unreadNotifications = store.state.userState.userNotifications
        .where((n) => !(n['isRead'] as bool? ?? true))
        .map((n) => n['id'] as String)
        .toList();

    if (unreadNotifications.isEmpty) return;

    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('markNotificationsAsRead');
      await callable.call({'notificationIds': unreadNotifications});
    } catch (e) {
      print("Erro ao marcar notificações como lidas: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notificações")),
      body: StoreConnector<AppState, UserState>(
        converter: (store) => store.state.userState,
        builder: (context, userState) {
          if (userState.isLoadingNotifications) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userState.userNotifications.isEmpty) {
            return const Center(child: Text("Nenhuma notificação ainda."));
          }

          return ListView.builder(
            itemCount: userState.userNotifications.length,
            itemBuilder: (context, index) {
              final notif = userState.userNotifications[index];
              final isRead = notif['isRead'] as bool? ?? true;

              Widget? icon;
              String title = "Notificação";
              String subtitle = "Você recebeu uma nova notificação.";

              final timestamp = notif['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('dd/MM/yy HH:mm').format(timestamp.toDate())
                  : '';

              if (notif['type'] == 'friend_request') {
                icon = const Icon(Icons.person_add, color: Colors.blueAccent);
                title = "Pedido de Amizade";
                subtitle =
                    "${notif['fromUserName'] ?? 'Alguém'} quer ser seu amigo.";
              }

              return ListTile(
                leading: icon,
                title: Text(title,
                    style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(subtitle),
                trailing:
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                tileColor: isRead
                    ? null
                    : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                onTap: () {
                  if (notif['type'] == 'friend_request') {
                    Navigator.pushNamed(context, '/friends').then((_) {
                      // Quando voltar da tela de amigos, recarrega os dados
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(LoadFriendsDataAction());
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
