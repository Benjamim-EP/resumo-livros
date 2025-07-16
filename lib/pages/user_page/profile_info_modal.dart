// lib/pages/user_page/profile_info_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/avatar/avatar_user.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// ViewModel para buscar os dados necessários do Redux
class _ProfileViewModel {
  final String? photoUrl;
  final String name;
  final String? septimaId;
  final String description;
  final String? denomination;

  _ProfileViewModel({
    this.photoUrl,
    required this.name,
    this.septimaId,
    required this.description,
    this.denomination,
  });

  static _ProfileViewModel fromStore(Store<AppState> store) {
    final details = store.state.userState.userDetails ?? {};
    String? generatedId;
    final username = details['username'] as String?;
    final discriminator = details['discriminator'] as String?;
    if (username != null && discriminator != null) {
      generatedId = '$username#$discriminator';
    }

    return _ProfileViewModel(
      photoUrl: details['photoURL'] as String?,
      name: details['nome'] as String? ?? 'Usuário',
      septimaId: generatedId,
      description:
          details['descrição'] as String? ?? 'Nenhuma descrição adicionada.',
      denomination: details['denomination'] as String?,
    );
  }
}

class ProfileInfoModal extends StatelessWidget {
  const ProfileInfoModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _ProfileViewModel>(
      converter: (store) => _ProfileViewModel.fromStore(store),
      builder: (context, vm) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar grande
              Avatar(userPhotoURL: vm.photoUrl),
              const SizedBox(height: 16),
              // Nome do usuário
              Text(
                vm.name,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // ID Septima com botão de copiar
              if (vm.septimaId != null)
                ActionChip(
                  avatar: Icon(Icons.tag,
                      size: 16, color: theme.colorScheme.secondary),
                  label: Text(vm.septimaId!),
                  tooltip: "Copiar ID",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: vm.septimaId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("ID copiado!")),
                    );
                  },
                ),
              const SizedBox(height: 16),
              // Descrição
              Text(
                vm.description,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Denominação
              if (vm.denomination != null && vm.denomination!.isNotEmpty)
                Chip(
                  avatar: Icon(Icons.church_outlined,
                      size: 18, color: theme.colorScheme.onSecondaryContainer),
                  label: Text(vm.denomination!),
                  backgroundColor:
                      theme.colorScheme.secondaryContainer.withOpacity(0.5),
                ),
              const Divider(height: 32),
              // Botão para editar perfil
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("Configurações e Perfil"),
                  onPressed: () {
                    Navigator.pop(context); // Fecha o modal
                    // ✅ CORREÇÃO AQUI: Adiciona rootNavigator: true
                    Navigator.of(context, rootNavigator: true)
                        .pushNamed('/userSettings');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
