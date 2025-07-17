// lib/pages/user_page/profile_action_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';

// ✅ O WIDGET AGORA É APENAS VISUAL
class ProfileActionButton extends StatelessWidget {
  final double avatarRadius;

  const ProfileActionButton({
    super.key,
    this.avatarRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, String?>(
      converter: (store) => store.state.userState.userDetails?['photoURL'],
      builder: (context, photoUrl) {
        // REMOVEMOS O GestureDetector e o Tooltip.
        // O CircleAvatar é a única coisa que retornamos.
        return CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Colors.grey.shade700.withOpacity(0.5),
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Icon(Icons.person,
                  size:
                      avatarRadius * 1.2, // Ajuste para o ícone preencher mais
                  color: Colors.white)
              : null,
        );
      },
    );
  }
}
