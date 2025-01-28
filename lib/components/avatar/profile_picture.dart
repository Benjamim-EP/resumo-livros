import 'package:flutter/material.dart';
import 'avatar_user.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class ProfilePicture extends StatelessWidget {
  final Map<String, String> _triboImageMap = {
    'Aser': 'assets/images/tribos/aser.webp',
    'Benjamim': 'assets/images/tribos/benjamim.webp',
    'Dã': 'assets/images/tribos/da.webp',
    'Gade': 'assets/images/tribos/gade.webp',
    'Issacar': 'assets/images/tribos/issacar.webp',
    'José': 'assets/images/tribos/jose.webp',
    'Judá': 'assets/images/tribos/juda.webp',
    'Levi': 'assets/images/tribos/levi.webp',
    'Naftali': 'assets/images/tribos/naftali.webp',
    'Rúben': 'assets/images/tribos/ruben.webp',
    'Simeão': 'assets/images/tribos/simeao.webp',
    'Zebulom': 'assets/images/tribos/zebulom.webp',
  };

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, String?>(
      converter: (store) {
        final tribo = store.state.userState.userDetails?['Tribo'] ?? '';
        return _triboImageMap[tribo];
      },
      builder: (context, triboImage) {
        return Center(
          child: Avatar(triboImage: triboImage),
        );
      },
    );
  }
}
