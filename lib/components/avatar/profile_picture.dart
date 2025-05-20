// lib/components/avatar/profile_picture.dart
import 'package:flutter/material.dart';
import 'avatar_user.dart';
// REMOVIDO: import 'package:flutter_redux/flutter_redux.dart';
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obter o usuário atual

class ProfilePicture extends StatelessWidget {
  // REMOVIDO: final Map<String, String> _triboImageMap = { ... };

  const ProfilePicture({super.key}); // Modificado para const

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? userPhotoURL = currentUser?.photoURL;

    // Não precisamos mais do StoreConnector aqui se a imagem da tribo foi removida
    return Center(
      child: Avatar(
        // triboImage: null, // REMOVIDO
        userPhotoURL: userPhotoURL,
      ),
    );
  }
}
