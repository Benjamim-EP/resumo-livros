// lib/components/avatar/avatar_user.dart
import 'package:flutter/material.dart';
// REMOVIDO: import 'package:firebase_auth/firebase_auth.dart'; // Já não era usado diretamente aqui

class Avatar extends StatelessWidget {
  // REMOVIDO: final String? triboImage;
  final String? userPhotoURL;

  const Avatar({
    super.key,
    // REMOVIDO: this.triboImage,
    this.userPhotoURL,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? backgroundImage;
    Widget? childIcon;

    if (userPhotoURL != null && userPhotoURL!.isNotEmpty) {
      backgroundImage = NetworkImage(userPhotoURL!);
    } else {
      childIcon = const Icon(
        Icons.account_circle,
        size: 80,
        color: Colors.grey,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 75,
          backgroundColor: Colors.grey[300],
          backgroundImage: backgroundImage,
          onBackgroundImageError: backgroundImage != null
              ? (dynamic exception, StackTrace? stackTrace) {
                  print("Erro ao carregar a imagem do usuário: $exception");
                }
              : null,
          child: backgroundImage == null ? childIcon : null,
        ),
        Container(
          width: 155,
          height: 155,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
        ),
        // REMOVIDO: Lógica e Positioned para triboImage
        // if (triboImage != null)
        //   Positioned(
        //     ...
        //   ),
      ],
    );
  }
}
