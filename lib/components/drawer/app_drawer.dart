// lib/components/drawer/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/services/notification_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ViewModel para buscar os dados do usuário para o cabeçalho do Drawer
class _DrawerViewModel {
  final String? photoUrl;
  final String name;
  final String? septimaId;
  final String? denomination;
  final int unreadCount;

  _DrawerViewModel({
    this.photoUrl,
    required this.name,
    this.septimaId,
    this.denomination,
    required this.unreadCount,
  });

  static _DrawerViewModel fromStore(Store<AppState> store) {
    final details = store.state.userState.userDetails ?? {};
    String? generatedId;
    final username = details['username'] as String?;
    final discriminator = details['discriminator'] as String?;
    if (username != null && discriminator != null) {
      generatedId = '$username#$discriminator';
    }

    return _DrawerViewModel(
      photoUrl: details['photoURL'] as String?,
      name: details['nome'] as String? ?? 'Usuário',
      septimaId: generatedId,
      denomination: details['denomination'] as String?,
      unreadCount: store.state.userState.unreadNotificationsCount,
    );
  }
}

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _isLoadingPreference = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Adiciona este widget como um observador do ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);
    // Faz a verificação inicial ao construir o widget
    _syncNotificationStatus();
  }

  @override
  void dispose() {
    // Remove o observador para evitar memory leaks
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Observa as mudanças no ciclo de vida do aplicativo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se o app voltou para o primeiro plano (ex: voltando das configurações do Android)
    if (state == AppLifecycleState.resumed) {
      print(
          "Drawer: App voltou para o primeiro plano. Sincronizando status da notificação.");
      // Sincroniza o estado do switch com a permissão real do sistema
      _syncNotificationStatus();
    }
  }

  /// Sincroniza o estado do switch com a permissão real do sistema E o SharedPreferences.
  Future<void> _syncNotificationStatus() async {
    // 1. Pega a permissão REAL do sistema operacional
    final status = await Permission.notification.status;
    final bool permissionGranted = status.isGranted;

    // 2. Pega a preferência SALVA pelo usuário no app
    final prefs = await SharedPreferences.getInstance();
    final bool userPreference =
        prefs.getBool(NotificationService.notificationsEnabledKey) ?? true;

    // 3. O estado final do switch é a combinação dos dois:
    //    Só deve estar "ligado" se o usuário QUER (preferência) E PODE (permissão).
    final bool finalStatus = userPreference && permissionGranted;

    if (mounted) {
      setState(() {
        _notificationsEnabled = finalStatus;
        _isLoadingPreference = false;
      });
    }

    // 4. Se houver uma discrepância, corrige o SharedPreferences para refletir a realidade.
    if (userPreference != finalStatus) {
      await prefs.setBool(
          NotificationService.notificationsEnabledKey, finalStatus);
    }
  }

  /// Lida com a interação do usuário com o switch.
  Future<void> _updateNotificationPreference(bool newValue) async {
    final prefs = await SharedPreferences.getInstance();

    if (newValue == true) {
      // O usuário está TENTANDO ATIVAR as notificações.
      var status = await Permission.notification.status;

      if (status.isGranted) {
        print("Drawer: Permissão já concedida. Ativando lembretes.");
        setState(() => _notificationsEnabled = true);
        await prefs.setBool(NotificationService.notificationsEnabledKey, true);
        await _notificationService.scheduleDailyDevotionals();
        if (mounted)
          CustomNotificationService.showSuccess(
              context, "Lembretes diários ativados!");
        return;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        print(
            "Drawer: Permissão negada permanentemente. Abrindo diálogo de configurações.");
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Permissão Necessária"),
              content: const Text(
                  "Para ativar os lembretes, você precisa permitir as notificações manualmente nas configurações do seu dispositivo para este aplicativo."),
              actions: [
                TextButton(
                  child: const Text("Cancelar"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text("Abrir Configurações"),
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        }
        setState(() => _notificationsEnabled = false);
        return;
      }

      if (status.isDenied) {
        print(
            "Drawer: Permissão foi negada anteriormente. Solicitando novamente...");
        final newStatus = await Permission.notification.request();

        if (newStatus.isGranted) {
          print("Drawer: Permissão agora concedida. Agendando lembretes.");
          setState(() => _notificationsEnabled = true);
          await prefs.setBool(
              NotificationService.notificationsEnabledKey, true);
          await _notificationService.scheduleDailyDevotionals();
          if (mounted)
            CustomNotificationService.showSuccess(
                context, "Lembretes diários ativados!");
        } else {
          print("Drawer: Usuário negou a permissão novamente.");
          if (mounted)
            CustomNotificationService.showError(
                context, "Permissão de notificação negada.");
          setState(() => _notificationsEnabled = false);
        }
      }
    } else {
      // O usuário está DESATIVANDO as notificações.
      print(
          "Drawer: Desativando lembretes e cancelando notificações agendadas.");
      setState(() {
        _notificationsEnabled = false;
      });
      await prefs.setBool(NotificationService.notificationsEnabledKey, false);
      await _notificationService.cancelAllNotifications();
      if (mounted) {
        CustomNotificationService.showSuccess(
            context, "Lembretes diários desativados.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _DrawerViewModel>(
      converter: (store) => _DrawerViewModel.fromStore(store),
      builder: (context, viewModel) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _buildDrawerHeader(context, viewModel),
              _buildDrawerItem(
                icon: Icons.people_alt_outlined,
                text: 'Amigos',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/friends');
                },
              ),
              _buildDrawerItem(
                icon: Icons.notifications_outlined,
                text: 'Notificações',
                badgeCount: viewModel.unreadCount,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              _buildDrawerItem(
                icon: Icons.edit_note_outlined,
                text: 'Diário Devocional',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/diary');
                },
              ),
              _isLoadingPreference
                  ? const ListTile(title: Text("Carregando configuração..."))
                  : SwitchListTile(
                      title: const Text("Lembretes Diários"),
                      value: _notificationsEnabled,
                      onChanged: _updateNotificationPreference,
                      secondary: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                    ),
              const Divider(),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                text: 'Configurações e Perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/userSettings');
                },
              ),
              _buildDrawerItem(
                icon: Icons.logout,
                text: 'Sair',
                onTap: () => _showLogoutConfirmationDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerHeader(BuildContext context, _DrawerViewModel viewModel) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: viewModel.photoUrl != null
                ? NetworkImage(viewModel.photoUrl!)
                : null,
            child: viewModel.photoUrl == null
                ? Text(viewModel.name.isNotEmpty ? viewModel.name[0] : 'U',
                    style: const TextStyle(fontSize: 28))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  viewModel.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (viewModel.septimaId != null)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: viewModel.septimaId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("ID copiado!")),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewModel.septimaId!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_all_outlined,
                            size: 14,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7)),
                      ],
                    ),
                  ),
                if (viewModel.denomination != null &&
                    viewModel.denomination!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      viewModel.denomination!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: badgeCount > 0
          ? Badge(
              label: Text('$badgeCount'),
              child: Icon(icon),
            )
          : Icon(icon),
      title: Text(text),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Você tem certeza que deseja sair?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child:
                  const Text('Sair', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pop(context);
                StoreProvider.of<AppState>(context, listen: false)
                    .dispatch(UserLoggedOutAction());
              },
            ),
          ],
        );
      },
    );
  }
}
