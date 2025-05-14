import 'package:flutter/material.dart';

class TribeView extends StatelessWidget {
  final AnimationController animationController;

  const TribeView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final animation =
        Tween<Offset>(begin: const Offset(1, 0), end: const Offset(0, 0))
            .animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
    ));

    return SlideTransition(
      position: animation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Escolha sua Tribo",
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Salvar a tribo e prosseguir
                  },
                  child: const Text("Tribo A"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Salvar a tribo e prosseguir
                  },
                  child: const Text("Tribo B"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
