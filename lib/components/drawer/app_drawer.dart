// lib/components/drawer/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

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

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
                icon: Icons.people_alt_outlined, // Ícone de grupo de pessoas
                text: 'Amigos', // Texto alterado
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context,
                      '/friends'); // Rota alterada para o hub de amigos
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

  // Novo cabeçalho customizado
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
    int badgeCount = 0, // ✅ NOVO PARÂMETRO OPCIONAL
  }) {
    return ListTile(
      leading: badgeCount > 0
          ? Badge(
              // Widget nativo do Flutter para contadores
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
