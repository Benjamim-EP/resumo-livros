import 'package:flutter/material.dart';

class DifficultNumber extends StatelessWidget {
  final int value; // Valor do número de 0 a 100

  const DifficultNumber({super.key, required this.value})
      : assert(value >= 0 && value <= 100, "O valor deve estar entre 0 e 100.");

  // Função que interpola a cor com base no valor
  Color _getColorForValue(int value) {
    // Verde (0) -> Vermelho (100)
    int red = (255 * value ~/ 100);
    int green = (255 * (100 - value) ~/ 100);
    return Color.fromARGB(255, red, green, 75);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value', // Exibe o valor
      style: TextStyle(
        fontSize: 24, // Tamanho do texto
        fontWeight: FontWeight.bold, // Negrito
        color: _getColorForValue(value), // Define a cor interpolada
      ),
    );
  }
}
