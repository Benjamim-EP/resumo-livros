// lib/components/avatar/profile_picture.dart
import 'package:flutter/material.dart';
import 'avatar_user.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obter o usuário atual

class ProfilePicture extends StatelessWidget {
  final Map<String, String> _triboImageMap = {
    'Aser': 'assets/images/tribos/aser.webp',
    'Benjamim': 'assets/images/tribos/benjamim.webp',
    'Dã': 'assets/images/tribos/da.webp',
    'Gade': 'assets/images/tribos/gade.webp',
    'Issacar': 'assets/images/tribos/issacar.webp',
    'José (Efraim e Manassés)':
        'assets/images/tribos/jose.webp', // Nome da tribo corrigido para corresponder ao mapa
    'Judá': 'assets/images/tribos/juda.webp',
    'Levi': 'assets/images/tribos/levi.webp',
    'Naftali': 'assets/images/tribos/naftali.webp',
    'Rúben': 'assets/images/tribos/ruben.webp',
    'Simeão': 'assets/images/tribos/simeao.webp',
    'Zebulom': 'assets/images/tribos/zebulom.webp',
  };

  ProfilePicture({super.key}); // Adicionado super.key

  @override
  Widget build(BuildContext context) {
    // Obtém a URL da foto do usuário do Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? userPhotoURL = currentUser?.photoURL;

    return StoreConnector<AppState, String?>(
      converter: (store) {
        // A lógica da tribo permanece a mesma
        final tribo = store.state.userState.userDetails?['Tribo']
            as String?; // Cast para String?
        return tribo != null ? _triboImageMap[tribo] : null;
      },
      builder: (context, triboImage) {
        return Center(
          child: Avatar(
            triboImage: triboImage,
            userPhotoURL: userPhotoURL, // Passa a URL da foto do usuário
          ),
        );
      },
    );
  }
}
