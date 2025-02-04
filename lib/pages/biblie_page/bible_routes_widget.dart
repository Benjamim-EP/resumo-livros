import 'package:flutter/material.dart';

class BibleRoutesWidget extends StatelessWidget {
  final VoidCallback onBack;

  const BibleRoutesWidget({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: onBack,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF272828),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: const Text(
          "Rotas Bíblia",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
