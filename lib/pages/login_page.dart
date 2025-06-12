// Em: lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/sign_in_google.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCDE7BE),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1A),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 23,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 90),
                  const Center(
                    child: Text(
                      'Login',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Use sua conta Google para acessar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 120), // Aumenta o espaço
                  const Center(
                    child: Text(
                      'Conecte-se com',
                      style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Apenas chama a função, sem await, sem setState.
                      // O AuthCheck cuidará do resto.
                      signInWithGoogle(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: SvgPicture.asset('assets/icons/google.svg',
                        width: 42, height: 42),
                  ),
                  const SizedBox(height: 150), // Aumenta o espaço
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
