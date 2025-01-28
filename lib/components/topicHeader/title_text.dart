import 'package:flutter/material.dart';

// Componente para o texto do título "Cristianismo"
class TitleText extends StatelessWidget {
  final String text;

  const TitleText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 20,
        fontFamily: 'Abel',
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
