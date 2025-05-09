// lib/components/avatar/avatar_user.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obter a foto do usuário do Firebase Auth

class Avatar extends StatelessWidget {
  final String? triboImage;
  final String? userPhotoURL; // Adicionar userPhotoURL

  const Avatar({
    super.key,
    this.triboImage,
    this.userPhotoURL, // Adicionado
  });

  @override
  Widget build(BuildContext context) {
    // Determina qual URL de imagem usar ou se deve usar o placeholder/ícone local
    ImageProvider? backgroundImage;
    Widget? childIcon;

    if (userPhotoURL != null && userPhotoURL!.isNotEmpty) {
      backgroundImage = NetworkImage(userPhotoURL!);
    } else {
      // Se não houver userPhotoURL, tentamos o placeholder, mas com fallback para ícone
      //backgroundImage = const NetworkImage("https://via.placeholder.com/150x150");
      // Vamos usar um ícone local como fallback principal se não houver foto do usuário.
      // O placeholder de rede pode ser uma segunda tentativa se a foto do usuário falhar,
      // mas o erro indica que até o placeholder está falhando por falta de rede.
      childIcon = const Icon(
        Icons.account_circle,
        size: 80, // Ajuste o tamanho conforme necessário
        color: Colors.grey, // Cor do ícone de fallback
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Imagem principal do usuário ou fallback
        CircleAvatar(
          // Usar CircleAvatar para facilitar o fallback e o carregamento
          radius: 75, // Metade de 150
          backgroundColor:
              Colors.grey[300], // Cor de fundo enquanto carrega ou se falhar
          backgroundImage:
              backgroundImage, // Será null se estivermos usando childIcon
          child: backgroundImage == null
              ? childIcon
              : null, // Mostra childIcon se backgroundImage for null
          onBackgroundImageError: backgroundImage != null
              ? (dynamic exception, StackTrace? stackTrace) {
                  // Se a NetworkImage do usuário falhar, poderia tentar o placeholder aqui,
                  // mas dado o erro de SocketException, é melhor ter um fallback local.
                  // Por agora, o backgroundColor e um possível ícone já servem de fallback.
                  print("Erro ao carregar a imagem do usuário: $exception");
                }
              : null,
        ),
        // Borda ao redor da imagem
        Container(
          width: 155, // 75 * 2 + 5 (borda)
          height: 155,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  Theme.of(context).primaryColor, // Usar cor primária do tema
              width: 2, // Aumentar um pouco a largura da borda
            ),
          ),
        ),
        // Imagem da tribo no canto inferior direito
        if (triboImage != null)
          Positioned(
            bottom: 5, // Ajustar posicionamento
            right: 5, // Ajustar posicionamento
            child: Container(
              // Adicionar um pequeno padding e fundo para a imagem da tribo
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  triboImage!,
                  width: 51,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
