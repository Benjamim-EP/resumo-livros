import 'package:flutter/material.dart';

class FavouriteIcon extends StatelessWidget {
  final bool isSelected; // Parâmetro para indicar se está selecionado

  const FavouriteIcon({Key? key, required this.isSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(
      isSelected
          ? Icons.favorite
          : Icons.favorite_border, // Ícone preenchido ou com borda
      color: isSelected
          ? Colors.red
          : Colors.grey, // Vermelho se selecionado, cinza se não
      size: 30, // Tamanho do ícone
    );
  }
}
