// lib/pages/user_page/profile_action_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'profile_info_modal.dart';

class ProfileActionButton extends StatelessWidget {
  // ✅ Adicionamos um novo parâmetro para o raio do avatar.
  final double avatarRadius;

  const ProfileActionButton({
    super.key,
    this.avatarRadius = 22, // Valor padrão para um bom tamanho na AppBar
  });

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, String?>(
      converter: (store) => store.state.userState.userDetails?['photoURL'],
      builder: (context, photoUrl) {
        // O Tooltip agora envolve o CircleAvatar diretamente
        return Tooltip(
          message: "Ver Perfil e Configurações",
          child: GestureDetector(
            onTap: () {
              // A ação de abrir o modal permanece a mesma.
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ProfileInfoModal(),
              );
            },
            // Usamos um InkWell com um CircleAvatar dentro para ter o efeito de splash.
            child: CircleAvatar(
              radius: avatarRadius, // ✅ Usa o parâmetro de raio
              backgroundColor: Colors.grey.shade700.withOpacity(0.5),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(Icons.person,
                      size: avatarRadius * 0.9, color: Colors.white)
                  : null,
            ),
          ),
        );
      },
    );
  }
}
