import 'package:flutter/material.dart';

// Componente para o texto "Show all"
class ShowAllText extends StatelessWidget {
  final String text;

  const ShowAllText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFCDE7BE),
        fontSize: 12,
        fontFamily: 'Abel',
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
